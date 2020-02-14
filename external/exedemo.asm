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
			db	'Print', 0
Print:	dd	?
			db	0		;array terminates with null (byte)
ExportTable:
			db	0		;array terminates with null (byte)

;data

sDemo	db	'Demo executable', 13, 0


align 4
FixAddress:
	nop
	call	.local
.local:	pop	eax
	sub	eax, .local
	ret


;entry point here
ExecutableEIP:
	;push ebp
	call	FixAddress
	mov	ebp, eax

.loop1:
	lea	eax, [ebp + sDemo]
	push eax
	call	[ebp + Print]

	hlt
	jmp .loop1

	;pop	ebp
	;ret
