;FDC driver
;This driver is internal (kernel)

;chip 82072

align 4
IRQ_FDC:
	pushad
	pushfd
	;cmp	byte [SystemLoaded], 1
	;je	.go
	;jmp	.exit
;.go:
	;push	dword [fdc_irq_func]
	;push	Debug_FDC_IRQ6
	;call	PrintDebug
	
	cmp	dword [fdc_irq_func], 0
	je	.exit
	call 	[fdc_irq_func]
.exit:
	popfd
	popad
	
	mov	al,20h
	out	20h,al
	iretd
	
align 4
;1st: Action
;2nd: Sector
;3rd: Buffer
FDC_Main:
	push	ebp
	mov	ebp, esp
	add	ebp, 8
	
	mov	eax, [ebp+8]
	cmp	eax, IO_READ
	jne	.next1
	
	;start sector
	push	dword [ebp+4]
	;how many sectors to read
	push	dword 1
	;buffer	
	push	dword [ebp]
	call	FDC_Read
	jmp	.exit

.next1:	

.exit:
	pop	ebp
	ret	3*4

align 4
Init_FDC:
	%ifdef DEBUG
	push	Debug_Init_FDC
	call	Print
	%endif

	movzx	eax, byte [dbFloppyType]
	and	al, 11110000b		;keep data for 1st floppy	  	
  	shr	eax, 4
  	cmp	eax, 0
  	jne	.FloppyOk
    	jmp	.exit
  	
.FloppyOk:
 	;0001 = 360KB
  	;0010 = 1.2MB
  	;0011 = 720KB
  	;0100 = 1.44MB
 	cmp	al, 1
 	jne	.next1
 	push	dword Floppy360
 	jmp	.next4
.next1:
 	cmp	al, 10b
 	jne	.next2
 	push	dword Floppy120
 	jmp	.next4
.next2:
 	cmp	al, 11b
 	jne	.next3
 	push	dword Floppy720
 	jmp	.next4
.next3:
	push	dword Floppy144 	
.next4:
	;name
	;Driver address
	;DMA
	;Channel
	;IRQ
	;Type
	;Flags
	
	;name already pushed
	push	dword FDC_Main
	push	dword 03F0h	;TODO: is 3f0 base address???
	push	dword 0		;channel unused
	push	dword 6		;irq 6
	push	dword DEVICE_FLOPPY
	push	dword 1		;bit 0 = enable
	call	RegisterDevice
	
	;register storage device
	;1.param: Drive number (0=A, 1=B...)
	;2.param: Drive Type
	;3.param: driver address
	;4.param: FS address
	push	dword 0
	push	dword 0		;TODO: fill currect value
	push	dword FDC_Main
	push	dword FAT12_Main
	call	RegisterStorageDevice	
	
	;enable FDC IRQ
	push	dword 26h
	push	dword IRQ_FDC
	call	HookInterrupt
	call	Enable_IRQs		;enable now	
	
	call	FDC_Motor_On
	mov	al, 3			;specify drive params
	call	FDC_Write_reg
	mov	al, 0DFh
	call	FDC_Write_reg
	mov	al, 10b			;DMA mode ON
	call	FDC_Write_reg
	mov	al, 7			;recalibrate
	call	FDC_Write_reg
	mov	al, 0			;drive
	call	FDC_Write_reg
	call	FDC_Motor_Off
	
	;register FDC functions
	call 	FDC_RegisterFunctions
.exit:
	ret

align 4	
FDC_Stop:
	%ifdef DEBUG
	push	Debug_FDC_Stop
	call	Print
	%endif

	call	FDC_Motor_Off
	
	ret
	
FDC_RegisterFunctions:
	;floppy functions
	push	dword sInit_FDC
	push	dword Init_FDC
	call	SetProcAddress
	
	push	dword sFDC_Stop
	push	dword FDC_Stop
	call	SetProcAddress
	
	push	dword sFDC_DO
	push	dword FDC_DO
	call	SetProcAddress
	
	ret

;start sector
;how many sectors to read
;buffer	
FDC_Read:
	push	ebp
	mov	ebp, esp
	add	ebp, 8
	
	%ifdef DEBUG_2
	push 	dword [ebp]
	push 	dword [ebp+4]
	push 	dword [ebp+8]
	push	Debug_FDC_Read
	call	Print
	%endif

	;calculate LBA
	;LBA = ( ( CYL * HPC + HEAD ) * SPT ) + SECT - 1
	;LBA: linear base address of the block
	;CYL: value of the cylinder CHS coordinate
	;HPC: number of heads per cylinder for the disk
	;HEAD: value of the head CHS coordinate
	;SPT: number of sectors per track for the disk
	;SECT: value of the sector CHS coordinate	
	
	;The equations to convert from LBA to CHS follow:
	;CYL = LBA / (HPC * SPT)
	;TEMP = LBA % (HPC * SPT)
	;HEAD = TEMP / SPT
	;SECT = TEMP % SPT + 1

	;Where:
	;LBA: linear base address of the block
	;CYL: value of the cylinder CHS coordinate
	;HPC: number of heads per cylinder for the disk
	;HEAD: value of the head CHS coordinate
	;SPT: number of sectors per track for the disk
	;SECT: value of the sector CHS coordinate
	;TEMP: buffer to hold a temporary value
	push	ebx
	push	ecx
	push	edx
	push	esi
	push	edi
	
	mov	ecx, [ebp+4]		;count of sectors to read
	mov	edi, [ebp]		;buffer
	mov	esi, dword [BootSector]
	mov	eax, [ebp+8]		;LBA
.loop:	
	push	ecx
	push	eax			;save LBA
	movzx	ebx, byte [esi+10h]	;Number Of FATs		
	xor	edx, edx
	movzx	ebx, word [esi+18h]	;Sectors Per Track	
	div	ebx
	inc	edx
	mov 	[sector], dl
	xor	edx, edx
	movzx	ebx, word [esi+1Ah]	;Heads Per Cylinder
	div	ebx

	push	dword DMA_READ		;Operation
	push	dword 0			;fdd
	and	eax, 0FFh		;keep AL
	push	dword eax		;track
	and	edx, 0FFh		;keep DL
	push	dword edx		;head
	movzx	eax, byte [sector]
	push	dword eax		;sector
	push	edi			;buffer
	call	FDC_DO
.loop1:
	nop
	call	Delay32
	cmp	byte [FDC_Busy_Flag], 1
	je	.loop1
	
	movzx	eax, word [esi+0Bh]	;Bytes Per Sector
	add	edi, eax
	
	pop	eax			;restore LBA
	inc	eax			;read next sector
	pop	ecx
	dec	ecx
	jnz	.loop
	
	pop	edi
	pop	esi
	pop	edx
	pop	ecx
	pop	ebx	
	pop	ebp
	ret	3*4
	
;start sector
;how many sectors to write
;buffer	
FDC_WriteSectors:
	push	ebp
	mov	ebp, esp
	add	ebp, 8
	
	%ifdef DEBUG
	push 	dword [ebp]
	push 	dword [ebp+4]
	push 	dword [ebp+8]
	push	Debug_FDC_Write
	call	Print
	%endif

	;calculate LBA
	;LBA = ( ( CYL * HPC + HEAD ) * SPT ) + SECT - 1
	;LBA: linear base address of the block
	;CYL: value of the cylinder CHS coordinate
	;HPC: number of heads per cylinder for the disk
	;HEAD: value of the head CHS coordinate
	;SPT: number of sectors per track for the disk
	;SECT: value of the sector CHS coordinate	
	
	;The equations to convert from LBA to CHS follow:
	;CYL = LBA / (HPC * SPT)
	;TEMP = LBA % (HPC * SPT)
	;HEAD = TEMP / SPT
	;SECT = TEMP % SPT + 1

	;Where:
	;LBA: linear base address of the block
	;CYL: value of the cylinder CHS coordinate
	;HPC: number of heads per cylinder for the disk
	;HEAD: value of the head CHS coordinate
	;SPT: number of sectors per track for the disk
	;SECT: value of the sector CHS coordinate
	;TEMP: buffer to hold a temporary value
	push	ebx
	push	ecx
	push	edx
	push	esi
	push	edi
	
	mov	ecx, [ebp+4]		;count of sectors to write
	mov	edi, [ebp]		;buffer
	mov	esi, dword [BootSector]
	mov	eax, [ebp+8]		;LBA
.loop:	
	push	ecx
	push	eax			;save LBA
	movzx	ebx, byte [esi+10h]	;Number Of FATs		
	xor	edx, edx
	movzx	ebx, word [esi+18h]	;Sectors Per Track	
	div	ebx
	inc	edx
	mov 	[sector], dl
	xor	edx, edx
	movzx	ebx, word [esi+1Ah]	;Heads Per Cylinder
	div	ebx

	push	dword DMA_WRITE		;Operation
	push	dword 0			;fdd
	and	eax, 0FFh		;keep AL
	push	dword eax		;track
	and	edx, 0FFh		;keep DL
	push	dword edx		;head
	movzx	eax, byte [sector]
	push	dword eax		;sector
	push	edi			;buffer
	call	FDC_DO
.loop1:
	nop
	call	Delay32
	cmp	byte [FDC_Busy_Flag], 1
	je	.loop1
	
	movzx	eax, word [esi+0Bh]	;Bytes Per Sector
	add	edi, eax
	
	pop	eax			;restore LBA
	inc	eax			;read next sector
	pop	ecx
	dec	ecx
	jnz	.loop
	
	pop	edi
	pop	esi
	pop	edx
	pop	ecx
	pop	ebx	
	pop	ebp
	ret	3*4


;params:
;fdd_operation:dword
;fdd_nr:DWORD
;track_nr:DWORD
;head_nr:DWORD
;sect_nr:DWORD
;lp_buff:DWORD
align 4	
FDC_DO:
	;%push     mycontext        ; save the current context 
	;%stacksize large           ; tell NASM to use bp 
	;%arg      fdd_operation:dword, fdd_nr:dword, track_nr:dword, head_nr:dword, sect_nr:dword, lp_buff:dword	
	push	ebp
	mov	ebp, esp
	add	ebp, 8
	
	mov	byte [FDC_Busy_Flag], 1
	
	%ifdef DEBUG_2
	push	dword [ebp]	;buffer
	push	dword [ebp+4]	;sector
	push	dword [ebp+8]	;head
	push	dword [ebp+12]	;track
	push	dword [ebp+16]	;fdd
	push	dword [ebp+20]	;operation	
	push	dword Debug_FDC_Do
	;Debug_FDC_Do='FDC Do: Operation:%d, fdd:%d, track:%d, head:%d, sector:%d, buffer:0x%x', 13, 0
	call	Print
	%endif

 	mov	eax, dword [ebp+20]
 	add	al, 2			;drive num
	mov	[dmamode], al
	
	mov	eax, dword [ebp+8]
	mov 	[head], al
	
	mov	eax, dword [ebp+12]
	mov 	[track], al
	
	mov	eax, dword [ebp+4]
	mov 	[sector], al
	
	mov	eax, dword [ebp]
	mov	[fdcbuf], eax
	
	mov 	[fdc_irq_func], dword FDC_Commit1
	
	;cmp	byte [dmamode], DMA_READ
	push	edi
	mov	edi, SCREEN_MEM + 0F9Ch
	mov	word [edi], 2041h
	pop	edi
	
	cmp	dword [FDC_Motor_Timer], 0
	jne	.next
	call 	FDC_Motor_On		;start floppy A: moter starts interruptflow.
	jmp	.exit
.next:
	mov	dword [FDC_Motor_Timer], FLOPPY_DELAY		;2 sec	
	mov 	dword [fdc_irq_func], 0
	call	FDC_Commit2
.exit:
	pop	ebp
	ret	4*6

	
FDC_Commit1:
	mov 	[fdc_irq_func], dword FDC_ReCalibrate_Result
	mov 	[fdc_pump_func], dword FDC_Commit2
	call 	FDC_ReCalibrate		;retract the head to track 0, sector 1
	ret
FDC_Commit2:
	mov 	[fdc_pump_func], dword FDC_Done ;FDC_FullPump
	call	FDC_Write
	ret
	
FDC_Write:	
	call 	FDC_ProgramDMA
	call 	FDC_Seek
	ret
	
FDC_Done:
	;push	dword Debug_FDC_Done
	;call	PrintDebug
	push	esi
	push	edi
	push	ecx
	mov	esi, FDC_DMA_BUFFER
	mov	edi, dword [fdcbuf]
	mov	ecx, SECTOR_SIZE
	shr	ecx, 2			;/4
	rep	movsd
	pop	ecx
	pop	edi
	pop	esi
	
	push	edi
	mov	edi, SCREEN_MEM + 0F9Ch
	mov	word [edi], 7020h
	pop	edi

	mov 	[fdc_irq_func], dword 0
	mov	dword [FDC_Motor_Timer], FLOPPY_DELAY		;2 sec
	
	mov	byte [FDC_Busy_Flag], 0
	
	ret

FDC_Seek:
	mov 	al, 0Fh
	call 	FDC_Write_reg
	mov 	al, [head]
	shl 	al, 2
	call 	FDC_Write_reg
	mov 	al, [track]
	call 	FDC_Write_reg
	mov 	[fdc_irq_func], dword FDC_Seek_Result	
	
	ret

FDC_Seek_Result:
	call 	FDC_Sensei
	cmp 	al, [track]
	je 	.done
	call 	FDC_Seek
	jmp 	.end
.done:	
	call 	FDC_Write_Sector
.end:
	ret
	
FDC_Write_Sector:	
	mov	al, [dmamode]		;read/write sector command
	call	FDC_Write_reg
	mov 	al, [head]		
	shl 	al, 2	
	call 	FDC_Write_reg
	mov 	al, [track]
	call 	FDC_Write_reg
	mov 	al, [head]
	call 	FDC_Write_reg
	mov 	al, [sector]	
	call 	FDC_Write_reg
	mov 	al, 2			;Sector size (2 ~> 512 bytes)
	call 	FDC_Write_reg
	mov 	al, 18			;last sector on track.
	call 	FDC_Write_reg
	mov 	al, 1Bh			;length of GAP3 
	call 	FDC_Write_reg
	mov 	al, 0FFh		;data length, ignored.
	call 	FDC_Write_reg
	mov 	[fdc_irq_func], dword FDC_ResultPhase	
	
	ret
	
FDC_ResultPhase:
	call 	FDC_Read_reg
	mov 	[fdc_st0], al
	mov 	ecx, 6
.loop:
	call 	FDC_Read_reg
	loop 	.loop
	and 	[fdc_st0], byte 11000000b
	
	cmp 	[fdc_st0], byte 0
	jz 	.done
	
	call 	FDC_Seek
	jmp 	.end
.done:
	cmp	dword [fdc_pump_func], 0
	je	.end
		
	call 	[fdc_pump_func]
.end:
	ret

FDC_Sensei:	
	mov 	al, 8			;get interrupt status command
	call 	FDC_Write_reg		
	call 	FDC_Read_reg		;get result in al;
	and 	al, 80h
	cmp 	al, 80h
	je 	FDC_Sensei		;retry
	call 	FDC_Read_reg
	ret

FDC_Read_reg:
	mov 	edx, 03F4h
	in 	al, dx
	and 	al, 0C0h
	cmp 	al, 0C0h
	jne 	FDC_Read_reg
	mov 	edx, 03F5h
	in 	al, dx 
	ret

;input AL
FDC_Write_reg:
	mov 	bl, al
.loop
	mov 	edx, 03F4h
	in 	al, dx
	and 	al, 80h
	cmp 	al, 80h
	jne 	.loop
	mov 	al, bl
	mov 	edx, 03F5h
	out 	dx, al
	ret
	
FDC_ReCalibrate_Result:
	mov 	al, 8			;get interrupt status command
	call 	FDC_Write_reg	  	;send it
	call 	FDC_Read_reg		;get command in al;
	cmp 	al, 80h
	je 	FDC_ReCalibrate_Result
	mov 	ah, al
	call 	FDC_Read_reg
	cmp 	ah, 70h
	jne 	.end1
	call 	FDC_ReCalibrate
	jmp 	.end2
.end1:
	cmp	dword [fdc_pump_func], 0
	je	.end2
	call 	[fdc_pump_func]
.end2:
	ret
	
FDC_ReCalibrate:
	mov 	al, 7			;calibrate command
	call 	FDC_Write_reg
	mov 	al, 0			;select drive 0
	call 	FDC_Write_reg
	ret

FDC_Motor_Off:
	;push	Debug_FDC_StopMotor
	;call	PrintDebug

	push	edx
	mov	dword [FDC_Motor_Timer], 0
	xor	eax, eax
	mov	edx, 03F2h
	out	dx, al
	pop	edx
	ret

FDC_Motor_On:
	;push	Debug_FDC_StartMotor
	;call	PrintDebug

	push	edx
	mov	dword [FDC_Motor_Timer], FLOPPY_DELAY		;2 sec
	mov 	eax, 1Ch
	mov 	edx, 3F2h
	out 	dx, al
	pop	edx
	ret

FDC_Busy:
	push	edx
.loop:
	mov	edx, 03F4h
	in	al, dx
	and 	al, 10h
	cmp 	al, 10h
	je	.loop
	pop	edx
	ret

FDC_ProgramDMA:	
	push	edx
	;mask channel 2
	mov     eax, 6
	out     0Ah, al          
	;clear pointers
	xor	eax, eax
	out	0Ch, al          ; clr byte ptr
	;setup mode of operation
	mov	al, [dmamode]	;byte [dmamode]	; read from device and WRITE to memory
	;add	al, 2		; add device nr
	out	0Bh, al          ; set mode reg
	;set page low register
	mov	edx, 81h
        mov	eax, FDC_DMA_BUFFER	;dword [fdcbuf]
	shr	eax, 16
;	and	eax, 3
	out	dx, al           ; set DMA page reg
	;setup offset addr
	mov	edx, 4
	mov	eax, FDC_DMA_BUFFER	;dword [fdcbuf]
	and	eax, 0FFFFh
	out	dx, al		; set base address low
	mov	al, ah
	out	dx, al		; set base address high
	;setup length
	mov	eax, SECTOR_SIZE
	dec	eax		; length-1
	mov	edx, 5
	out	dx, al		; set length low
	mov	al, ah
	out	dx, al		; set length high
	;unmask channel 2
	mov	al, 2
	out	0Ah, al          ; unmask (activate) dma channel
	pop	edx
	ret
	