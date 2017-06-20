;memory and bios informations

GetMemInfo:
	pushad
	pushfd
	
	;get memory info
	xor	eax, eax
	xor	ebx, ebx
	xor	ecx, ecx
	xor	edx, edx
	
	mov	eax, 0E801h
	int	15h
	;returns:
	;AX = extended memory between 1M and 16M, in K (max 3C00h = 15MB)
	;BX = extended memory above 16M, in 64K blocks
	;CX = configured memory 1M to 16M, in K
	;DX = configured memory above 16M, in 64K blocks
	cmp	eax, 0
	jne	AxIsOk
	mov	eax, ecx
AxIsOk:
	cmp	ebx, 0
	jne	BxIsOk
	mov	ebx, edx
BxIsOk:
	inc	eax			;add mem below 1MB
	shl	eax, 10
	shl	ebx, 6
	shl	ebx, 10
	add	eax, ebx
	mov	dword [FreeMem], eax
	
	shr	eax, 10
	shr	eax, 10
	mov	dword [TotalMem], eax		;in MBytes
	
	popfd
	popad
	
	ret
	
;Moves a null terminated string to a buffer
;cx has the dest buffer size (limmit)
MoveString16:
	lodsb
	cmp	al, 0
	je	MoveString16_Ends
	cmp	cx, 0
	je	MoveString16_Buf_Full
	dec 	cx
	stosb
	jmp	MoveString16
	
MoveString16_Ends:
	mov	al, ' '
	stosb
	ret
MoveString16_Buf_Full:
	mov	al, '~'
	stosb
	ret

;returns in "BiosSignature"
;all bios info
GetBiosInformations:
	pusha
	push	es
	push	ds	
	mov	ax, 0F000h
	mov	ds, ax
	
	push	cs
	pop	es
	mov	di, BiosSignature
	mov	cx, 512
	
	mov	si, 0F400h
	cmp	byte [ds:si], 41h 		;=A	means AMIBIOS
	jne	NotAmiBios
	
	;AMI bios	
	mov	si, 0F400h		;Bios copyright

	call	MoveString16
	
	mov	si, 0F479h		;Bios serial number
	call	MoveString16
	
NotAmiBios:
	mov	si, 0E000h
	cmp	byte [ds:si], 41h		;=A	means Award
	jne	NotAwardBios	
	
	;award bios
	mov	si, 0E061h		;Bios name
	call	MoveString16
	
	mov	si, 0E091h		;Bios copyright
	call	MoveString16
	
	mov	si, 0EC71h		;Bios serial number
	call	MoveString16
	
NotAwardBios:
	mov	si, 04D12h
	cmp	byte [ds:si], 'C'	;Compaq ?
	jne	NotCompaqBios
	
	mov	si, 4D12h
	call	MoveString16
	
	mov	si, 135Dh
	call	MoveString16
	
	mov	si, 5A4Fh
	call	MoveString16
NotCompaqBios:
	
	mov	si, 0FFF5h		;F000:FFF5	;Bios date
	call	MoveString16
	pop	ds
	pop	es	
	popa
	ret
	
GetCMOSData:
	mov	al, 14h			;Installed Equipment
	call	ReadCMOS
	;Bits 7-6 = Number of floppy disks (00 = 1 floppy disk, 01 = 2 floppy disks)
  	;Bits 5-4 = Primary display (00 = Use display adapter BIOS, 01 = CGA 40 column, 10 = CGA 80 column, 11 = Monochrome Display Adapter)
  	;Bit 3 = Display adapter installed/not installed
  	;Bit 2 = Keyboard installed/not installed
  	;Bit 1 = math coprocessor installed/not installed
  	;Bit 0 = Always set to 1
	mov	byte [dbInstEquipment], al
	
	mov	al, 10h			;Floppy Disk Drive Types
	call	ReadCMOS
	;Bits 7-4 = Drive 0 type
  	;Bits 3-0 = Drive 1 type
  	;0000 = None
  	;0001 = 360KB
  	;0010 = 1.2MB
  	;0011 = 720KB
  	;0100 = 1.44MB
  	mov	byte [dbFloppyType], al
	
	ret	


;Get info from CMOS
;input:	al=offset
;output:	al=result byte
ReadCMOS:
	cli
	push	dx
	mov	dx, 70h
	out	dx, al
	mov	dx, 71h	
	in	al, dx
	pop	dx
	sti
	ret
	
GetVGAInfo:
	pusha
	xor	ax, ax
	xor	cx, cx
	; 4fh=VESA function
	mov	di, DataOutOfKernel
	mov	ax, 4f00h	
	int	10h		;make VESA BIOS call
	cmp	ax, 4f00h
	je	.exit
	
	mov	si, DataOutOfKernel
	mov	ax, word [si+6]
	mov	word [VESAoff], ax
	mov	ax, word [si+8]
	mov	word [VESAseg], ax
	
	; Get VESA version number
	mov	ax, word [si+4]
	mov	word [VesaVer], ax
	
	cmp	ah, 2			;Is Vesa 2.0+ ?
	jnb	.Vesa2
	jmp	.exit
.Vesa2:
	mov	ax, 'VB'
	mov	word [si], ax
	mov	ax, 'E2'
	mov	word [si+2], ax

	mov	di, DataOutOfKernel
	mov	ax, 4f00h	
	int	10h		;make VESA BIOS call
	
	mov	si, DataOutOfKernel
	
	mov	ax, word [si+16h]
	mov	word [VESAVNoff], ax
	mov	ax, word [si+18h]
	mov	word [VESAVNseg], ax
	
	mov	ax, word [si+1Ah]
	mov	word [VESAPNoff], ax
	mov	ax, word [si+1Ch]
	mov	word [VESAPNseg], ax
	
	mov	ax, word [si+1Eh]
	mov	word [VESAPRoff], ax
	mov	ax, word [si+20h]
	mov	word [VESAPRseg], ax
	
	mov	ax, word [si+12h]
	mov	word [VesaMem], ax
	
	mov	ax, word [si+14h]
	mov	word [VESASV], ax	
.exit:
	popa
	ret
	

