;ATA_Identify_Device command = 0xec
;ATA_Identify_Packet_Device = 0xa1
; 0ECh command is for HD drives
; 0A1h command is for ATAPI CD/DVD drives
align 4
;primary controller
IRQ_IDE:
	pushad	
	mov	al, 20h
	out	20h, al
	out	0A0h, al	
	popad
	iretd

align 4
;secondary controller
IRQ_IDE2:
	pushad	
	mov	al, 20h
	out	20h, al
	out	0A0h, al	
	popad
	iretd

FindCDROM:
	push	dword 2Eh
	push	dword IRQ_IDE
	call	HookInterrupt
	call	Enable_IRQs		;enable now	
	
	push	dword 2Fh
	push	dword IRQ_IDE2
	call	HookInterrupt
	call	Enable_IRQs		;enable now
	
	
	
	
        mov	byte [command], 0A1h		; Put the hex number for IDENTIFY DRIVE in the var "command".

	mov	word [port], 1F0h			; Try port 1f0 .
        mov	byte [drive], 0			; Try master drive 0 (bit 5 should be 0).
        call	AtaPi_Id_Drive			; Call proc,if no error we have a ata/atapi address.        
        cmp	word [MyCDROMport], 0
        jne	.exit
        
        mov	word [port], 1F0h			; Try port 1f0 .
        mov	byte [drive], 10h			; Try slave drive 1 (bit 5 should be 1,so we put 0x10 bin 10000b) .
        call	AtaPi_Id_Drive			; Call proc,if no error we have a ata/atapi address.
        cmp	word [MyCDROMport], 0
        jne	.exit
        
        mov	word [port], 170h			; Try port 170 .
        mov	byte [drive], 0			; Try master drive 0 (bit 5 should be 0).
        call	AtaPi_Id_Drive			; Call proc,if no error we have a ata/atapi address.
        cmp	word [MyCDROMport], 0
        jne	.exit
        
       	mov	word [port], 170h			; Try port 170 .
       	mov	byte [drive], 10h			; Try slave drive 1 (bit 5 should be 1,so we put 0x10 bin 10000b) .
       	call	AtaPi_Id_Drive			; Call proc,if no error we have a ata/atapi address.       	
       	cmp	word [MyCDROMport], 0
        jne	.exit        
        jmp	.myret        
.exit:       	
       	call	ATA_ReadSector
       	
       	push	dword TempBuffer
       	push	dword 256
       	call	PrintHexView
.myret:
       	ret
       	
ReadATASector:
	mov	dx, word [MyCDROMport]
	add	dx, 1Bh
	mov	al,0
	out	dx, al
	
	mov	dx, word [MyCDROMport]
   	add     dx,6	        ;Drive and head port
   	mov     al, byte [MyCDROMdrive]  ;Drive ?, head 0
   	out     dx,al

	mov	dx, word [MyCDROMport]
   	add     dx,2            ;Sector count port
   	mov     al,1            ;Read one sector
   	out     dx,al

   	mov	dx, word [MyCDROMport]
   	add     dx,3            ;Sector number port
   	mov     al,1            ;Read sector one
   	out     dx,al

   	mov	dx, word [MyCDROMport]
   	add     dx,4            ;Cylinder low port
   	mov     al,0            ;Cylinder 0
   	out     dx,al

   	mov	dx, word [MyCDROMport]
   	add     dx,5            ;Cylinder high port
   	mov     al,0            ;The rest of the cylinder 0
   	out     dx,al

	mov	dx, word [MyCDROMport]
	add     dx,7	        ;Command port
   	mov     al,20h          ;Read with retry.
   	out     dx,al
still_going:
   	in      al,dx
   	test    al,8            ;This means the sector buffer requires servicing.
   	jz      still_going     ;Don't continue until the sector buffer is ready

   	mov     ecx,512/2        ;One sector /2
   	mov     edi, dword TempBuffer
   	mov	dx, word [MyCDROMport]
   	rep     insw
   	ret


AtaPi_Id_Drive:
	mov	edx, 7
	add	dx, word [port]
	mov	ecx, 0FFFFh

StatusReg1:          
	in	al, dx
	and	al, 80h
	jz	WriteCommand1         
	loop	StatusReg1
	jmp	DeviceBusy             
WriteCommand1:
	mov	edx, 6         
	add	dx, word [port]
	mov	al, byte [drive]
	or	al, 0EFh
	out	dx, al
	mov	ecx, 0FFFFh
	mov	edx, 7
	add	dx, word [port] 
        
StatusReg2:                                  
	in	al, dx
	test	al, 80h
	jz	Drdy_check
	loop	StatusReg2 
	jmp	DeviceBusy
Drdy_check:
	test	al, 40h
	jnz	WriteCommand2
	cmp	byte [command], 0A1h
	je	WriteCommand2
DeviceBusy:
	ret

WriteCommand2:
	mov	edx, 7           
	add	dx, word [port]
	mov	al, byte [command]      
	out	dx, al
	mov	ecx, 0FFFFh
	mov	edx, 7
	add	dx, word [port] 

StatusReg3: 
	in	al, dx
	test	al, 80h
	jnz	DrqErrorCheck1
	test	al, 1
	jnz	error
	test	al, 8 
	jnz	Read_data_reg_0
	ret

DrqErrorCheck1:
	push	ecx
	mov	ecx, 0FFFFh
busy_delay123:
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	loop  busy_delay123

	pop	ecx
	loop	StatusReg3
error:
	ret

Read_data_reg_0:                                                  
	mov	edx, 0
	add	dx, word [port]
	xor	ecx, ecx
	mov	ecx, 100h
	mov	edi, TempBuffer
                
Read_data_reg_1:
	in	ax, dx
	xchg	al, ah
	mov	word [edi], ax
	add	edi, 2
	loop	Read_data_reg_1             	
	
	;save port & drive ?
	mov	ax, word [port]
	mov	word [MyCDROMport], ax	
        mov	al, byte [drive]
        mov	byte [MyCDROMport], al
	
	ret

Small_Delay:
	push	ecx
	mov	ecx, 0FFFFh
BusyDelay3a:                                  
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	loop	BusyDelay3a
	pop	ecx
	ret

ATA_ReadSector:
	pushad
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
	
	mov	eax, 1
	mov	edi, TempBuffer

  ;test eax, 0xF0000000	; test for bits 28-31
  ;jnz short .return_error
  ;test dl, 0xFE		; test for invalid device ids
  ;jnz short .return_error
  	call 	ATA_WaitNotBusy
  	
  	mov 	edx, dword [MyCDROMport]
  	add	edx, 2		;sector count register
 	mov 	al, 1		;read one sector at any given time
  	out 	dx, al
  	
  	mov	ecx, 1		; LBA ***********************************************

  	inc 	edx		; sector number register
	mov 	al, cl		; al = lba bits 0-7 
  	out 	dx, al

  	inc 	edx		; cylinder low register
  	mov 	al, ch		; al = lba bits 8-15
  	out 	dx, al

  	inc 	edx		; cylinder high register
  	ror 	ecx, 16
  	mov 	al, cl		; set al = lba bits 16-23
  	out 	dx, al

  	mov	eax, dword [MyCDROMdrive]
  	inc 	edx		; device/head register
  	and 	ch, 0Fh		; set ch = lba bits 24-27
  	shl 	al, 4		; switch device id selection to bit 4
  	or 	al, 0E0h	; set bit 7 and 5 to 1, with lba = 1
  	or 	al, ch		; add in lba bits 24-27
  	out 	dx, al

  	call 	_wait_drdy	; wait for DRDY = 1 (Device ReaDY)
  	test 	al, 10h		; check DSC bit (Drive Seek Complete)
  	jz 	short .return_error

  	mov 	al, 20h		; set al = read sector(s) (with retries)
  	out 	dx, al		; command/status register

  	; TODO: ask for thread yield, giving time for hdd to read data
  	jmp 	short $+2
  	jmp 	short $+2

  	call 	ATA_WaitNotBusy.loop	; bypass the "mov edx, 0x1F7"
  	test 	al, 1     	; check for errors
  	jnz 	short .return_error

  	mov 	dl, 0F0h	; set dx = 0x1F0 (data register)
  	mov 	ecx, 256	; 256 words (512 bytes)
  	repz 	insw		; read the sector to memory
  	clc			; set completion flag to successful
  
  	popad
  	ret

.return_error:
	;mov dl, 0xF1		; error status register 0x1F1
  	;in al, dx		; read error code
  	popad
  	mov	eax, -1
  	ret



_wait_drdy:
; TODO: add check in case DRDY is 0 too long
	push	edx
	mov	edx, dword [MyCDROMport]
	add	edx, 7		;status register
.loop:
  	in 	al, dx			; read status
  	test 	al, 40h			; check DRDY bit state
  	jz 	.loop			; if DRDY = 0, wait
  	pop	edx
  	ret



ATA_WaitNotBusy:
; TODO: add error check if drive is busy too long
	push	edx
	mov	edx, dword [MyCDROMport]
	add	edx, 7
.loop:
  	in 	al, dx
  	test 	al, 80h
  	jnz 	.loop
  	pop	edx
  	ret

