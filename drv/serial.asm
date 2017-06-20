;example code for executables and drivers
[bits 32]

org 0

?			equ	0

Driver_Start:

;executable header 34 bytes
Signature		db	'AsteriOS'
HeaderVersion		db	00010000b		;v.1.0 (4 hi-bits major version, 4 lo-bits minor version)
ExecutableCRC		dd	?			;including rest of header
ExecutableFlags		db	00011110b		;check below (execute init & stop, contains import & export)
ImportTableOffset	dd	ImportTable - Driver_Start
ExportTableOffset	dd	ExportTable - Driver_Start
InitFunctionOffset	dd	SerialPortInit - Driver_Start
StopFunctionOffset	dd	SerialPortStop - Driver_Start
EntryPoint		dd	?

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
			db	'GetDebugMode', 0
GetDebugMode:		dd	?
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
MemAlloc		dd	?
			db	'MemFree', 0
MemFree			dd	?
			db	0		;array terminates with null (byte)
ExportTable:
			db	'SerialPortSendChar', 0
			dd	SerialPortSendChar - Driver_Start
			db	'SerialPortSendString', 0
			dd	SerialPortSendString - Driver_Start
			db	'ReadSerialPortData', 0
			dd	ReadSerialPortData - Driver_Start
			db	0		;array terminates with null (byte)

;data
INTNUM      equ 0Ch          ; COM1; COM2: 0Bh
OFFMASK     equ 00010000b    ; COM1; COM2: 00001000b
;ONMASK      equ not OFFMASK
UART_BASE   equ 3F8h         ; COM1; COM2: 2F8h
UART_RATE   equ 12           ; 9600 bps, see table in this file
UART_PARAMS equ 00000011b    ; 8n1, see tables
RXFIFOSIZE  equ 8096         ; set this to your needs
TXFIFOSIZE  equ 8096         ; dito.
                             ; the fifos must be large on slow computers
                             ; and can be small on fast ones
                             ; These have nothing to do with the 16550A's
                             ; built-in FIFOs!
; UART_BASEADDR   the base address of the UART
; UART_BAUDRATE   the divisor value (eg. 12 for 9600 bps)
; UART_LCRVAL     the value to be written to the LCR (eg. 0x1b for 8e1)
; UART_FCRVAL     the value to be written to the FCR. Bit 0, 1 and 2 set,
;                  bits 6 & 7 according to trigger level wished (see above).
;                  0x87 is a good value, 0x7 establishes compatibility
;                  (except that there are some bits to be masked in the IIR).

;OldIntx?		dd	?
DebugMode		db	0
Debug_SerialPortInit	db	'[Init] Serial port driver', 13, 0
Debug_SerialPortStop	db	'[Stop] Serial port driver', 13, 0

SerialPortInit:
	;this needs to make the code running from any place
	push	ebp	
	call	.local
.local:	pop	ebp
	sub	ebp, .local
	;until here
	
	call	[ebp + GetDebugMode]
	mov	byte [ebp + DebugMode], al
	
	cmp	byte [ebp + DebugMode], 1		;debug mode enabled ?
	jne	SerialPortInit_NoDebug
	lea	eax, [ebp + Debug_SerialPortInit]
	push	eax
	call	[ebp + Print]
SerialPortInit_NoDebug:
	;Init code here 	

	;TODO: 
	;hook serial port IRQ
	;allocate memory for incoming data buffer

	push 	ax
  	push 	dx
  	mov  	dx, UART_BASE + 3  ; LCR
  	mov  	al, 80h  ; set DLAB
  	out  	dx, al
  	mov  	dx, UART_BASE    ; divisor
  	mov  	ax, UART_RATE
  	out  	dx, ax
  	mov  	dx, UART_BASE + 3  ; LCR
  	mov  	al, UART_PARAMS	;UART_LCRVAL  ; params
  	out  	dx, al
  	mov  	dx, UART_BASE+4  ; MCR
  	xor  	ax, ax  ; clear loopback
  	out  	dx, al
  	;***
  	pop  	dx
  	pop  	ax
  	
  	pop	ebp
  	ret
  	
SerialPortStop:
	;this needs to make the code running from any place
	push	ebp	
	call	.local
.local:	pop	ebp
	sub	ebp, .local
	;until here
	
	cmp	byte [ebp + DebugMode], 1		;debug mode enabled ?
	jne	SerialPortStop_NoDebug
	lea	eax, [ebp + Debug_SerialPortStop]
	push	eax
	call	[ebp + Print]
SerialPortStop_NoDebug:

	;TODO:
	;set back old interrupt address
	;free up buffer
	
	pop	ebp
	ret
  	
SerialPortSendChar:
	; character to be sent in AL
  	push 	dx
  	push 	ax
  	mov  	dx, UART_BASE+5
SerialPortSendChar_wait:
  	in  	al, dx  ; wait until we are allowed to write a byte to the THR
  	test 	al, 20h
  	jz   	SerialPortSendChar_wait
  	pop  	ax
  	mov  	dx, UART_BASE
  	out  	dx, al  ; then write the byte
  	pop  	dx
  	ret
  	
SerialPortSendString:
  	; DS:SI contains a pointer to the string to be sent.
  	push	 si
  	push 	ax
  	push 	dx
  	cld 
SerialPortSendString_loop:
  	lodsb
  	or   	al,al  ; last character sent?
  	jz   	SerialPortSendString_end
  	;*1*
  	mov  	dx, UART_BASE+5
  	push 	ax
SerialPortSendString_wait:
  	in   	al, dx
  	test 	al, 20h
  	jz   	SerialPortSendString_wait
  	
  	mov  	dx, UART_BASE
  	pop  	ax
  	out  	dx, al
  	;*2*
  	jmp  	SerialPortSendString_loop
SerialPortSendString_end:
  	pop  	dx
  	pop  	ax
  	pop  	si
  	ret

;This function listen to IRQ
;and fills input buffer
SerialPortGetData:
	;TODO: 
	ret

;exported
ReadSerialPortData:
	;TODO:
	ret