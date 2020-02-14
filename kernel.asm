;Kernel for AsteriOS

;Project started 15/12/2004
;Author: Christos Themelis
;name of OS given in memory of my friend Asterios Parlamentas
;
;also i have to thank some people for some asm code taken from internet
;part: floppy bootloader: "BootProg" Loader v 1.2 by Alexei A. Frounze (c) 2000

[BITS 16]

[SECTION .text]

[ORG 600h]

Kernel_Start:
	jmp	RealStart		;RealStart is in kernel16.asm

%include 'defines.asm'		;all strings
%include 'struct.asm'		;all structs
%include 'data.asm'		;all strings
;biosinfo is 16 bit
%include 'biosinfo.asm'
%include 'kernel16.asm'

[BITS 32]

;Demo code taken from: http://my.execpc.com/CE/AC/geezer/osd/pmode/index.htm
;Here starts the Protected Mode code
align 4
pmode:
	mov 	ax, SYS_DATA_SEL
	mov 	ds, ax
	mov 	ss, ax
	mov 	fs, ax
	mov 	gs, ax
	mov 	es, ax

	mov 	eax, OS_STACK		;stack
	add	eax, 0FC00h		;stack size
	sub	eax, 4			;for safe :)
	mov 	esp, eax

	mov	dword [KernelAddress], 600h

	mov	byte [SystemLoaded], 0
	mov	byte [Multitasking], 0		;multitasking disabled

	cli

	;mov	ax, TSS_SEL
	;ltr	ax

	;call	InitDesktop

	push	dword LoadingMsg
	call	Print

	;push dword [VGA_Height]
	;push dword [VGA_Width]
	;push dword VGA_Resolution
	;call	Print

	;setup IRQs and IDT
	call	Setup_PIC
	call	Delay32
	call	Disable_IRQs
	call	Setup_IDT

	;until here only traps and exceptions are enabled
	;enable timer IRQ
	push	dword 20h
	push	dword IRQ_Timer
	call	HookInterrupt

	;enable IRQs
	call	Enable_IRQs		;enable now

	;init memory manager
	call	Init_MemManager
	call	Init_Loader

	;after this point are available the functions "SetProcAddress" & "GetProcAddress"
	;now we can set all kernel functions, so can be used by other modules
	call	Register_Kernel_Functions

	;call	Init_WinManager

	call 	CheckVMWare

	jnc	not_vmware
	%ifdef DEBUG
	push	dword RunUnderVMWare
	call	Print
	%endif
not_vmware:
	call	Init_ProcessManager

	call	Init_DeviceManager
	;call	Init_CPU		;just shows info
	;call	DetectCPU		;detects dual/quad core cpus (or multi-cpus systems)

	;;;
	;call	Enable_IRQs		;enable now

	call	Init_Display
	call	OS_Bars
	;call	ClearScreen

	;call	Init_IDE
	;call	FindCDROM

	call	Init_FileIO
	call	Init_FDC
	call	Init_FAT12
  call  InitClock

	push	dword SystemIni
	call	ExecuteBatFile

	;call	Init_Mouse

	push	dword sGetKeyboardQueue
	call	GetProcAddress
	mov	dword [GetKeyboardQueue], eax

	push	dword sCheckCmdLineBuffer
	call	GetProcAddress
	push	eax
	call	SetKeyboardCallback		;input eax = address of keyboard handler (hook)

	push	esi
	push	dword sKernelFileName
	call	SetOpenFile
	mov	esi, dword [OpenFilesArray]
	mov	eax, dword Kernel_Start
	mov	dword [esi + FILE_NAME_SIZE + 16], eax	;save loaded address
	pop	esi

	push	dword System_Loaded
	call	Print

	mov	byte [MoveRealCursor], 1	;enable real cursor movement

	push	dword CurrentDrive		;and directory
	push	dword OS_Prompt
	call	Print

	;call	DrawDesktop


	push	OS_Main_Loop	    		;Code to execute
	push	dword 4*1024			;stack size
	call	CreateProcess

	;call	DrawCounters

	;push	ClockLoop	    		;Code to execute
	;push	dword 4*1024			;stack size
	;call	CreateProcess

	;push	CountLoop2	    		;Code to execute
	;push	dword 4*1024			;stack size
	;call	CreateProcess

	;push DWORD 1
	;push DWORD 649
	;push DWORD myImage1
	;call 	DrawBmpF

	;call	OSM2LFB

	mov	byte [Multitasking], 1		;multitasking enabled
	mov	byte [InitMultitask], 1
	mov	byte [SystemLoaded], 1		;activate IRQs and other

	jmp	$

;align 4
OS_Main_Loop:
	;TODO: handle messages (keyboard queue, etc)
	cmp	byte [SystemLoaded], 1
	jne	OS_Main_Loop

  call PrintClock
	;cmp	byte [GUILoaded], 0
	;je	.do_later
	;cmp	byte [ScrollingWindow], 1
	;je	.do_later
	;cmp	byte [VgaNeedsUpdate], 1
	;jne	.do_later
	;mov	byte [VgaNeedsUpdate], 0
	;call	OSM2LFB
.do_later:

	call	HandleKeyboardEvents

	hlt
  jmp   	OS_Main_Loop


align	4

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Clock
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

align 4
InitClock:
	pushad
  pushfd

	mov	dword [OS_loops], 0
	mov byte [uptime_sec], 0
	mov byte [uptime_min], 0
	mov byte [uptime_hours], 0
	mov byte [uptime_days], 0

	push	sSetClockMode
	push	SetClockMode
	call	SetProcAddress

  ;push	dword [ebp + sPrintClock]
	;push	dword [ebp + PrintCLock]
	;call	[ebp + SetProcAddress]

	mov	byte [ShowClock], 1

	popfd
  popad
	ret

align 4
SetClockMode:
    pushfd
		mov	byte [ShowClock], al
    cmp al, 0
    jne .exit
    call	OS_Bars
.exit:
    popfd
		ret

align 4
;Clear everything to unload driver
StopClock:
	;unregister function
	;stop process
	ret


  Print_OS_Loops:
  	;pushad
  	call	GetCursor
  	push	eax
  	mov	eax, 0030h
  	call	SetCursor
  	;mov	ebx, [OS_loops]
  	push	dword [OS_loops]
  	call	PrintHex
  	pop	eax
  	call	SetCursor
  	;popad
  	ret

  ; inc system uptime
  Inc_Uptime:
  	pushad

  	cld
  	inc	byte [uptime_sec]
  	cmp	byte [uptime_sec], 60
  	jne	.exit

  	mov	byte [uptime_sec], 0
  	inc	byte [uptime_min]
  	cmp	byte [uptime_min], 60
  	jne	.exit

  	mov	byte [uptime_min], 0
  	inc	byte [uptime_hours]
  	cmp	byte [uptime_hours], 24
  	jne	.exit

  	mov	byte [uptime_hours], 0
  	inc	byte [uptime_days]
  .exit:

  	;UpTimeMask		db	'  d 00:00:00', 0
  	movzx	ebx, word [uptime_days]
  	push	ebx
  	call	MakeDecimal
  	mov	esi, DecimalBufT
  	mov	edi, UpTimeMask

  	cmp	word [uptime_days], 10
  	jb	.Inc_Uptime_1
  	lodsb
  	mov	[edi], al
  .Inc_Uptime_1:
  	inc	edi
  	lodsb
  	mov	[edi], al
  	add	edi, 3

  	movzx 	ebx, byte [uptime_hours]
  	push	ebx
  	call	MakeDecimal
  	mov	esi, DecimalBufT
  	mov	byte [edi], "0"
  	cmp	byte [esi+1], 0
  	je	.Inc_Uptime_2
  	lodsb
  	mov	[edi], al
  .Inc_Uptime_2:
  	inc	edi
  	lodsb
  	mov	[edi], al
  	add	edi, 2

  	movzx 	ebx, byte [uptime_min]
  	push	ebx
  	call	MakeDecimal
  	mov	esi, DecimalBufT
  	mov	byte [edi], "0"
  	cmp	byte [esi+1], 0
  	je	.Inc_Uptime_3
  	lodsb
  	mov	[edi], al
  .Inc_Uptime_3:
  	inc	edi
  	lodsb
  	mov	[edi], al
  	add	edi, 2

  	movzx 	ebx, byte [uptime_sec]
  	push	ebx
  	call	MakeDecimal
  	mov	esi, DecimalBufT
  	mov	byte [edi], "0"
  	cmp	byte [esi+1], 0
  	je	.Inc_Uptime_4
  	lodsb
  	mov	[edi], al
  .Inc_Uptime_4:
  	inc	edi
  	lodsb
  	mov	[edi], al

  	popad
  	ret

  ;PrintSimple system uptime
  PrintUpTime:
  	mov	eax, UpTimeMask
  	push	eax
  	push	dword 0039h		;line 1 column 70
  	call	PrintXY
  	ret

  ;Print system clock
  PrintClock:
  	pushad
  	pushfd

  	cld
  	mov	eax, [cmos_sec]
  	mov	[last_sec], eax
  	xor	eax, eax
  	out	70h, al
  	call	Delay
  	in	al, 71h
  	mov	[cmos_sec], eax

  	cmp	eax, [last_sec]
  	jne	.ok
  	jmp	.Exit
  .ok:

  	call	Inc_Uptime

    cmp byte [ShowClock], 0
    je .Exit

  	call	PrintUpTime
  	;call	CPULoad
  	;call	Print_OS_Loops

  	mov	al, 2
  	out	70h, al
  	call	Delay
  	in	al, 71h
  	mov	[cmos_min], eax

  	mov	al, 4
  	out	70h, al
  	call	Delay
  	in	al, 71h
  	mov	[cmos_hour], eax

  	mov	eax, ClockMask
  	push	eax
  	push	dword 0047h		;line 1 column 71
  	call	PrintXY

  	pushad
  	mov	eax, dword [cmos_hour]
  	push	eax
  	and	eax,0ffh
  	shr	eax,4
  	mov	edx,10
  	mul	edx
  	pop	edx
  	and	edx,0fh
  	add	eax,edx

  	push	eax
  	call	MakeDecimal
  	mov	esi, DecimalBufT

  	mov	edi, SCREEN_MEM + 8Eh

  	cmp	byte [esi+1], 0
  	jne	.ok_1
  	mov	al, '0'
  	stosb
  	inc 	edi
  	movsb

  	jmp	.ok_1a
  .ok_1:
  	movsb
  	inc 	edi
  	movsb
  .ok_1a:
  	popad

  	add	edi, 3

  	pushad
  	mov	eax, dword [cmos_min]
  	push	eax
  	and	eax,0ffh
  	shr	eax,4
  	mov	edx,10
  	mul	edx
  	pop	edx
  	and	edx,0fh
  	add	eax,edx

  	push	eax
  	call	MakeDecimal
  	mov	esi, DecimalBufT

  	mov	edi, SCREEN_MEM + 94h

  	cmp	byte [esi+1], 0
  	jne	.ok_2
  	mov	al, '0'
  	stosb

  	inc 	edi
  	movsb
  	jmp	.ok_2a
  .ok_2:
  	movsb
  	inc 	edi
  	movsb
  .ok_2a:
  	popad

  	add	edi, 3

  	pushad
  	mov	eax, dword [cmos_sec]
  	push	eax
  	and	eax,0ffh
  	shr	eax,4
  	mov	edx,10
  	mul	edx
  	pop	edx
  	and	edx,0fh
  	add	eax,edx

  	push	eax
  	call	MakeDecimal
  	mov	esi, DecimalBufT

  	mov	edi, SCREEN_MEM + 9Ah

  	cmp	byte [esi+1], 0
  	jne	.ok_3
  	mov	al, '0'
  	stosb
  	inc 	edi
  	movsb

  	jmp	.ok_3a
  .ok_3:
  	movsb
  	inc 	edi
  	movsb
  .ok_3a:

  	popad

  .Exit:

  	popfd
  	popad

  	ret

;align 4
;CountLoop1:
;	inc	dword [OS_loops]
;
;	;cmp	dword [OS_loops], 0FFFFFh
;	;jb	.next
;
;	;mov	al, 0FEh
;	;out	64h, al			;this cause a soft reset (reboot)
;;.next:
;
;	push	dword [Cursor_Pos]
;	push	dword [Cursor_Line]
;
;	mov	dword [Cursor_Line],50+23
;	mov	dword [Cursor_Pos],20+6
;	push	dword [OS_loops]
;	call	PrintHex
;
;	pop	dword [Cursor_Line]
;	pop	dword [Cursor_Pos]
;	;hlt
;	jmp	CountLoop1
;
;CountLoop2:
;	inc	dword [OS_loops2]
;
;	push	dword [Cursor_Pos]
;	push	dword [Cursor_Line]
;
;	mov	dword [Cursor_Line],50+23
;	mov	dword [Cursor_Pos],220+6
;	push	dword [OS_loops2]
;	call	PrintHex
;
;	pop	dword [Cursor_Line]
;	pop	dword [Cursor_Pos]
;	;hlt
;	jmp	CountLoop2
;
DrawCounters:
	;push	dword MyCounter1
	;push	dword 50	;line
	;push	dword 20	;position
	;push	dword 50	;height
	;push	dword 100	;width
	;push	dword COLOR_BLUE		;color = blue
	;call	DrawWindow

	;push	dword MyCounter2
	;push	dword 50	;line
	;push	dword 220	;position
	;push	dword 50	;height
	;push	dword 100	;width
	;push	dword COLOR_BLUE		;color = blue
	;call	DrawWindow

	ret

; Include files
align 4
%include 'process.asm'
align 4
;%include 'gui.asm'
;align 4
;%include 'font256.asm'
;ALIGN 4
;%include 'mouse.asm'
;align 4
%include 'display.asm'
align 4
%include 'strings.asm'
ALIGN 4
%include 'irq.asm'
ALIGN 4
%include 'memmgr.asm'
ALIGN 4
%include 'loader.asm'
ALIGN 4
%include 'floppy.asm'
ALIGN 4
%include 'fileIO.asm'
ALIGN 4
%include 'fat12.asm'
ALIGN 4
%include 'devmgr.asm'
;ALIGN 4
;%include 'cpu.asm'
ALIGN 4
%include 'idt.asm'
;align 4
;%include 'winmgr.asm'

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


HandleKeyboardEvents:
	cmp	dword [GetKeyboardQueue], -1
	je	.next
	call	dword [GetKeyboardQueue]
	;call	GetKeyboardQueue
	;returns in al the first byte from queue (and deletes it from queue)
	;if no key/char in queue, returns 0
	cmp	al, 0
	je	.next

	cmp	dword [KeyboardCallback], -1
	je 	.next
	call	dword [KeyboardCallback]		;input:al
	mov	byte [VgaNeedsUpdate], 1
.next:
	ret

SetKeyboardCallback:
	push	ebp
	mov		ebp, esp
	add		ebp, 8

	mov		eax, dword [ebp]
	mov	dword [KeyboardCallback], eax

	pop	ebp
	ret	4

GetKeyboardCallback:
	mov	eax, dword [KeyboardCallback]
	ret

GetOSPrompt:
	mov	eax, dword OS_Prompt
	ret

GetOpenFilesArray:
	mov	eax, dword [OpenFilesArray]
	ret

GetMaxOpenFiles:
	mov	eax, MAX_OPEN_FILES
	ret

;input: bat file
ExecuteBatFile:
	push	ebp
	mov	ebp, esp
	add	ebp, 8

	pushad

	push	dword [ebp]
	call	OpenFile
	cmp	eax, -1
	jne	.file_ok
	jmp	.error
.file_ok:
	mov	dword [hBat], eax

	push	dword [hBat]
	call	GetFileSize
	mov	dword [szBat], eax

	push	dword [szBat]
	call	MemAlloc
	mov	dword [bufBat], eax

	push	dword [hBat]
	push	dword [bufBat]
	push	dword [szBat]
	call	LoadFile

	push	dword 512
	call	MemAlloc
	mov	dword [tmpBat], eax

	xor	edx, edx
	xor	ebx, ebx
	mov	esi, dword [bufBat]
	mov	edi, dword [tmpBat]
	mov	ecx, dword [szBat]
	inc	ecx
.loop:
	dec	ecx
	jz	.do_it

	mov	al, byte [esi]
	cmp	al, 13
	je	.do_it
	cmp	al, 10
	je	.next
	cmp	al, 9
	jne	.not_tab
	mov	al, ' '
.not_tab:
	cmp	edx, 511
	jge	.next
	mov	byte [edi], al
	inc	edi
	inc	edx
.next:
	inc	esi
	jmp	.loop
.do_it:
	cmp	edx, 0
	jne	.next1
	jmp	.emptyline
.next1:

	mov	byte [edi], 0

	push	dword [tmpBat]

	pushad
	push	dword [tmpBat]
	call	OpenFile
	cmp	eax, -1
	je	.loaded_ok
	mov	dword [h1], eax

	push	dword [h1]
	call	GetFileSize
	mov	dword [sz], eax

	push	dword [sz]
	call	MemAlloc
	mov	dword [buf], eax

	push	dword [h1]
	push	dword [buf]
	push	dword [sz]
	call	LoadFile

	push	dword [buf]
	call	LoadExecutable
	cmp	eax, -1
	jne	.loaded_ok
		;first close file and then free mem
		;cause CloseFile maybe executes "Stop" function
		push	dword [tmpBat]
		call	CloseFile
		push	dword [buf]
		call	MemFree
.loaded_ok:
	popad
	pop	dword [tmpBat]
.emptyline:
	cmp	ecx, 0
	je	.exit
	xor	edx, edx
	mov	edi, dword [tmpBat]
	jmp	.next
.exit:
	push	dword [tmpBat]
	call	MemFree

	push	dword [bufBat]
	call	MemFree

	push	dword [ebp]
	call	CloseFile
.error:
	popad
	pop	ebp
	ret	4

Register_Kernel_Functions:
	%ifdef DEBUG
	push	Debug_Register_Kernel_Functions
	call	Print
	%endif

	;register Kernel functions
	push	dword sCheckVMWare
	push	dword CheckVMWare
	call	SetProcAddress

	;register String functions
	push	dword sStrCmp
	push	dword StrCmp
	call	SetProcAddress

	push	dword sStrCpy
	push	dword StrCpy
	call	SetProcAddress

	push	dword sStrLen
	push	dword StrLen
	call	SetProcAddress

	push	dword sMemSet
	push	dword MemSet
	call	SetProcAddress

	;register display functions
	push	dword sDisable_IRQs
	push	dword Disable_IRQs
	call	SetProcAddress

	push	dword sEnable_IRQs
	push	dword Enable_IRQs
	call	SetProcAddress

	push	dword sMemAlloc
	push	dword MemAlloc
	call	SetProcAddress

	push	dword sMemFree
	push	dword MemFree
	call	SetProcAddress

	push	dword sMemCpy
	push	dword MemCpy
	call	SetProcAddress

	push	dword sHookInterrupt
	push	dword HookInterrupt
	call	SetProcAddress

	push	dword sGetInterruptAddress
	push	dword GetInterruptAddress
	call	SetProcAddress

	%ifdef DEBUG
	push	dword sGetDebugMode
	push	dword GetDebugMode
	call	SetProcAddress

	push	dword sSetDebugMode
	push	dword SetDebugMode
	call	SetProcAddress
	%endif

	;push	dword sSetClockMode
	;push	dword SetClockMode
	;call	SetProcAddress

	push	dword sGetSystemLoaded
	push	dword GetSystemLoaded
	call	SetProcAddress

	push	dword sToLower
	push	dword ToLower
	call	SetProcAddress

	push	dword sToUpper
	push	dword ToUpper
	call	SetProcAddress

	push	dword sGetOSPrompt
	push	dword GetOSPrompt
	call	SetProcAddress

	push	dword sGetMaxOpenFiles
	push	dword GetMaxOpenFiles
	call	SetProcAddress

	push	dword sGetOpenFilesArray
	push	dword GetOpenFilesArray
	call	SetProcAddress

	push	dword sSetKeyboardCallback
	push	dword SetKeyboardCallback
	call	SetProcAddress

	push	dword sGetKeyboardCallback
	push	dword GetKeyboardCallback
	call	SetProcAddress

	push	dword sGetMemoryManagerTable
	push	dword GetMemoryManagerTable
	call	SetProcAddress

	push	dword sGetMemoryManagerTableSize
	push	dword GetMemoryManagerTableSize
	call	SetProcAddress

	push	dword sGetSystemRam
	push	dword GetSystemRam
	call	SetProcAddress

	ret

align 4
;input nothing
;returns in eax DebugMode
%ifdef DEBUG
GetDebugMode:
	movzx	eax, byte [DebugMode]
	ret
align 4
SetDebugMode:
	mov	byte [DebugMode], al
	ret
%endif

align 4
GetSystemLoaded:
	movzx	eax, byte [SystemLoaded]
	ret

;align 4
;SetClockMode:
;	mov	byte [ShowClock], al
;	ret

ALIGN 4
CheckVMWare:
	;Are we running under VMWare ?
	pusha
	mov	eax, 564D5868h
	mov	ebx, 12345h
	mov	ecx, 00Ah
	mov	edx, 5658h
	in	ax, dx

	cmp	ebx, 564D5868h
	jne	NotVMWare

	popa
	stc
	ret
NotVMWare:
	popa
	clc
	ret

ALIGN 4
; this routine enables the infamouse A20 Line
Enable_A20:
	call	empty_8042
	mov	al, 0D1h		; command write
	out	064h, al
	call	empty_8042
	mov	al, 0DFh		; A20 line is going to be on from now on
	out	060h, al
	call	empty_8042
	ret

; This routine checks that the keyboard command queue is empty (after emptying the output buffers)
; for A20 Line enableing commands it deals with the 8042 chip whitch is used
; as a keyboard controller in PCs but also for many other extras
ALIGN 4
empty_8042:
	call	Delay
	in	al, 064h		; 8042 status port
	and	al, 10b		; unread data in input buffer?
	jz	no_output

	in	al, 060h		; yes, then read it
	jmp	empty_8042	; and of course we ignore it ;)
no_output:
	and	al, 01b		; is output buffer full?
	jnz	empty_8042	; yes - loop
	ret

; here is a short delay for input/output operations
ALIGN 4
Delay:
	db	0E9h, 0, 0, 0, 0
	db	0E9h, 0, 0, 0, 0
	ret

ALIGN 4
%include 'debug.asm'		;all debug messages
Kernel_Signature	db	'-=\AsteriOS/=-', 0
DataOutOfKernel		db	?

Kernel_End:
