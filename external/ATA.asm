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
Print:			dd	?
			db	'PrintC', 0
PrintC:			dd	?
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
			db	0		;array terminates with null (byte)

;data

command			db	0
drive			db	0
port			dw	0
ATA_Buffer		dd	?

CheckingATA		db	'Checking ATA, cmd:0x%x, port:0x%x, drive:0x%x', 13, 0
ScaningHD		db	'Scaning HD drives...', 13, 0
ScaningCD		db	'Scaning CD/DVD drives...', 13, 0
ATAPMaster		db	'Primary Master: %s', 13, 0
ATAPSlave		db	'Primary Slave: %s', 13, 0
ATASMaster		db	'Secondary Master: %s', 13, 0
ATASSlave		db	'Secondary Slave: %s', 13, 0

Debug_ExecutableInit	db	'[Init] Test Executable', 13, 0
Debug_ExecutableEIP	db	'Testing Executable EIP function', 13, 0


align 4
FixAddress:
	nop
	call	.local
.local:	pop	eax
	sub	eax, .local
	ret


;entry point here
ExecutableEIP:
	push	ebp
	call	FixAddress
	mov	ebp, eax
	
	call	GetATAInfo
	
	pop	ebp
	ret
  	
;Gets the Ata/Atapi drive info 

;ATA_Identify_Device command = 0xec
;ATA_Identify_Packet_Device = 0xa1

ATA_ShowInfo:	
	pushad

	movzx	eax, word [ebp + port]
	push	eax
	call	[ebp + PrintHex]
	
        movzx	eax, byte [ebp + drive]
	push	eax
	call	[ebp + PrintHex]
	
	mov	esi, [ebp + ATA_Buffer]
	add	esi, 36h				;Model
	push	esi
	push	dword 28h
	call	[ebp + PrintC]
	call	[ebp + PrintCRLF]
	
	popad
	ret

ATA_ID_Drive:
	;%ifdef DEBUG
	movzx	eax, byte [ebp + drive]
	push	eax
	movzx	eax, word [ebp + port]
	push	eax	
	movzx	eax, byte [ebp + command]
	push	eax
	lea	eax, [ebp + CheckingATA]
	push	eax
	call	[ebp + Print]
	;%endif
	
	mov	edx, 7
	add	dx, word [ebp + port]
	mov	ecx, 0FFFFh

ATA_StatusReg1:          
	in	al, dx
	and	al, 80h
	jz	ATA_WriteCommand1         
	loop	ATA_StatusReg1
	ret			;DeviceBusy
ATA_WriteCommand1:
	mov	edx, 6         
	add	dx, word [ebp + port]
	mov	al, byte [ebp + drive]
	or	al, 0EFh
	out	dx, al
	mov	ecx, 0FFFFh
	mov	edx, 7
	add	dx, word [ebp + port] 
        
ATA_StatusReg2:                                  
	in	al, dx
	test	al, 80h
	jz	ATA_ReadyCheck
	loop	ATA_StatusReg2
	ret			;DeviceBusy
ATA_ReadyCheck:
	test	al, 40h
	jnz	ATA_WriteCommand2
	cmp	byte [ebp + command], 0A1h
	je	ATA_WriteCommand2
	;DeviceBusy:
	ret

ATA_WriteCommand2:
	mov	edx, 7           
	add	dx, word [ebp + port]
	mov	al, byte [ebp + command]      
	out	dx, al
	mov	ecx, 0FFFFh
	mov	edx, 7
	add	dx, word [ebp + port] 

ATA_StatusReg3: 
	in	al, dx
	test	al, 80h
	jnz	ATA_ErrorCheck
	test	al, 1
	jnz	ATA_Error
	test	al, 8 
	jnz	ATA_ReadData
	ret

ATA_ErrorCheck:
	push	ecx
	mov	ecx, 0FFFFh
ATA_BusyDelay:
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	loop  ATA_BusyDelay

	pop	ecx
	loop	ATA_StatusReg3
ATA_Error:
	ret

ATA_ReadData:                                                  
	mov	edx, 0
	add	dx, word [ebp + port]
	;xor	ecx, ecx
	mov	ecx, 100h
	mov	edi, [ebp + ATA_Buffer]
                
ATA_ReadData1:
	in	ax, dx
	xchg	al, ah
	;stosw
	mov	word [edi], ax
	add	edi, 2
	loop	ATA_ReadData1             

	;save port & drive ?        
	;mov	dx,word [port]
        	;mov	al,byte [drive]
	clc
	call	ATA_ShowInfo
	ret
	
; 0ECh command is for HD drives
; 0A1h command is for ATAPI CD/DVD drives
GetATAInfo:
	pushad
	pushfd
	push	dword 1024
	call	[ebp + MemAlloc]
	mov	dword [ebp + ATA_Buffer], eax
	
        mov	byte [ebp + command], 0ECh		; Put the hex number for IDENTIFY DRIVE in the var "command".
drive_id:        
	mov	word [ebp + port], 1F0h			; Try port 1f0 .
	mov	byte [ebp + drive], 0			; Try master drive 0 (bit 5 should be 0).
	call	ATA_ID_Drive			; Call proc,if no error we have a ata/atapi address.
	
	mov	word [ebp + port], 1F0h			; Try port 1f0 .
	mov	byte [ebp + drive], 10h			; Try slave drive 1 (bit 5 should be 1,so we put 0x10 bin 10000b) .
	call	ATA_ID_Drive			; Call proc,if no error we have a ata/atapi address.
	
	mov	word [ebp + port], 170h			; Try port 170 .
	mov	byte [ebp + drive], 0			; Try master drive 0 (bit 5 should be 0).
	call	ATA_ID_Drive			; Call proc,if no error we have a ata/atapi address.
	
	mov	word [ebp + port], 170h			; Try port 170 .
	mov	byte [ebp + drive], 10h			; Try slave drive 1 (bit 5 should be 1,so we put 0x10 bin 10000b) .
	call	ATA_ID_Drive			; Call proc,if no error we have a ata/atapi address.
	
	cmp	byte [ebp + command], 0A1h		; Have we been here before, yes then lets go!
	je	Lets_go                       
	
	mov	byte [ebp + command], 0A1h		; Put the hex number for ATAPI IDENTIFY DRIVE in the var "command".
	jmp	drive_id             
Lets_go:
	push	dword [ebp + ATA_Buffer]
	call	[ebp + MemFree]
	popfd
	popad
	ret
