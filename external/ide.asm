; ATA IDE I/O Ports:
;----------------------------------------
; 1F0h	Read/Write	= Data Port
;
; 1F1h	READ		= Error register
; 1F1h	Write		= Write precompensation (obsolete?)
;
; 1F2h	Read/Write	= Sector Count, how many sector to transfer in one operation
; 1F3h	Read/Write	= Sector Number to start operation from
; 1F4h	Read/Write	= Track/Cylinder LOW
; 1F5h	Read/Write	= Track/Cylinder High
; 1F6h	Read/Write	= Drive + Head packed
;
; 1F7h	Write	= Command to be executed (byte)
;			ECh	- Identify Drive
;			1Xh	- Reclibrate Drive
;			7Xh	- Seek
;
;			20h	- Read Sectors with retry
;			21h	- Read Sectors
;			30h	- Write Sectors with retry
;			31h	- Write Sectors
;			50h	- Format Track
;
;
; 1F7h	Read	= Status register
;	bit 7 	- BUSY	= Can not read/write any command registers
;	bit 6	- DRDY	= Drive ready to acept commands
;	bit 5	- DF	= Drive Fault (vendor specific)
;	bit 4	- DSC	= Drive Seek Complete
;	bit 3	- DRQ	= Data Request Bit
;	bit 2	- CORR	= Corrected Data bit
;	bit 1	- INDEX	= Index hole (vendor specific)
;	bit 0	- ERR	= An Erorr occured
;
; 3F6h	Read	= Alternate Status register
; 3F6h	Write	= Device Control register

IDE_Main:
	ret

;ATA_Identify_Device command = 0xec
;ATA_Identify_Packet_Device = 0xa1

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

Init_IDE:
	pushad
	push	dword 1024
	call	MemAlloc
	mov	dword [ATA_Buffer], eax
	
	push	dword 2Eh
	push	dword IRQ_IDE
	call	HookInterrupt
	call	Enable_IRQs		;enable now	
	
	push	dword 2Fh
	push	dword IRQ_IDE2
	call	HookInterrupt
	call	Enable_IRQs		;enable now	
		
        mov	byte [command], 0ECh		; Put the hex number for IDENTIFY DRIVE in the var "command".
drive_id:        
	mov	word [port], 1F0h			; Try port 1f0 .
	mov	byte [drive], 0			; Try master drive 0 (bit 5 should be 0).
	call	AtaPi_Id_Drive			; Call proc,if no error we have a ata/atapi address.
	
	mov	word [port], 1F0h			; Try port 1f0 .
	mov	byte [drive], 10h			; Try slave drive 1 (bit 5 should be 1,so we put 0x10 bin 10000b) .
	call	AtaPi_Id_Drive			; Call proc,if no error we have a ata/atapi address.
	
	mov	word [port], 170h			; Try port 170 .
	mov	byte [drive], 0			; Try master drive 0 (bit 5 should be 0).
	call	AtaPi_Id_Drive			; Call proc,if no error we have a ata/atapi address.
	
	mov	word [port], 170h			; Try port 170 .
	mov	byte [drive], 10h			; Try slave drive 1 (bit 5 should be 1,so we put 0x10 bin 10000b) .
	call	AtaPi_Id_Drive			; Call proc,if no error we have a ata/atapi address.
	
	cmp	byte [command], 0A1h		; Have we been here before, yes then lets go!
	je	Lets_go                       
	
	mov	byte [command], 0A1h		; Put the hex number for ATAPI IDENTIFY DRIVE in the var "command".
	jmp	drive_id             
Lets_go:
	push	dword [ATA_Buffer]
	call	MemFree
	popad	
	ret

RegisterIDE:
	;name
	;Driver address
	;DMA
	;Channel
	;IRQ
	;Type
	;Flags
	pushad
	
	mov	esi, dword [ATA_Buffer]
	add	esi, 36h				;Model name
	add	esi, 27h
.fixit:
	cmp	byte [esi], ' '
	jne	.done
	dec	esi
	jmp	.fixit
.done:
	mov	byte [esi+1], 0	
	
	mov	esi, dword [ATA_Buffer]
	add	esi, 36h				;Model name

	push	esi
	push	dword IDE_Main
	movzx	eax, word [port]
	push	eax
	movzx	eax, byte [drive]
	push	eax
	
	cmp	word [port], 1F0h
	jne	.irq_f	
	push	dword 0Eh		;irq 6
	jmp 	.go
.irq_f:
	push	dword 0Fh
.go:
	push	dword DEVICE_IDE
	push	dword 0		;bit 0 : (1=enable)
	call	RegisterDevice

	popad
	ret

AtaPi_Id_Drive:
        mov   edx, 7
        add   dx, word [port]
        mov   ecx, 0FFFFh

StatusReg1:                                  
        in    al, dx
        and   al, 80h
        jz    WriteCommand1         
        loop  StatusReg1
                
        jmp   DeviceBusy             
WriteCommand1:
        mov   edx, 6         
        add   dx, word [port]
        mov   al, byte [drive]
        or    al, 0EFh
        out   dx, al
        mov   ecx, 0FFFFh
        mov   edx, 7
        add   dx, word [port] 
        
StatusReg2:                                  
        in    al,dx
        test  al, 80h
        jz    Drdy_check
        loop  StatusReg2 

        jmp   DeviceBusy
Drdy_check:
        test  al, 40h
        jnz   WriteCommand2
        cmp   byte [command], 0A1h
        je    WriteCommand2
                    
DeviceBusy:
        ret
 ;----------------------------------------------------;
 ;  WriteCommand2                                     ;
 ;----------------------------------------------------;

WriteCommand2:
        mov   edx, 7           
        add   dx, word [port]
        mov   al, byte [command]      
        out   dx, al
        mov   ecx, 0FFFFh
        mov   edx, 7
        add   dx, word [port] 

StatusReg3: 
        in    al, dx
        test  al, 80h
        jnz   DrqErrorCheck1
        test  al, 1
        jnz   error
        test  al, 8 
        jnz   Read_data_reg_0
        ret
 ;----------------------------------------------------;
 ; DrqErrorCheck                                      ;
 ;----------------------------------------------------;

DrqErrorCheck1:
        push  ecx
        mov   ecx, 0FFFFh
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

        pop   ecx
        loop  StatusReg3

error:
        ret
 ;----------------------------------------------------;
 ; Read data reg              (& move it into buffer) ;
 ;----------------------------------------------------;


Read_data_reg_0:                                                  
        movzx edx, word [port]
        xor   ecx, ecx
        mov   ecx, 100h
        mov   edi, dword [ATA_Buffer]
                
Read_data_reg_1:
        in    ax,dx
	xchg  al, ah
        stosw
        loop  Read_data_reg_1             

        call	 RegisterIDE
        ret



