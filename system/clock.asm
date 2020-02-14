;keyboard driver

SCREEN_MEM	equ	0B8000h

[BITS 32]

org 0

?			EQU	0

Executable_Start:

;executable header 38 bytes
Signature		db	'AsteriOS'
HeaderVersion		db	00010001b		;v.1.1 (4 hi-bits major version, 4 lo-bits minor version)
ExecutableCRC		dd	?			;including rest of header
ExecutableFlags		db	00011110b		;check below (execute init & stop, contains import & export)
ImportTableOffset	dd	ImportTable - Executable_Start
ExportTableOffset	dd	ExportTable - Executable_Start
RelocationTableOffset	dd	0
InitFunctionOffset	dd	InitClock - Executable_Start
StopFunctionOffset	dd	StopClock - Executable_Start
EntryPoint		dd	0

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
			;db	'HookInterrupt', 0
;HookInterrupt:		dd	?
			db	'GetInterruptAddress', 0
GetInterruptAddress:	dd	?
			db	'SetProcAddress', 0
SetProcAddress:		dd	?
			db	'GetCursor', 0
GetCursor:	dd	?
			db	'SetCursor', 0
SetCursor:			dd	?
			db	'PrintHex', 0
PrintHex:		dd	?
			db	'PrintXY', 0
PrintXY:		dd	?
			db	'Print', 0
Print:		dd	?
			db	0		;array terminates with null (byte)

ExportTable:
			db	'SetClockMode', 0
			dd	SetClockMode - Executable_Start
      db	'PrintClock', 0
			dd	PrintClock - Executable_Start
			db	0		;array terminates with null (byte)

;export table struct
;Function name (null terminated)
;dword size (in bytes) from the start of executable to the start of the function
;array terminates with null (byte)
;export table

;data

OldInt1C		dd	?

sClock	db	'Clock v.0.3', 13, 10, 0
sClockOn db 'Enabling clock...', 13, 10, 0
sClockOff db 'Disabling clock...', 13, 10, 0
UpTimeMask		db	' ?d ??:??:??', 0
ClockMask		db	'  :  :  ', 0
DecimalBuf times 15	db	0
DecimalBufT times 15	db	0

sSetClockMode		db	'SetClockMode', 0
sPrintClock		db	'PrintCLock', 0
ShowClock		db	0	;1=show
uptime_sec		db	0
uptime_min		db	0
uptime_hours		db	0
uptime_days		dw	0		;max 0xFFFF days!

last_sec		dd	"0000"
cmos_sec		dd	"1234"
cmos_min		dd	"1234"
cmos_hour		dd	"1234"

OS_loops		dd	0
OS_loops2		dd	0

align 4
FixAddress:
	nop
	call	.local
.local:	pop	eax
	sub	eax, .local
	ret

align 4
InitClock:
	push	ebp
	call	FixAddress
	mov	ebp, eax

	lea	eax, [ebp + sClock]
	push eax
	call	[ebp + Print]

	mov	dword [ebp + OS_loops], 0
	mov byte [ebp + uptime_sec], 0
	mov byte [ebp + uptime_min], 0
	mov byte [ebp + uptime_hours], 0
	mov byte [ebp + uptime_days], 0

	;push	dword [ebp + sSetClockMode]
	;push	dword [ebp + SetClockMode]
	;call	[ebp + SetProcAddress]

  ;push	dword [ebp + sPrintClock]
	;push	dword [ebp + PrintCLock]
	;call	[ebp + SetProcAddress]

	mov	byte [ebp + ShowClock], 0

	pop	ebp
	ret

;IRQ entry point here
IRQ_Timer:

align 4
SetClockMode:
		push ebp

		push 	eax
		call	FixAddress
		mov		ebp, eax
		pop 	eax

		mov	byte [ebp + ShowClock], al

		cmp 	al, 1
		je		.set_on
		lea		eax, [ebp + sClockOff]
		jmp 	.print_now
.set_on:
		lea	eax, [ebp + sClockOn]
.print_now:
		push eax
		call	[ebp + Print]

		pop ebp
		ret

align 4
;Clear everything to unload driver
StopClock:
	push	ebp
	call	FixAddress
	mov	ebp, eax

	;mov	byte [ebp + ShowClock], 0

	;set back old address
	;push	dword 1Ch
	;push	dword [ebp + OldInt1C]
	;call	[ebp + HookInterrupt]

	;unregister function
	;stop process

	pop	ebp
	ret


Print_OS_Loops:
	;pushad
	call	[ebp + GetCursor]
	push	eax
	mov	eax, 0030h
	call	[ebp + SetCursor]
	;mov	ebx, [ebp + OS_loops]
	push	dword [ebp + OS_loops]
	call	[ebp + PrintHex]
	pop	eax
	call	[ebp + SetCursor]
	;popad
	ret

; inc system uptime
Inc_Uptime:
	pushad

	cld
	inc	byte [ebp + uptime_sec]
	cmp	byte [ebp + uptime_sec], 60
	jne	.exit

	mov	byte [ebp + uptime_sec], 0
	inc	byte [ebp + uptime_min]
	cmp	byte [ebp + uptime_min], 60
	jne	.exit

	mov	byte [ebp + uptime_min], 0
	inc	byte [ebp + uptime_hours]
	cmp	byte [ebp + uptime_hours], 24
	jne	.exit

	mov	byte [ebp + uptime_hours], 0
	inc	byte [ebp + uptime_days]
.exit:

	;UpTimeMask		db	'  d 00:00:00', 0
	movzx	ebx, word [ebp + uptime_days]
	push	ebx
	call	MakeDecimal
	mov	esi, [ebp + DecimalBufT]
	lea	edi, [ebp + UpTimeMask]

	cmp	word [ebp + uptime_days], 10
	jb	.Inc_Uptime_1
	lodsb
	mov	[edi], al
.Inc_Uptime_1:
	inc	edi
	lodsb
	mov	[edi], al
	add	edi, 3

	movzx 	ebx, byte [ebp + uptime_hours]
	push	ebx
	call	MakeDecimal
	mov	esi, [ebp + DecimalBufT]
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

	movzx 	ebx, byte [ebp + uptime_min]
	push	ebx
	call	MakeDecimal
	mov	esi, [ebp + DecimalBufT]
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

	movzx 	ebx, byte [ebp + uptime_sec]
	push	ebx
	call	MakeDecimal
	mov	esi, [ebp + DecimalBufT]
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
	lea	eax, [ebp + UpTimeMask]
	push	eax
	push	dword 0039h		;line 1 column 70
	call	[ebp + PrintXY]
	ret

;Print system clock
PrintClock:
	push ebp

	push 	eax
	call	FixAddress
	mov		ebp, eax
	pop 	eax

	pushad
	pushfd

	cld
	mov	eax, dword [ebp + cmos_sec]
	mov	dword [ebp + last_sec], eax
	xor	eax, eax
	out	70h, al
	call	Delay
	in	al, 71h
	mov	dword [ebp + cmos_sec], eax

	cmp	eax, dword [ebp + last_sec]
	jne	.ok
	jmp	.Exit
.ok:

	call	Inc_Uptime

	cmp byte [ebp + ShowClock], 0
	je .Exit

	call	PrintUpTime
	;call	CPULoad
	;call	Print_OS_Loops

	mov	al, 2
	out	70h, al
	call	Delay
	in	al, 71h
	mov	dword [ebp + cmos_min], eax

	mov	al, 4
	out	70h, al
	call	Delay
	in	al, 71h
	mov	dword [ebp + cmos_hour], eax

	lea	eax, [ebp + ClockMask]
	push	eax
	push	dword 0047h		;line 1 column 71
	call	[ebp + PrintXY]

	pushad
	mov	eax, dword [ebp + cmos_hour]
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
	mov	esi, [ebp + DecimalBufT]

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
	mov	eax, dword [ebp + cmos_min]
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
	mov	esi, [ebp + DecimalBufT]

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
	mov	eax, dword [ebp + cmos_sec]
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
	mov	esi, [ebp + DecimalBufT]

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

	pop ebp

  ret
	;iretd

;Converts number Decimal format string
MakeDecimal:
	push	ebp
	mov	ebp, esp
	add	ebp, 8

	push	esi
	push	edi
	push	ebx
	push	ecx
	push	edx

	mov	eax, [ebp]
	mov	edi, [ebp + DecimalBuf]
	cmp	eax, 0
	jne	.doit
	mov	edi, [ebp + DecimalBufT]
	mov	byte [edi], '0'
	inc	edi
	jmp	.exit_now
.doit:
     	mov	ebx, 10
     	xor	ecx, ecx
     	xor	edx, edx
.loop:
	cmp	eax, 0
	je	.exit
	push	edx
	inc	ecx
	xor	edx, edx
	div	ebx
	add	dl, 48
	mov	byte [edi], dl
	inc   	edi
	pop	edx
	inc	edx
	cmp	edx, 3
	jne	.loop
	xor	edx, edx
	mov	byte [edi], '.'
	inc 	edi
	inc	ecx
	jmp	.loop
.exit:
	dec	edi
	mov	esi, edi
	mov	edi, [ebp + DecimalBufT]
	cmp	byte [esi], '.'
	jne	.next
	dec	esi
.next:
	mov	al, byte [esi]
	mov	byte [edi], al
	inc	edi
	dec	esi
	dec	ecx
	jnz	.next
.exit_now:
	mov	byte [edi], 0

	pop	edx
	pop	ecx
	pop	ebx
	pop	edi
	pop	esi
	pop	ebp
  ret	4


Delay:
	db	0E9h, 0, 0, 0, 0
	db	0E9h, 0, 0, 0, 0
	ret
