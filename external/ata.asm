;example code for executables

%define DEBUG

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
			db	'PrintHexView', 0
PrintHexView:		dd	?
			db	'MemAlloc', 0
MemAlloc		dd	?
			db	'MemFree', 0
MemFree			dd	?
			db	0		;array terminates with null (byte)
ExportTable:
			db	0		;array terminates with null (byte)

;data

mySector dd ?
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

align 4
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
align 4
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

	mov		dword [ebp + mySector], 1
.read1:
	call	ReadATASector
	
	push	dword [ebp + ATA_Buffer]
  push	dword 256
  call	[ebp + PrintHexView]

	mov		eax, dword [ebp + mySector]  
	inc		eax
	mov		dword [ebp + mySector], eax
	;cmp		eax, 16
	;jne		.read1
	
	;jmp $
  
	popad
	ret
	
align 4
ReadATASector:
; parameters:
;------------
; eax = lba
; edi = location where to put the data (512 bytes)
; dl  = drive, 0 = master, 1 = slave

	;calculate LBA
	;LBA = ( ( CYL * HPC + HEAD ) * SPT ) + SECT - 1
	;LBA: linear base address of the block
	;CYL: value of the cylinder CHS coordinate
	;HPC: number of heads per cylinder for the disk
	;HEAD: value of the head CHS coordinate
	;SPT: number of sectors per track for the disk
	;SECT: value of the sector CHS coordinate
	
		;pushad
	
		mov		eax, dword [ebp + mySector]
		mov		edi, dword [ebp + ATA_Buffer]
		mov		dl, 1
	
		test 	eax, 0xF0000000	; test for bits 28-31
  	jnz	  short .return_error
  	test 	dl, 0xFE		; test for invalid device ids
  	jnz 	short .return_error
  
  	call 	ATA_WaitNotBusy
  	
  	mov 	edx, dword [ebp + port]
  	add		edx, 2		;sector count register
 		mov 	al, 1			;read one sector at any given time
  	out 	dx, al
  	
  	;DriveLBA = (((M * 60) + S) * 75 + F) -150. Where M is minutes, S is seconds, and F is frames.
  	
  	;mov		ecx, 16		; LBA ***********************************************
  	mov		ecx, dword [ebp + mySector]

  	inc 	edx				; sector number register
		mov 	al, cl		; al = lba bits 0-7 
  	out 	dx, al

  	inc 	edx				; cylinder low register
  	mov 	al, ch		; al = lba bits 8-15
  	out 	dx, al

  	inc 	edx				; cylinder high register
  	ror 	ecx, 16
  	mov 	al, cl		; set al = lba bits 16-23
  	out 	dx, al

  	mov		eax, dword [ebp + drive]
  	inc 	edx				; device/head register
  	and 	ch, 0Fh		; set ch = lba bits 24-27
  	shl 	al, 4			; switch device id selection to bit 4
  	or 		al, 0E0h	; set bit 7 and 5 to 1, with lba = 1
  	or 		al, ch		; add in lba bits 24-27
  	out 	dx, al

  	call 	_wait_drdy	; wait for DRDY = 1 (Device ReaDY)
  	test 	al, 10h		; check DSC bit (Drive Seek Complete)
  	jz 	short .return_error

  	mov 	al, 20h		; set al = read sector(s) (with retries)
  	out 	dx, al		; command/status register

  	; TODO: ask for thread yield, giving time for hdd to read data
  	jmp 	short $+2
  	jmp 	short $+2

  	call 	ATA_WaitNotBusy.loop			; bypass the "mov edx, 0x1F7"
  	test 	al, 1     	; check for errors
  	jnz 	short .return_error

  	mov 	dl, 0F0h	; set dx = 0x1F0 (data register)
  	mov 	ecx, 256	; 256 words (512 bytes)
  	repz 	insw		; read the sector to memory
  	clc			; set completion flag to successful
  
  	;popad
  	ret

.return_error:
		mov dl, 0xF1		; error status register 0x1F1
  	in al, dx		; read error code
  	;popad
  	mov	eax, -1
  	ret
  	
_wait_drdy:
; TODO: add check in case DRDY is 0 too long
		;push	edx
		mov		edx, dword [ebp + port]
		add		edx, 7		;status register
.loop:
  	in 	al, dx			; read status
  	test 	al, 40h		; check DRDY bit state
  	jz 	.loop				; if DRDY = 0, wait
  	
  	;pop	edx
  	ret

ATA_WaitNotBusy:
; TODO: add error check if drive is busy too long
		;push	edx
		mov	edx, dword [ebp + port]
		add	edx, 7
.loop:
  	in 		al, dx
  	test 	al, 80h
  	jnz 	.loop
  	
  	;pop		edx
  	ret
	
align 4
ATA_ID_Drive:
	%ifdef DEBUG
	movzx	eax, byte [ebp + drive]
	push	eax
	movzx	eax, word [ebp + port]
	push	eax	
	movzx	eax, byte [ebp + command]
	push	eax
	lea	eax, [ebp + CheckingATA]
	push	eax
	call	[ebp + Print]
	%endif
	
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
  ;mov	byte [ebp + command], 0A1h		; Put the hex number for ATAPI IDENTIFY DRIVE in the var "command".
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


