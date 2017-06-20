[BITS 32]

;org 0F0000000h
org 0

?			equ	0

Driver_Start:

;executable header 38 bytes
Signature		db	'AsteriOS'
HeaderVersion		db	00010001b		;v.1.0 (4 hi-bits major version, 4 lo-bits minor version)
ExecutableCRC		dd	?			;including rest of header
ExecutableFlags		db	00111010b		;check below (execute init & stop, contains import & export)
ImportTableOffset	dd	ImportTable - Driver_Start
ExportTableOffset	dd	ExportTable - Driver_Start
RelocationTableOffset	dd	RelocationTable - Driver_Start
InitFunctionOffset	dd	DriverInit - Driver_Start
StopFunctionOffset	dd	DriverStop - Driver_Start
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
;			db	'GetDebugMode', 0
;GetDebugMode:		dd	?
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
			db	0		;array terminates with null (byte)
ExportTable:
			db	'DriverTest', 0
			dd	DriverTest - Driver_Start
			db	0		;array terminates with null (byte)
			
RelocationTable:
			;include .reloc file
			dd	0		;array terminates with null (byte)

;data

DebugMode		db	0
Debug_DriverInit	db	'[Init] x driver', 13, 0
Debug_DriverStop	db	'[Stop] x driver', 13, 0
Debug_DriverTest	db	'Testing driver export function', 13, 0

DriverInit:
	;call	[GetDebugMode]
	mov	byte [DebugMode], 0		;al
	
	cmp	byte [DebugMode], 1		;debug mode enabled ?
	jne	.NoDebug
	lea	eax, [Debug_DriverInit]
	push	eax
	call	[Print]
.NoDebug:
	;Init code here 

  	ret
  	
DriverStop:
	cmp	byte [DebugMode], 1		;debug mode enabled ?
	jne	.NoDebug
	lea	eax, [Debug_DriverStop]
	push	eax
	call	[Print]
.NoDebug:
	;stop code here
	

	ret
	
;exported function
DriverTest:
	lea	eax, [Debug_DriverTest]
	push	eax
	call	[Print]


	ret
  	
