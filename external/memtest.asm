[BITS 32]

org 0

?			equ	0

Executable_Start:

;executable header 34 bytes
Signature		db	'AsteriOS'
HeaderVersion		db	00010000b		;v.1.0 (4 hi-bits major version, 4 lo-bits minor version)
ExecutableCRC		dd	?			;including rest of header
ExecutableFlags		db	00001001b		;check below (execute init & stop, contains import & export)
ImportTableOffset	dd	ImportTable - Executable_Start
ExportTableOffset	dd	?
RelocationTableOffset	 dd	0
InitFunctionOffset	dd	?
StopFunctionOffset	dd	?
EntryPoint		dd	ExecutableEIP - Executable_Start

;executable flags (0=no, 1=yes)
;0 = Execute EIP
;1 = Execute Init function
;2 = Execute Stop function
;3 = Contains Import table
;4 = Contains Export table
;5 = Executable is encrypted
;6 = Executable is compressed
;7 = (unused)
ImportTable:
			db  'GetCursor', 0
GetCursor:		dd ?
			db  'SetCursor', 0
SetCursor:		dd ?
			db  'GetSystemRam', 0
GetSystemRam:		dd ?
			db	'GetKeyboardCallback', 0
GetKeyboardCallback:	dd	?
			db	'GetMemoryManagerTableSize', 0
GetMemoryManagerTableSize:	dd	?
			db	'GetMemoryManagerTable', 0
GetMemoryManagerTable:	dd	?
			db	'SetKeyboardCallback', 0
SetKeyboardCallback:	dd	?
			db	'GetKeyboardQueue', 0
GetKeyboardQueue:		dd	?
			db	'PrintXY', 0
PrintXY:	dd	?
			db	'PrintLine', 0
PrintLine:	dd	?
			db	'Print', 0
Print:		dd	?
			db	'PrintHex', 0
PrintHex:	dd	?
;			db	'PrintHexXY', 0
;PrintHexXY:	dd	?
			db	'ClearScreen', 0
ClearScreen:	dd	?
			db	0		;array terminates with null (byte)
ExportTable:
			db	0		;array terminates with null (byte)

;data

sVersion	db	'Memory Tester v.0.2', 13, 0
ReadingAddress		db	'Reading 0x%x of 0x%x', 0
WritingAddress		db	'Writing 0x%x of 0x%x', 0
VerifyingAddress	db	'Verify  0x%x of 0x%x', 0
Passed		db	'[Passed]', 0
Finished	db  'Test completed. Press ESC to reboot', 0
Aborted		db  'Test aborted. Press ESC to reboot', 0
EscToAbort db	'Press ESC to abort', 0
EscToAbort2 db	'                  ', 0
;ByPassingAddress	db	'Bypassing 0x%x (total blocks:%d)', 0
;CheckingAddress		db	'Checking 0x%x - 0x%x', 0
;s1				db  'key press', 13, 0
myFlag		dd	?
MMT				dd	?
MMTS			dd	?
NotCheckedBlocks dd	?
Memory_Table_Entry	db	'%x, size:%x', 13, 0
SystemRam dd ?

align 4
FixAddress:
	nop
	call	.local
.local:	pop	eax
	sub	eax, .local
	ret

align 4
;entry point here
ExecutableEIP:
	push ebp
	call	FixAddress
	mov		ebp, eax
	call	[ebp + GetKeyboardCallback]

	push	eax				;save old value

	lea		eax, [ebp + MyKeyboardCallback]
	push	eax
	call	[ebp + SetKeyboardCallback]


	call	[ebp + ClearScreen]

	mov		dword [ebp + myFlag], 0

	lea		eax, [ebp + EscToAbort]
	push	eax
	push	dword 1801h		;line 25 column 1
	call	[ebp + PrintXY]

	lea		eax, [ebp + sVersion]
	push	eax
	push	dword 0100h		;line 1 column 0
	call	[ebp + PrintXY]

	push	dword 0200h		;line 2, col 0
	call	[ebp + PrintLine]


		call	[ebp + GetMemoryManagerTable]
		mov		dword [ebp + MMT], eax			;MemoryTableAddress
		call	[ebp + GetMemoryManagerTableSize]
		mov		dword [ebp + MMTS], eax			;MemoryTableAddressSize
		call	[ebp + GetSystemRam]
		shr		eax, 12		;eax=eax/4096
		mov		dword [ebp + SystemRam], eax


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; reading test
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		mov		ecx, [ebp + SystemRam]
		mov		edx, ecx
		shl		edx, 12				;/4096
		sub		edx, 4096 		;start from 0 (so total mem -1 block)
		mov		esi, 0

.readtest:
		cmp		dword [ebp + myFlag], 1
		jne		.readtest2
		jmp 	.exit
.readtest2:

		push	esi
		mov		eax,  0300h
		call	[ebp + SetCursor]

		push	edx
		push	esi
		lea 	eax, [ebp + ReadingAddress]
		push	eax
		call	[ebp + Print]
		pop		esi

		push	ecx
		mov		ecx, 1024 	;4096 bytes
		rep		lodsd
		pop		ecx
		loop	.readtest

		mov		eax,  0322h
		call	[ebp + SetCursor]
		lea 	eax, [ebp + Passed]
		push	eax
		call	[ebp + Print]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; writing test 1
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.writetest0:
		mov		ecx, [ebp + SystemRam]
		mov		edx, ecx
		shl		edx, 12				;/4096
		sub		edx, 4096 		;start from 0 (so total mem -1 block)
		mov		edi, 0

.writetest1:
		cmp		dword [ebp + myFlag], 1
		jne		.writetest12
		jmp 	.exit
.writetest12:

		push	edi
		mov		eax,  0400h
		call	[ebp + SetCursor]

		push	edx
		push	edi
		lea 	eax, [ebp + WritingAddress]
		push	eax
		call	[ebp + Print]
		pop		edi

		push	ecx
		mov		ecx, 1024 	;4096 bytes
		mov		esi, edi
		rep		movsd
		pop		ecx
		loop	.writetest1

		mov		eax,  0422h
		call	[ebp + SetCursor]
		lea 	eax, [ebp + Passed]
		push	eax
		call	[ebp + Print]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; writing test 2
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		mov		dword [ebp + NotCheckedBlocks], 0
		mov		ecx, [ebp + SystemRam]
		sub		ecx, 6 * 256
		mov		edx, ecx
		shl		edx, 12				;/4096
		sub		edx, 4096 		;start from 0 (so total mem -1 block)
		mov		edi, 6 * 100000h

.writetest:
		cmp		dword [ebp + myFlag], 1
		jne		.writetest22
		jmp 	.exit
.writetest22:


		mov		eax, edi				;address to check
		call	IsBlockWritable
		cmp		eax, 0
		je		.dowrite

		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		;push	edi
		;mov		eax,  0600h
		;call	[ebp + SetCursor]
		;push	dword [ebp + NotCheckedBlocks]
		;push	edi
		;lea 	eax, [ebp + ByPassingAddress]
		;push	eax
		;call	[ebp + Print]
		;pop		edi
		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

		add		edi, 4096
		jmp	 	.nextwrite

.dowrite:

		push	edi

		mov		eax,  0500h
		call	[ebp + SetCursor]
		push	edx
		push	edi
		lea 	eax, [ebp + VerifyingAddress]
		push	eax
		call	[ebp + Print]

		pop		edi

		push	ecx
		mov		ecx, 1024 	;4096 bytes
		mov		eax, 0FFFFFFFFh
		rep		stosd
		pop		ecx
.nextwrite:
		loop	.writetest

		mov		eax,  0522h
		call	[ebp + SetCursor]
		lea 	eax, [ebp + Passed]
		push	eax
		call	[ebp + Print]

		mov		eax,  0600h
		call	[ebp + SetCursor]
		lea 	eax, [ebp + Finished]
		push	eax
		call	[ebp + Print]

		call	ClearBar
		ret
		;jmp		.exit2

.exit:

		call 	ClearBar

		call	[ebp + GetCursor]
		mov		al,  22h
		call	[ebp + SetCursor]

		lea		eax, [ebp + Aborted]
		push	eax
		call	[ebp + Print]

		ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.exit2:
	mov		dword [ebp + myFlag], 0
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.loop:
	cmp		dword [ebp + myFlag], 1
	jne		.loop
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;reboot now
	ret
	mov	al, 0FEh
	out	64h, al			;this cause a soft reset (reboot)
	jmp $
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;call	[ebp + ClearScreen]

	;OldKeyboardCallback is in stack
	call	[ebp + SetKeyboardCallback]
	pop	ebp
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
align 4
ClearBar:
		lea		eax, [ebp + EscToAbort2]
		push	eax
		push	dword 1801h		;line 25 column 1
		call	[ebp + PrintXY]
		ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
align 4
IsBlockWritable:
		push	edi
		push	ebx
		push	ecx
		push	edx

		mov		edx, eax 			;address to check

		mov		edi, dword [ebp + MMT]
		mov		ebx, edi
		add		ebx, dword [ebp + MMTS]
		sub		ebx, 8

.loop1:
		cmp		dword [edi+4], 0
		je		.next

		mov		eax, dword [edi]			;address
		mov		ecx, dword [edi+4]		;size
		add		ecx, eax

		;;;;;;;;;;;;;;;
		;push	edi

		;push	eax
		;mov		eax,  0700h
		;call	[ebp + SetCursor]
		;pop		eax

		;push	ecx
		;push	eax
		;lea 	eax, [ebp + CheckingAddress]
		;push	eax
		;call	[ebp + Print]
		;pop		edi
		;;;;;;;;;;;;;;;

		cmp		edx, eax
		jl		.next
		add		edx, 4096			;block size
		cmp		edx, ecx
		jg		.next

		mov		eax, dword [ebp + NotCheckedBlocks]
		inc		eax
		mov		dword [ebp + NotCheckedBlocks], eax
		mov		eax, 1
		jmp		.exit

	.next:
		add		edi, 8
		cmp		edi, ebx
		jne		.loop1

		mov		eax, 0

.exit:
		pop		edx
		pop		ecx
		pop		ebx
		pop		edi

		ret

align 4
MyKeyboardCallback:
	push ebp

	push	eax
	call	FixAddress
	mov		ebp, eax
	pop		eax

	cmp		eax, 27
	jne		.not_now
	mov		dword [ebp + myFlag], 1
.not_now:

	;push	eax
	;lea		eax, [ebp + s1]
	;push	eax
	;call	[ebp + Print]
	;pop		eax

	pop		ebp
	ret

;Physical memory layout of the PC
;linear address range	real-mode address range	memory type	use
;0- 	3FF	 	0000:0000-0000:03FF 	RAM	real-mode interrupt vector table (IVT)
;400- 	4FF 		0040:0000-0040:00FF 	BIOS data area (BDA)
;500- 	9FBFF 		0050:0000-9000:FBFF 	free conventional memory (below 1 meg)
;9FC00- 	9FFFF 		9000:FC00-9000:FFFF 	extended BIOS data area (EBDA)
;A0000- 	BFFFF 		A000:0000-B000:FFFF 	video RAM 	VGA framebuffers
;C0000-	C7FFF 		C000:0000-C000:7FFF 	ROM 	video BIOS (32K is typical size)
;C8000-	EFFFF 		C800:0000-E000:FFFF 	NOTHING
;F0000-	FFFFF 		F000:0000-F000:FFFF 	ROM 	motherboard BIOS (64K is typical size)
;100000-	FEBFFFFF 	RAM 			free extended memory (1 meg and above)
;FEC00000-FFFFFFFF 	various 			motherboard BIOS, PnP NVRAM, ACPI, etc.
