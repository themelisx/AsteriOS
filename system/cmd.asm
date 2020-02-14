;CmdLine driver
;%define DEBUG

[BITS 32]

org 0

?			EQU	0
MAX_COMMANDS 		EQU	20
MAX_CMD_NAME		EQU	12	;ASCIIZ
CMD_LINE_ARRAY_SIZE	EQU	MAX_COMMANDS * (MAX_CMD_NAME + 4)
CMD_LINE_BUFFER_SIZE	EQU	127

FILE_NAME_SIZE			EQU	512 - 20 	;512-(5*4)
OPEN_FILE_STRUCT_SIZE		EQU	FILE_NAME_SIZE + 20

Driver_Start:

;executable header 38 bytes
Signature		db	'AsteriOS'
HeaderVersion		db	00010001b		;v.1.0 (4 hi-bits major version, 4 lo-bits minor version)
ExecutableCRC		dd	?			;including rest of header
ExecutableFlags		db	00011110b		;check below (execute init & stop, contains import & export)
ImportTableOffset	dd	ImportTable - Driver_Start
ExportTableOffset	dd	ExportTable - Driver_Start
RelocationTableOffset	dd	0
InitFunctionOffset	dd	InitCmdLine - Driver_Start
StopFunctionOffset	dd	StopCmdLine - Driver_Start
EntryPoint		dd	?

;executable flags (0=no, 1=yes)
;0 = Execute EIP
;1 = Execute Init function
;2 = Execute Stop function
;3 = Contains Import table
;4 = Contains Export table
;5 = Contains Relocations
;6 = Executable is encrypted
;7 = Executable is compressed

ImportTable:
      db	'ShowCpuInfo', 0
ShowCpuInfo:	dd	?
      db	'GetMaxOpenFiles', 0
GetMaxOpenFiles:	dd	?
			db	'GetOpenFilesArray', 0
GetOpenFilesArray	dd	?
			db	'SetClockMode', 0
SetClockMode:		dd	?
			db	'Print', 0
Print:			dd	?
			db	'PrintHex', 0
PrintHex:		dd	?
			db	'PrintCRLF', 0
PrintCRLF:		dd	?
			db	'PrintChar', 0
PrintChar:		dd	?
			db	'PrintHexView', 0
PrintHexView:		dd	?
			db	'MemAlloc', 0
MemAlloc:		dd	?
			db	'MemFree', 0
MemFree:		dd	?
			db	'MemSet', 0
MemSet:			dd	?
			db	'StrLen', 0
StrLen:			dd	?
			db 	'StrCmp', 0
StrCmp:			dd	?
			db	'StrCpy', 0
StrCpy:			dd	?
			db	'ToLower', 0
ToLower:		dd	?
			db	'ToUpper', 0
ToUpper:		dd	?
			db	'PrintMemoryMap', 0
PrintMemoryMap:		dd	?
			db	'PrintIRQList', 0
PrintIRQList:		dd	?
			db	'DeleteCurrentChar', 0
DeleteCurrentChar:	dd	?
			db	'PrintTextFile', 0
PrintTextFile:		dd	?
			db	'IsFileOpen', 0
IsFileOpen:		dd	?
			db	'OpenFile', 0
OpenFile:		dd	?
			db	'CloseFile', 0
CloseFile:		dd	?
			db	'LoadFile', 0
LoadFile:		dd	?
			db	'GetFileSize', 0
GetFileSize:		dd	?
			db	'DirList', 0
DirList:		dd	?
			db	'LoadExecutable', 0
LoadExecutable:		dd	?
			db	'GetSystemLoaded', 0
GetSystemLoaded:	dd	?
			db	'GetCurrentDirectory', 0
GetCurrentDirectory:	dd	?
			db	'GetOSPrompt', 0
GetOSPrompt:		dd	?
			db	'GetKey', 0
GetKey:			dd	?
			db	'ClearScreen', 0
ClearScreen:	dd	?
			db	'CreateFile', 0
CreateFile:		dd	?
			db	0		;array terminates with null (byte)

ExportTable:
			db	'CheckCmdLineBuffer', 0
			dd	CheckCmdLineBuffer - Driver_Start
			db	0		;array terminates with null (byte)

;export table struct
;Function name (null terminated)
;dword size (in bytes) from the start of executable to the start of the function
;array terminates with null (byte)
;export table

;data

sHelp			db	'Help', 0
sIRQ			db	'Irq', 0
sRAM			db	'Ram', 0
sCD			db	'CD', 0
sDirList		db	'Dir', 0
sPrintFile		db	'Print', 0
sPrintHex		db	'PrintHex', 0
sLoad			db	'Load', 0
sEcho			db	'Echo', 0
sClock			db	'Clock', 0
sOpenFiles		db	'OpenFiles', 0
sNew			db	'New', 0
sReboot			db	'Reboot', 0
sCls			db	'Cls', 0
sCpu			db	'CPU', 0
;sDrives			db	'Drives', 0

CurrentDrive			db	'?:'
CurrentDirectory times 255 	db	0

FileWasOpen		db	?

CmdLineArray		dd	?
CmdLineArrayPtr		dd	0
CmdLineBufferPtr	db	0
CmdLineBuffer		dd	?
CmdLineParam		dd	?

bufLoad			dd	?
szLoad			dd	?
hLoad			dd	?

sOn			db	'ON', 0
sOff			db	'OFF', 0
Unknown_command		db  	'Unknown command: "%s"', 13, 0
sClockSyntax		db	'Syntax: Clock on|off', 13, 0
sOpenFile		db	'File:%s, drv:%x, FS:%x, ptr:%d, size:%d, addr:%x', 13, 0
PressAnyKey		db	'Press any key...', 13, 0

Debug_InitCmdLine	db	'[Init] Command line', 13, 0
Debug_StopCmdLine	db	'[Stop] Command line', 13, 0
;Debug_AddCommand	db	'Adding command "%s", addr:0x%x', 13, 0
Debug_CheckCmdLine	db	'Command:"%s", param:"%s"', 13, 0

align 4
FixAddress:
	nop
	call	.local
.local:	pop	eax
	sub	eax, .local
	ret

align 4
InitCmdLine:
	push	ebp
	call	FixAddress
	mov	ebp, eax

	%ifdef DEBUG
	lea 	eax, [ebp + Debug_InitCmdLine]
	push	eax
	call	[ebp + Print]
	%endif

	mov	byte [ebp + CmdLineBufferPtr], 0
	push	dword CMD_LINE_BUFFER_SIZE
	call	[ebp + MemAlloc]
	mov	dword [ebp + CmdLineBuffer], eax

	push	dword CMD_LINE_BUFFER_SIZE
	call	[ebp + MemAlloc]
	mov	dword [ebp + CmdLineParam], eax

	mov	dword [ebp + CmdLineArrayPtr], 0
	push	dword CMD_LINE_ARRAY_SIZE
	call	[ebp + MemAlloc]
	mov	dword [ebp + CmdLineArray], eax

	push	eax
	push	dword CMD_LINE_ARRAY_SIZE
	push	dword 0
	call	[ebp + MemSet]

	call	AddCommands
	call	Clear_cmd_line_buffer

	pop	ebp
	ret

align 4
;Clear everything to unload driver
StopCmdLine:
	push	ebp
	call	FixAddress
	mov	ebp, eax

	%ifdef DEBUG
	lea 	eax, [ebp + Debug_StopCmdLine]
	push	eax
	call	[ebp + Print]
	%endif


	push	dword [ebp + CmdLineBuffer]
	call	[ebp + MemFree]
	push	dword [ebp + CmdLineParam]
	call	[ebp + MemFree]
	push	dword [ebp + CmdLineArray]
	call	[ebp + MemFree]

	pop	ebp
	ret

align 4
CheckCommand:
	push	ebp
	call	FixAddress
	mov	ebp, eax
	cmp	byte [ebp + CmdLineBufferPtr], 0
	jne	.continue1			;no command. just enter pressed
	pop	ebp
	ret
.continue1:
	push	ecx
	push	edx
	push	esi
	push	edi

	mov	esi, dword [ebp + CmdLineBuffer]
	push 	esi
	push	esi
	call	[ebp + ToLower]

	%ifdef DEBUG
	push	dword [ebp + CmdLineParam]
	push	dword [ebp + CmdLineBuffer]
	lea 	eax, [ebp + Debug_CheckCmdLine]
	push	eax
	call	[ebp + Print]
	%endif

	mov	edi, dword [ebp + CmdLineArray]
	mov	edx, MAX_COMMANDS
.loop:
	cmp	edx, 0
	je	.unknown
	cmp	byte [edi], 0
	je	.next
	push	edi
	mov	esi, dword [ebp + CmdLineBuffer]
	movzx	ecx, byte [ebp + CmdLineBufferPtr]
	inc	ecx
	repe	cmpsb
	jz	.found
	pop	edi
.next:
	add	edi, MAX_CMD_NAME + 4		;name + address
	dec	edx
	jmp	.loop
.unknown:
	push	dword [ebp + CmdLineBuffer]
	lea	eax, [ebp + Unknown_command]
	push	eax
	call	[ebp + Print]
	jmp	.exit
.found:
	pop	edi
	add	edi, MAX_CMD_NAME
	mov	eax, dword [edi]
	call	eax
.exit:
	call	[ebp + PrintCRLF]
	call	Clear_cmd_line_buffer

	pop	edi
	pop	esi
	pop	edx
	pop	ecx
	pop	ebp
	ret

align 4
AddCommands:
	push	ebp
	call	FixAddress
	mov	ebp, eax

	lea	eax, [ebp + sHelp]
	push	eax
	lea	eax, [ebp + cmd_help]
	push	eax
	call	AddCommand

	lea	eax, [ebp + sIRQ]
	push	eax
	lea	eax, [ebp + cmd_IRQ]
	push	eax
	call	AddCommand

	lea	eax, [ebp + sRAM]
	push	eax
	lea	eax, [ebp + cmd_RAM]
	push	eax
	call	AddCommand

	lea	eax, [ebp + sDirList]
	push	eax
	lea	eax, [ebp + cmd_Dir]
	push	eax
	call	AddCommand

	lea	eax, [ebp + sCD]
	push	eax
	lea	eax, [ebp + cmd_CD]
	push	eax
	call	AddCommand

	lea	eax, [ebp + sPrintFile]
	push	eax
	lea	eax, [ebp + cmd_PrintFile]
	push	eax
	call	AddCommand

	lea	eax, [ebp + sPrintHex]
	push	eax
	lea	eax, [ebp + cmd_PrintHex]
	push	eax
	call	AddCommand

	lea	eax, [ebp + sLoad]
	push	eax
	lea	eax, [ebp + cmd_Load]
	push	eax
	call	AddCommand

	lea	eax, [ebp + sEcho]
	push	eax
	lea	eax, [ebp + cmd_Echo]
	push	eax
	call	AddCommand

	lea	eax, [ebp + sClock]
	push	eax
	lea	eax, [ebp + cmd_Clock]
	push	eax
	call	AddCommand

	lea	eax, [ebp + sOpenFiles]
	push	eax
	lea	eax, [ebp + cmd_OpenFiles]
	push	eax
	call	AddCommand

	lea	eax, [ebp + sNew]
	push	eax
	lea	eax, [ebp + cmd_New]
	push	eax
	call	AddCommand

	lea	eax, [ebp + sReboot]
	push	eax
	lea	eax, [ebp + cmd_Reboot]
	push	eax
	call	AddCommand

	lea	eax, [ebp + sCls]
	push	eax
	lea	eax, [ebp + cmd_Cls]
	push	eax
	call	AddCommand

  lea	eax, [ebp + sCpu]
	push	eax
	lea	eax, [ebp + cmd_Cpu]
	push	eax
	call	AddCommand

	;lea	eax, [ebp + sDrives]
	;push	eax
	;lea	eax, [ebp + cmd_Drives]
	;push	eax
	;call	AddCommand

	pop	ebp
	ret

;input:
;command (asciiz)
;function address
align 4
AddCommand:
	push	ebp
	mov	ebp, esp
	add	ebp, 8
	push	esi
	push	ecx

	push	ebx
	call	FixAddress
	mov	ebx, eax

	mov	ecx, MAX_COMMANDS
	mov	esi, dword [ebx + CmdLineArray]
.loop:
	cmp	ecx, 0
	je	.exit
	cmp	byte [esi], 0
	je	.fill
	add	esi, MAX_CMD_NAME + 4		;name + address
	dec	ecx
	jmp	.loop
.fill:
	push	dword [ebp+4]
	push	esi
	call	[ebx + ToLower]			;copy and make lower
	add	esi, MAX_CMD_NAME
	mov	eax, dword [ebp]
	mov	dword [esi], eax
.exit:
	;push	dword [ebp]
	;push	dword [ebp+4]
	;lea	eax, [ebx + Debug_AddCommand]
	;push	eax
	;call	[ebp + PrintDebug]

	pop	ebx
	pop	ecx
	pop	esi
	pop	ebp
	ret	2*4

align 4
CheckParam:
	push	ebp
	call	FixAddress
	mov	ebp, eax

	push	esi
	mov	esi, dword [ebp + CmdLineBuffer]
.loop:
	mov	al, byte [esi]
	cmp	al, 0
	je	.exit
	cmp	al, ' '
	je	.param
	inc	esi
	jmp	.loop
.param:
	mov	byte [esi], 0		;seperate cmd from param
.trimleft:
	inc	esi
	cmp	byte [esi], 0
	je	.next_trim
	cmp	byte [esi], ' '
	je	.trimleft
.next_trim:
	push	esi		;save
	push	esi
	call	[ebp + StrLen]
	cmp	al, 0
	je	.ok
	and	eax, 0FFh
	dec	eax
	add	esi, eax
	push	ecx
	mov	ecx, eax
.trim_right:
	cmp	ecx, 0
	je	.ok
	cmp	byte [esi], ' '
	jne	.ok
	mov	byte [esi], 0
	dec	esi
	dec	ecx
	jmp	.trim_right
.ok:
	pop	ecx
	pop	esi		;restore

	push	esi
	push	dword [ebp + CmdLineParam]
	call	[ebp + ToLower]
	push	dword [ebp + CmdLineBuffer]
	call	[ebp + StrLen]

	mov	byte [ebp + CmdLineBufferPtr], al
.exit:
	pop	esi
	pop	ebp
	ret

align 4
CheckCmdLineBuffer:
	push	ebp

	push	eax		;input byte=al
	call	FixAddress
	mov	ebp, eax
	pop	eax
	;29             ; CTRL
	;56             ; ALT
	;42             ; SHIFT
	cmp	al, 13		;enter
	jne	.next2

	call	[ebp + PrintCRLF]
	call	CheckParam
	call	CheckCommand

	call	[ebp + GetCurrentDirectory] 	;drive and path
	push	eax
	lea	eax, [ebp + CurrentDrive]
	push	eax
	call	[ebp + StrCpy]

	lea	eax, [ebp + CurrentDrive]		;and directory
	push	eax
	call	[ebp + GetOSPrompt]			;returns in eax the string addr
	push	eax
  call	[ebp + Print]

	jmp	.exit

.next2:
	cmp	al, 27		;ESC
	jne	.next3

	cmp	byte [ebp + CmdLineBufferPtr], 0
	je	.exit
	push	ecx
	movzx	ecx, byte [ebp + CmdLineBufferPtr]
.loop:
	call	[ebp + DeleteCurrentChar]		;from screen
	dec	ecx
	jnz	.loop
	pop	ecx
	call	Clear_cmd_line_buffer
	jmp	.exit

.next3:
	cmp	al, 8		;backspace
	jne	.next4

	cmp	byte [ebp + CmdLineBufferPtr], 0
	je	.exit

	dec	byte [ebp + CmdLineBufferPtr]
	movzx	eax, byte [ebp + CmdLineBufferPtr]
	push	esi
	mov	esi, dword [ebp + CmdLineBuffer]
	add	esi, eax
	mov	byte [esi], 0
	pop	esi
	call	[ebp + DeleteCurrentChar]		;from screen
	jmp	.exit

.next4:
	push	ebx
	push	esi
	movzx	ebx, byte [ebp + CmdLineBufferPtr]
	mov	esi, dword [ebp + CmdLineBuffer]
	add	esi, ebx
	mov	byte [esi], al
	inc	byte [ebp + CmdLineBufferPtr]
	inc	esi
	mov	byte [esi], 0
	pop	esi
	pop	ebx

	call	[ebp + PrintChar]
.exit:
	pop	ebp
	ret

align 4
Clear_cmd_line_buffer:
	push	ebp
	call	FixAddress
	mov	ebp, eax

	mov	byte [ebp + CmdLineBufferPtr], 0
	push	esi
	mov	esi, dword [ebp + CmdLineBuffer]
	mov	byte [esi], 0
	mov	esi, dword [ebp + CmdLineParam]
	mov	byte [esi], 0
	pop	esi

	pop	ebp
	ret




;;;;;;;;;;;;;;;;;;;;;
;;; user commands ;;;
;;;;;;;;;;;;;;;;;;;;;

align 4
cmd_Reboot:
	mov	al, 0FEh
	out	64h, al			;this cause a soft reset (reboot)
	jmp $

align 4
cmd_Drives:
	push	ebp
	call	FixAddress
	mov	ebp, eax

	;call	[ebp + GetATAInfo]

	pop	ebp
	ret

align 4
cmd_New:
	push	ebp
	call	FixAddress
	mov	ebp, eax

	push	dword [ebp + CmdLineParam]
	call	[ebp + StrLen]
	cmp	eax, 0
	je	.exit

	push	dword [ebp + CmdLineParam]
	call	[ebp + CreateFile]

.exit:
	pop	ebp
	ret

align 4
cmd_OpenFiles:
	push	ebp
	call	FixAddress
	mov	ebp, eax

	call	[ebp + GetOpenFilesArray]
	mov	edi, eax
	call	[ebp + GetMaxOpenFiles]
	mov	ecx, eax
.loop:
	cmp	byte [edi], 0
	je	.next
;name
;driver
;FS
;File pointer
;size
;memory address
	push	dword [edi + FILE_NAME_SIZE+16]	;loaded address
	push	dword [edi + FILE_NAME_SIZE+12]	;size
	push	dword [edi + FILE_NAME_SIZE+8]	;Pointer
	push	dword [edi + FILE_NAME_SIZE+4]	;FS
	push	dword [edi + FILE_NAME_SIZE]	;driver
	push	dword edi
	lea	eax, [ebp + sOpenFile]
	push	eax
	call	[ebp + Print]
.next:
	add	edi, OPEN_FILE_STRUCT_SIZE
	dec	ecx
	jnz	.loop
.exit:
	pop	ebp
	ret

align 4
cmd_help:
	push	ebp
	call	FixAddress
	mov	ebp, eax

	push	esi
	push	ecx
	mov	esi, dword [ebp + CmdLineArray]
	mov	ecx, MAX_COMMANDS
.loop:
	cmp	ecx, 0
	je	.exit
	cmp	byte [esi], 0
	je	.next
	push	esi
	call	[ebp + Print]
	call	[ebp + PrintCRLF]
.next:
	add	esi, MAX_CMD_NAME + 4		;name + address
	dec	ecx
	jmp	.loop
.exit:

	pop	ecx
	pop	esi
	pop	ebp
	ret

align 4
cmd_PrintHex:
	push	ebp
	call	FixAddress
	mov	ebp, eax

	push	dword [ebp + CmdLineParam]
	call	[ebp + StrLen]
	cmp	eax, 0
	jne	.next
	pop	ebp
	ret
.next:
	pushad

	mov	byte [ebp + FileWasOpen], 0

	push	dword [ebp + CmdLineParam]
	call	[ebp + IsFileOpen]
	cmp	eax, -1
	je	.openit

	mov	byte [ebp + FileWasOpen], 1
	jmp	.ok1
.openit:
	push	dword [ebp + CmdLineParam]
	call	[ebp + OpenFile]
	cmp	eax, -1
	jne	.ok1
	jmp	.error
.ok1:

	mov	dword [ebp + hLoad], eax

	push	dword [ebp + hLoad]
	call	[ebp + GetFileSize]
	mov	dword [ebp + szLoad], eax

	push	dword [ebp + szLoad]
	call	[ebp + MemAlloc]
	mov	dword [ebp + bufLoad], eax

	push	dword [ebp + hLoad]
	push	dword [ebp + bufLoad]
	push	dword [ebp + szLoad]
	call	[ebp + LoadFile]

	mov	ecx, dword [ebp + szLoad]
	mov	esi, dword [ebp + bufLoad]
	mov	edx, 20*16
.loop:
	cmp	ecx, 20*16
	jg	.ok
	mov	edx, ecx
.ok:
	push	esi
	push	edx
	call	[ebp + PrintHexView]

	cmp	ecx, edx
	je	.exit

	lea 	eax, [ebp + PressAnyKey]
	push	eax
	call	[ebp + Print]
	;call	[ebp + GetKey]

	sub	ecx, 20*16
	add	esi, 20*16
	jmp	.loop
.exit:
	push	dword [ebp + bufLoad]
	call	[ebp + MemFree]

	cmp	byte [ebp + FileWasOpen], 1
	je	.error				;was open, dont close it

	push	dword [ebp + CmdLineParam]
	call	[ebp + CloseFile]
.error:
	popad
	pop	ebp
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
align 4
cmd_IRQ:
	call	FixAddress
	call	[eax + PrintIRQList]
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
align 4
cmd_CD:
	push	ebp
	call	FixAddress
	mov	ebp, eax

	call	[ebp + GetCurrentDirectory] 	;drive and path
	push	eax
	lea	eax, [ebp + CurrentDrive]
	push	eax
	call	[ebp + StrCpy]

	lea 	eax, [ebp + CurrentDrive]
	push	eax
	call	[ebp + Print]

	pop	ebp
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
align 4
cmd_Dir:
	push	ebp
	call	FixAddress
	mov	ebp, eax
	;todo: pass real params (drive:\directory)

	call	[ebp + GetCurrentDirectory] 	;drive and path
	push	eax
	lea	eax, [ebp + CurrentDrive]
	push	eax
	call	[ebp + StrCpy]

	lea	eax, [ebp + CurrentDrive]
	push	eax
	call	[ebp + DirList]
	pop	ebp
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
align 4
cmd_RAM:
	call	FixAddress
	call	[eax + PrintMemoryMap]
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

align 4
cmd_Clock:
	push	ebp
	call	FixAddress
	mov	ebp, eax

	push	dword [ebp + CmdLineParam]
	call	[ebp + StrLen]
	cmp	eax, 0
	je	.printsyntax
	push	dword [ebp + CmdLineParam]
	push	dword [ebp + CmdLineParam]
	call	[ebp + ToUpper]
	push	dword [ebp + CmdLineParam]
	lea	eax, [ebp + sOn]
	push	eax
	call	[ebp + StrCmp]
	cmp	eax, 0
	je	.makeON
	push	dword [ebp + CmdLineParam]
	lea	eax, [ebp + sOff]
	push	eax
	call	[ebp + StrCmp]
	cmp	eax, 0
	je	.makeOFF
.printsyntax:
	lea 	eax, [ebp + sClockSyntax]
	push	eax
	call	[ebp + Print]
	jmp	.exit
.makeON:
	mov	eax, 1
	call	[ebp + SetClockMode]
	jmp	.exit
.makeOFF:
	mov	eax, 0
	call	[ebp + SetClockMode]
.exit:
	pop	ebp
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
align 4
cmd_Echo:
	push	ebp
	call	FixAddress
	mov	ebp, eax

	push	dword [ebp + CmdLineParam]
	call	[ebp + StrLen]
	cmp	eax, 0
	jne	.next
	pop	ebp
	ret
.next:
	push	dword [ebp + CmdLineParam]
	call	[ebp + Print]
	pop	ebp
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
align 4
cmd_Cls:
	call	FixAddress
	call	[eax + ClearScreen]
	ret

cmd_Cpu:
	call	FixAddress
	call	[eax + ShowCpuInfo]
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
align 4
cmd_Load:
	push	ebp
	call	FixAddress
	mov	ebp, eax

	push	dword [ebp + CmdLineParam]
	call	[ebp + StrLen]
	cmp	eax, 0
	jne	.next
	pop	ebp
	ret
.next:
	;TODO: set somewhere that file is loaded to so can be unload
	;at close file???
	push	dword [ebp + CmdLineParam]
	call	[ebp + OpenFile]
	cmp	eax, -1
	je	.exit
	mov	dword [ebp + hLoad], eax

	push	dword [ebp + hLoad]
	call	[ebp + GetFileSize]
	mov	dword [ebp + szLoad], eax

	push	dword [ebp + szLoad]
	call	[ebp + MemAlloc]
	mov	dword [ebp + bufLoad], eax

	push	dword [ebp + hLoad]
	push	dword [ebp + bufLoad]
	push	dword [ebp + szLoad]
	call	[ebp + LoadFile]

	push	dword [ebp + bufLoad]
	call	[ebp + LoadExecutable]
	cmp	eax, -1
	jne	.exit
		;first close file and then free mem
		;cause CloseFile maybe executes "Stop" function
		push	dword [ebp + CmdLineParam]
		call	[ebp + CloseFile]
		push	dword [ebp + bufLoad]
		call	[ebp + MemFree]
.exit:
	pop	ebp
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
align 4
cmd_PrintFile:
	push	ebp
	call	FixAddress
	mov	ebp, eax

	push	dword [ebp + CmdLineParam]
	call	[ebp + StrLen]
	cmp	eax, 0
	jne	.next
	pop	ebp
	ret
.next:
	pushad

	mov	byte [ebp + FileWasOpen], 0

	push	dword [ebp + CmdLineParam]
	call	[ebp + IsFileOpen]
	cmp	eax, -1
	je	.openit

	mov	byte [ebp + FileWasOpen], 1
	jmp	.ok1
.openit:

	push	dword [ebp + CmdLineParam]
	call	[ebp + OpenFile]
	cmp	eax, -1
	je	.error
.ok1:
	mov	dword [ebp + hLoad], eax

	push	dword [ebp + hLoad]
	call	[ebp + GetFileSize]
	mov	dword [ebp + szLoad], eax

	push	dword [ebp + szLoad]
	call	[ebp + MemAlloc]
	mov	dword [ebp + bufLoad], eax

	push	dword [ebp + hLoad]
	push	dword [ebp + bufLoad]
	push	dword [ebp + szLoad]
	call	[ebp + LoadFile]

	push	dword [ebp + bufLoad]
	push	dword [ebp + szLoad]
	call	[ebp + PrintTextFile]

	push	dword [ebp + bufLoad]
	call	[ebp + MemFree]

	cmp	byte [ebp + FileWasOpen], 1
	je	.error				;was open, dont close it

	push	dword [ebp + CmdLineParam]
	call	[ebp + CloseFile]
.error:
	popad
	pop	ebp
	ret
