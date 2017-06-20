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
  	
  	;DriveLBA = (((M * 60) + S) * 75 + F) -150. Where M is minutes, S is seconds, and F is frames.
  	
  	mov	ecx, 16		; LBA ***********************************************

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

