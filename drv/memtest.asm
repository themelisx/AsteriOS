;example code for executables

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
			db	'GetKeyboardCallback', 0
GetKeyboardCallback:	dd	?
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
			db	'ClearScreen', 0
ClearScreen:	dd	?			
			db	0		;array terminates with null (byte)
ExportTable:
			db	0		;array terminates with null (byte)

;data

sVersion	db	'Memory Tester v.0.1.1', 13, 0
s1			db  'key press', 13, 0
myFlag		dd	?


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
	
		
	;call	[ebp + ClearScreen]
	
	lea		eax, [ebp + sVersion]
	push	eax
	push	dword 0100h		;line 1 column 0
	call	[ebp + PrintXY]
	
	push	dword 0200h		;line 2, col 0
	call	[ebp + PrintLine]
	
	mov		dword [ebp + myFlag], 0
.loop:	
	cmp		dword [ebp + myFlag], 1
	jne		.loop
	
	call	[ebp + ClearScreen]
	
	;OldKeyboardCallback is in stack
	call	[ebp + SetKeyboardCallback]	
	pop	ebp
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
	
	push	eax
	lea		eax, [ebp + s1]
	push	eax
	call	[ebp + Print]	
	pop		eax
	
	pop		ebp
	ret

