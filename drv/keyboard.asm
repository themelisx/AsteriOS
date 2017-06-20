;keyboard driver

[BITS 32]

org 0

?			EQU	0

Driver_Start:

;executable header 38 bytes
Signature		db	'AsteriOS'
HeaderVersion		db	00010001b		;v.1.0 (4 hi-bits major version, 4 lo-bits minor version)
ExecutableCRC		dd	?			;including rest of header
ExecutableFlags		db	00011110b		;check below (execute init & stop, contains import & export)
ImportTableOffset	dd	ImportTable - Driver_Start
ExportTableOffset	dd	ExportTable - Driver_Start
RelocationTableOffset	dd	0
InitFunctionOffset	dd	InitKeyboard - Driver_Start
StopFunctionOffset	dd	StopKeyboard - Driver_Start
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
			db	'HookInterrupt', 0
HookInterrupt:		dd	?
			db	'GetInterruptAddress', 0
GetInterruptAddress:	dd	?
			db	'Print', 0
Print:			dd	?
			db	'PrintCRLF', 0
PrintCRLF:		dd	?
			db	'PrintHex', 0
PrintHex:		dd	?
			db	'MemAlloc', 0
MemAlloc:		dd	?
			db	'MemFree', 0
MemFree:		dd	?
			db	'MemCpy', 0
MemCpy:			dd	?
			db	'GetSystemLoaded', 0
GetSystemLoaded:	dd	?
			db	'RegisterDevice', 0
RegisterDevice:		dd	?
			db	0		;array terminates with null (byte)
			
ExportTable:
			db	'GetKeyboardQueue', 0
			dd	GetKeyboardQueue - Driver_Start
			db 'CheckKeyboardQueue', 0
			dd	CheckKeyboardQueue - Driver_Start
			db	'GetKey', 0
			db	GetKey - Driver_Start
			db	0		;array terminates with null (byte)

;export table struct
;Function name (null terminated)
;dword size (in bytes) from the start of executable to the start of the function
;array terminates with null (byte)
;export table

;data
KEYBOARD_QUEUE_SIZE	EQU	0FFh

OldInt21		dd	?

KeyboardQueueCount	db	0
KeyboardQueue		dd	?

KeyLedStatus		dd	0
KeyFlag_e0		dd	0
KeyFlag_e1		dd	0
KeyFlag_f0		dd	0
KeyFlag_ShiftLeft	dd	0
KeyFlag_ShiftRight	dd	0
KeyFlag_AltLeft		dd	0
KeyFlag_AltRight	dd	0
KeyFlag_CtrlLeft	dd	0
KeyFlag_CtrlRight	dd	0

sKeyboard		db	'Keyboard', 0
Debug_InitKeyboard	db	'[Init] Keyboard driver', 13, 0
Debug_StopKeyboard	db	'[Stop] Keyboard driver', 13, 0
;Debug_Keyboard_IRQ	db	'[IRQ 21] Key press: 0x%x', 13, 0

align 4
FixAddress:
	nop
	call	.local
.local:	pop	eax
	sub	eax, .local
	ret
	
align 4
GetKey:
.loop:
	;call	Delay32
	hlt	
	cmp		byte [ebp + KeyboardQueueCount], 0
	je		.loop

	mov		eax, dword [ebp + KeyboardQueue]
	movzx	eax, byte [eax]
	ret

align 4
InitKeyboard:
	push	ebp
	call	FixAddress
	mov	ebp, eax
	
	%ifdef DEBUG
	lea 	eax, [ebp + Debug_InitKeyboard]
	push	eax
	call	[ebp + Print]
	%endif
	
	push	dword KEYBOARD_QUEUE_SIZE
	call	[ebp + MemAlloc]
	mov	dword [ebp + KeyboardQueue], eax
	mov	byte [ebp + KeyboardQueueCount], 0
	
	;get old interrupt address
	push	dword 21h
	call	[ebp + GetInterruptAddress]
	mov	dword [ebp + OldInt21], eax
	
	;enable keyboard IRQ
	push	dword 21h
	lea	eax, [ebp + IRQ_Keyboard]
	push	eax
	call	[ebp + HookInterrupt]
	
	;name
	;Driver address
	;DMA
	;Channel
	;IRQ
	;Type
	;Flags
	
	lea	eax, [ebp + sKeyboard]
	push	eax
	lea	eax, [ebp + IRQ_Keyboard]
	push	eax
	push	dword 60h	;port
	push	dword 0		;channel unused
	push	dword 1		;irq 1
	push	dword 4		;DEVICE_KEYBOARD
	push	dword 1		;bit 0 = enable
	call	[ebp + RegisterDevice]
	
	pop	ebp
	ret

align 4
;Clear everything to unload driver	
StopKeyboard:
	push	ebp	
	call	FixAddress
	mov	ebp, eax
	
	%ifdef DEBUG
	lea 	eax, [ebp + Debug_StopKeyboard]
	push	eax
	call	[ebp + PrintDebug]
	%endif

	;set back old address
	push	dword 21h
	push	dword [ebp + OldInt21]
	call	[ebp + HookInterrupt]
	
	;free buffer
	push	dword [ebp + KeyboardQueue]
	call	[ebp + MemFree]
	
	pop	ebp
	ret

align 4
;no input
;returns AL=key
GetKeyboardQueue:
	push	ebp	
	call	FixAddress
	mov	ebp, eax
	
	cmp	byte [ebp + KeyboardQueueCount], 0
	jne	.HasKey
	xor	eax, eax
	jmp	.exit
.HasKey:
	;cli
	mov		eax, dword [ebp + KeyboardQueue]
	movzx	eax, byte [eax]
	push	eax				;save ret value
	push	ecx
	movzx	ecx, byte [ebp + KeyboardQueueCount]
	dec	ecx
	push	dword [ebp + KeyboardQueue+1]
	push	dword [ebp + KeyboardQueue]
	push	ecx
	call	[ebp + MemCpy]				;move queue -1 byte
	dec	byte [ebp + KeyboardQueueCount]
	pop	ecx
	pop	eax
	;sti
.exit:
	pop	ebp
	ret
	
align 4
;no input
;returns AL=key
CheckKeyboardQueue:
	push	ebp	
	call	FixAddress
	mov		ebp, eax
	
	cmp		byte [ebp + KeyboardQueueCount], 0
	jne		.HasKey
	xor		eax, eax
	jmp		.exit
.HasKey:
	mov		eax, dword [ebp + KeyboardQueue]
	movzx	eax, byte [eax]
.exit:
	pop	ebp
	ret
	
align 4
IRQ_Keyboard:
	push	ebp	
	call	FixAddress
	mov	ebp, eax
	
	pushad
	pushfd
	
	call	[ebp + GetSystemLoaded]
	cmp	eax, 1
	je	.go
	jmp	.exit
.go:

	call	Delay32
	in 	al, 60h
			
	cmp	al, 0FAh
	jne	.k0
	jmp	.exit 		;ignore 0FAh=ACK codes
.k0:	
	; Up key = 0F0h in scanmode2
	cmp	eax, 0F0h
	jne	.k1
	mov	dword [ebp + KeyFlag_f0], 1
	jmp	.exit	
.k1:
	; Extended E0h scancode
	cmp	eax, 0E0h
	jne	.k2
	mov	dword [ebp + KeyFlag_e0], 1
	jmp	.exit
.k2:
	; Extended E1h scancode
	cmp	eax, 0E1h
	jne	.k3
	mov	dword [ebp + KeyFlag_e1], 1
	jmp	.exit
.k3:
	; Left SHIFT status
	cmp	eax, 2Ah
	jne	.k4
	mov	dword [ebp + KeyFlag_ShiftLeft], 1
	jmp	.exit
.k4:
	cmp	eax, 0AAh
	jne	.k5
	mov	dword [ebp + KeyFlag_ShiftLeft], 0
	mov	dword [ebp + KeyFlag_e0], 0
	mov	dword [ebp + KeyFlag_e1], 0
	mov	dword [ebp + KeyFlag_f0], 0
	jmp	.exit
.k5:
	; Right SHIFT status
	cmp	eax, 36h
	jne	.k6
	mov	dword [ebp + KeyFlag_ShiftRight], 1
	jmp	.exit
.k6:
	cmp	eax, 0B6h
	jne	.k7
	mov	dword [ebp + KeyFlag_ShiftRight], 0
	mov	dword [ebp + KeyFlag_e0], 0
	mov	dword [ebp + KeyFlag_e1], 0
	mov	dword [ebp + KeyFlag_f0], 0
	jmp	.exit
.k7:
	; Left CONTROL status
	cmp	eax, 01Dh
	jne	.k8
	mov	dword [ebp + KeyFlag_CtrlLeft], 1
	jmp	.exit
.k8:
	cmp	eax, 09Dh
	jne	.k9
	mov	dword [ebp + KeyFlag_CtrlLeft], 0
	mov	dword [ebp + KeyFlag_e0], 0
	mov	dword [ebp + KeyFlag_e1], 0
	mov	dword [ebp + KeyFlag_f0], 0
	jmp	.exit
.k9:
	; Left ALT status
	cmp	eax, 038h
	jne	.k10
	mov	dword [ebp + KeyFlag_AltLeft], 1
	jmp	.exit
.k10:
	cmp	eax, 0B8h
	jne	.k11
	mov	dword [ebp + KeyFlag_AltLeft], 0
	mov	dword [ebp + KeyFlag_e0], 0
	mov	dword [ebp + KeyFlag_e1], 0
	mov	dword [ebp + KeyFlag_f0], 0
	jmp	.exit
.k11:
		
	test	eax, 80h			; Key DOWN only?
	jz	.k12
	mov	dword [ebp + KeyFlag_e0], 0
	mov	dword [ebp + KeyFlag_e1], 0
	mov	dword [ebp + KeyFlag_f0], 0
	jmp	.exit
.k12:
	
	;push	eax
	;push	eax
	;push	dword 1847h		;line 25 column 71
	;call	[ebp + PrintHexXY]
	;pop	eax

	cmp	eax, 45h		;num lock
	jne	.k13
	mov	eax, dword [ebp + KeyLedStatus]
	xor	eax, 10b
	mov	dword [ebp + KeyLedStatus], eax
	call	SetKeyboardLeds
	jmp	.exit
.k13:
	cmp	eax, 3Ah		;caps lock
	jne	.k14
	mov	eax, dword [ebp + KeyLedStatus]
	xor	eax, 100b
	mov	dword [ebp + KeyLedStatus], eax
	call	SetKeyboardLeds
	jmp	.exit
.k14:
	cmp	eax, 46h		;num lock
	jne	.k15
	mov	eax, dword [ebp + KeyLedStatus]
	xor	eax, 1b
	mov	dword [ebp + KeyLedStatus], eax
	call	SetKeyboardLeds
	jmp	.exit
.k15:
	;check extended keys
	;num pad keys

	;siple key
	mov	ebx, dword [ebp + KeyLedStatus]
	and	ebx, 100b
	jz	.s1
	; caps status
	mov	ebx, dword [ebp + KeyFlag_ShiftLeft]
	or	ebx, dword [ebp + KeyFlag_ShiftRight]
	jz	.s1a
	lea	edi, [ebp + kb_caps_Shift_table]
	jmp	.s2
.s1a:
	lea	edi, [ebp + kb_capslock_table]
	jmp	.s2
.s1:
	; shift status
	mov	ebx, dword [ebp + KeyFlag_ShiftLeft]
	or	ebx, dword [ebp + KeyFlag_ShiftRight]
	jz	.s2a
	lea	edi, [ebp + kb_Shift_table]
	jmp	.s2
.s2a:	
	lea	edi, [ebp + kb_ascii_table]
.s2:
	;find keypress from the scancode table
	shl	eax, 2		;*4 as each table is made of dwords
	add	edi, eax
	mov	eax, [edi]
	
	push	eax
	mov	esi, dword [ebp + KeyboardQueue]
	movzx	eax, byte [ebp + KeyboardQueueCount]
	add	esi, eax
	pop	eax
	mov	byte [esi], al
	inc	byte [ebp + KeyboardQueueCount]
	
	;and	eax, 0FFh	
	;push	eax
	;lea	eax, [ebp + Debug_Keyboard_IRQ]
	;push	eax
	;call	[ebp + PrintDebug]

	;HandleKeyboardMessages (kernel) will do the rest
.exit:	
	popfd
	popad
	
	pop	ebp
	
	mov	al,20h
	out	20h,al
	iretd

align 4
SetKeyboardLeds:
	push	ebp	
	call	FixAddress
	mov	ebp, eax
.loop:
	in	al, 64h
	and	al, 2h
	jnz	.loop
	;write LED command
	mov	al, 0EDh	
	out	60h, al
.loop2:
	in	al, 64h
	and	al, 2
	jnz	.loop2		
	mov	eax, dword [ebp + KeyLedStatus]
	out	60h, al
	
	pop	ebp
	ret

align 4
Delay32:
	nop
	db	0E9h, 0, 0, 0, 0		;jmp to next command
	db	0E9h, 0, 0, 0, 0
	ret
	
align 4
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	

kb_control_table	dd	0,   0,   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,   0,   0,   127, 127
			dd	17,  23,  5,   18,  20,  25,  21,  9,   15,  16,  2,   2,   10,  0,   1,   19
			dd	4,   6,   7,   8,   10,  11,  12,  0,   0,   0,   0,   0,   26,  24,  3,   22
			dd	2,   14,  13,  0,   0,   0,   0,   0,   0,   0,   0,   2,   2,   2,   2,   2
			dd	2,   2,   2,   2,   2,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0
			dd	0,   0,   2,   0,   0,   0,   0,   2,   2,   0,   0,   0,   0,   0,   0,   0
			dd	0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0
			dd	0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0

kb_Shift_table		dd	0,   27,  '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '_', '+', 126, 126
			dd	'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '{', '}', 126, 0,   'A', 'S'
			dd	'D', 'F', 'G', 'H', 'J', 'K', 'L', ':', 34,  '~', 0,   '|', 'Z', 'X', 'C', 'V'
			dd	'B', 'N', 'M', '<', '>', '?', 0,   '*', 0,   1,   0,   1,   1,   1,   1,   1
			dd	1,   1,   1,   1,   1,   0,   0,   0,   0,   0,   '-', 0,   0,   0,   '+', 0
			dd	0,   0,   1,   127, 0,   0,   0,   1,   1,   0,   0,   0,   0,   0,   0,   0
			dd	13,  0,   '/', 0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   127
			dd	0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   '/', 0,   0,   0,   0,   0

kb_caps_Shift_table	dd	0,   27,  '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '_', '+', 126, 126
			dd	'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '{', '}', 126, 0,   'a', 's'
			dd	'd', 'f', 'g', 'h', 'i', 'k', 'l', ':', 34,  '~', 0,   '|', 'z', 'x', 'c', 'v'
			dd	'b', 'n', 'm', '<', '>', '?', 0,   '*', 0,   1,   0,   1,   1,   1,   1,   1
			dd	1,   1,   1,   1,   1,   0,   0,   0,   0,   0,   '-', 0,   0,   0,   '+', 0
			dd	0,   0,   1,   127, 0,   0,   0,   1,   1,   0,   0,   0,   0,   0,   0,   0
			dd	13,  0,   '/', 0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   127
			dd	0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   '/', 0,   0,   0,   0,   0

kb_ascii_table:		dd	0,   27,  '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', 8,   9
			dd	'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', 13,  0,   'a', 's'
			dd	'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', 39,  '`', 0,   92,  'z', 'x', 'c', 'v'
			dd	'b', 'n', 'm', ',', '.', '/', 0,   '*', 0,   ' ', 0,   3,   3,   3,   3,   8
			dd	3,   3,   3,   3,   3,   0,   0,   0,   0,   0,   '-', 0,   0,   0,   '+', 0
			dd	0,   0,   0,   127, 0,   0,   92,  3,   3,   0,   0,   0,   0,   0,   0,   0
			dd	13,  0,   '/', 0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   127
			dd	0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   '/', 0,   0,   0,   0,   0

kb_capslock_table	dd	0,   27,  '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', 8,   9
			dd	'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', '[', ']', 13,  0,   'A', 'S'
			dd	'D', 'F', 'G', 'H', 'J', 'K', 'L', ';', 39,  '`', 0,   92,  'Z', 'X', 'C', 'V'
			dd	'B', 'N', 'M', ',', '.', '/', 0,   '*', 0,   ' ', 0,   3,   3,   3,   3,   8
			dd	3,   3,   3,   3,   3,   0,   0,   0,   0,   0,   '-', 0,   0,   0,   '+', 0
			dd	0,   0,   0,   127, 0,   0,   92,  3,   3,   0,   0,   0,   0,   0,   0,   0
			dd	13,  0,   '/', 0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   127
			dd	0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   '/', 0,   0,   0,   0,   0

			