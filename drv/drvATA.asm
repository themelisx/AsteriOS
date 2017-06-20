;ATA32 driver

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

%define DEBUG

[BITS 32]

org 0

?			EQU	0

Driver_Start:

;executable header 38 bytes
Signature		db	'AsteriOS'
HeaderVersion		db	00010001b		;v.1.0 (4 hi-bits major version, 4 lo-bits minor version)
ExecutableCRC		dd	?			;including rest of header
ExecutableFlags		db	00011110b		;check below (execute init & stop, contains import & export)
ImportTableOffset	dd	ImportTable - Driver_Start
ExportTableOffset	dd	ExportTable - Driver_Start
RelocationTableOffset	dd	0
InitFunctionOffset	dd	InitATA32 - Driver_Start
StopFunctionOffset	dd	StopATA32 - Driver_Start
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
			db	'MemCpy', 0
MemCpy:			dd	?
			db	'GetSystemLoaded', 0
GetSystemLoaded:	dd	?
			db	'RegisterDevice', 0
RegisterDevice:		dd	?
			db	0		;array terminates with null (byte)
			
ExportTable:
			db	'GetATA32Queue', 0
			dd	GetATA32Queue - Driver_Start
			db	0		;array terminates with null (byte)

;export table struct
;Function name (null terminated)
;dword size (in bytes) from the start of executable to the start of the function
;array terminates with null (byte)
;export table

;data
OldInt0E		dd	?
OldInt0F		dd	?
command	db	0
drive			db	0
port			   dw	0
ATA_Buffer		dd	?
Debug_InitATA32	db	'[Init] ATA32 driver', 13, 0
Debug_StopATA32	db	'[Stop] ATA32 driver', 13, 0

sIRQ0E db	'IRQ 0Eh hit', 13, 0
sIRQ0F db	'IRQ 0Fh hit', 13, 0

align 4
FixAddress:
	nop
	call	.local
.local:	pop	eax
	sub	eax, .local
	ret

align 4
InitATA32:
	push	ebp
	call	FixAddress
	mov	ebp, eax
	
	%ifdef DEBUG
	lea 	eax, [ebp + Debug_InitATA32]
	push	eax
	call	[ebp + Print]
	%endif
	
	push	dword 1024
	call	[ebp + MemAlloc]
	mov	dword [ebp + ATA_Buffer], eax
	
	;get old interrupt address
	push	 dword 2Eh
	call	[ebp + GetInterruptAddress]
	mov	dword [ebp + OldInt0E], eax
	
	;enable ATA32 IRQ
	push	dword 2Eh
	lea	eax, [ebp + IRQ_IDE1]
	push	eax
	call	[ebp + HookInterrupt]
	
	;get old interrupt address
	push	 dword 2Fh
	call	[ebp + GetInterruptAddress]
	mov	dword [ebp + OldInt0F], eax
	
	;enable ATA32 IRQ
	push	dword 2Fh
	lea	eax, [ebp + IRQ_IDE2]
	push	eax
	call	[ebp + HookInterrupt]
	
	mov	byte [ebp + command], 0ECh		; Put the hex number for IDENTIFY DRIVE in the var "command".
drive_id:        
	mov	word [ebp + port], 1F0h			; Try port 1f0 .
	mov	byte [ebp + drive], 0			; Try master drive 0 (bit 5 should be 0).
	call	AtaPi_Id_Drive			; Call proc,if no error we have a ata/atapi address.
	
	mov	word [ebp + port], 1F0h			; Try port 1f0 .
	mov	byte [ebp + drive], 10h			; Try slave drive 1 (bit 5 should be 1,so we put 0x10 bin 10000b) .
	call	AtaPi_Id_Drive			; Call proc,if no error we have a ata/atapi address.
	
	mov	word [ebp + port], 170h			; Try port 170 .
	mov	byte [ebp + drive], 0			; Try master drive 0 (bit 5 should be 0).
	call	AtaPi_Id_Drive			; Call proc,if no error we have a ata/atapi address.
	
	mov	word [ebp + port], 170h			; Try port 170 .
	mov	byte [ebp + drive], 10h			; Try slave drive 1 (bit 5 should be 1,so we put 0x10 bin 10000b) .
	call	AtaPi_Id_Drive			; Call proc,if no error we have a ata/atapi address.
	
	cmp	byte [ebp + command], 0A1h		; Have we been here before, yes then lets go!
	je	Lets_go                       
	
	mov	byte [ebp + command], 0A1h		; Put the hex number for ATAPI IDENTIFY DRIVE in the var "command".
	jmp	drive_id             
Lets_go:
	push	dword [ebp + ATA_Buffer]
	call	[ebp + MemFree]
	
	pop	ebp
	ret

align 4	
IDE_Main:
	ret

align 4	
RegisterIDE:
	;name
	;Driver address
	;DMA
	;Channel
	;IRQ
	;Type
	;Flags
	pushad
	
	mov	esi, dword [ebp + ATA_Buffer]
	add	esi, 36h				;Model name
	add	esi, 27h
.fixit:
	cmp	byte [esi], ' '
	jne	.done
	dec	esi
	jmp	.fixit
.done:
	mov	byte [esi+1], 0	
	
	mov	esi, dword [ebp + ATA_Buffer]
	add	esi, 36h				;Model name

	push	esi
	push	dword IDE_Main
	movzx	eax, word [ebp + port]
	push	eax
	movzx	eax, byte [ebp + drive]
	push	eax
	
	cmp	word [ebp + port], 1F0h
	jne	.irq_f	
	push	dword 0Eh		;irq 6
	jmp 	.go
.irq_f:
	push	dword 0Fh
.go:
	push	dword 6		;	DEVICE_IDE
	push	dword 0		;bit 0 : (1=enable)
	call	RegisterDevice

	popad
	ret

align 4
AtaPi_Id_Drive:
        mov   edx, 7
        add   dx, word [ebp + port]
        mov   ecx, 0FFFFh

StatusReg1:                                  
        in    al, dx
        and   al, 80h
        jz    WriteCommand1         
        loop  StatusReg1
                
        jmp   DeviceBusy             
WriteCommand1:
        mov   edx, 6         
        add   dx, word [ebp + port]
        mov   al, byte [ebp + drive]
        or    al, 0EFh
        out   dx, al
        mov   ecx, 0FFFFh
        mov   edx, 7
        add   dx, word [ebp + port] 
        
StatusReg2:                                  
        in    al,dx
        test  al, 80h
        jz    Drdy_check
        loop  StatusReg2 

        jmp   DeviceBusy
Drdy_check:
        test  al, 40h
        jnz   WriteCommand2
        cmp   byte [ebp + command], 0A1h
        je    WriteCommand2
                    
DeviceBusy:
        ret
 ;----------------------------------------------------;
 ;  WriteCommand2                                     ;
 ;----------------------------------------------------;

align 4
WriteCommand2:
        mov   edx, 7           
        add   dx, word [ebp + port]
        mov   al, byte [ebp + command]      
        out   dx, al
        mov   ecx, 0FFFFh
        mov   edx, 7
        add   dx, word [ebp + port] 

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

align 4
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

align 4
Read_data_reg_0:                                                  
        movzx edx, word [ebp + port]
        xor   ecx, ecx
        mov   ecx, 100h
        mov   edi, dword [ebp + ATA_Buffer]
  
 align 4              
Read_data_reg_1:
        in    ax,dx
	xchg  al, ah
        stosw
        loop  Read_data_reg_1             

        call	 RegisterIDE
        ret

align 4
;Clear everything to unload driver	
StopATA32:
	push	ebp	
	call	FixAddress
	mov	ebp, eax
	
	%ifdef DEBUG
	lea 	eax, [ebp + Debug_StopATA32]
	push	eax
	call	[ebp + Print]
	%endif

	;set back old address
	push	dword 2Eh
	push	dword [ebp + OldInt0E]
	call	[ebp + HookInterrupt]
	
	push	dword 2Fh
	push	dword [ebp + OldInt0F]
	call	[ebp + HookInterrupt]
	
	pop	ebp
	ret

align 4
;no input
;returns AL=key
GetATA32Queue:
	push	ebp	
	call	FixAddress
	mov	ebp, eax
		
.exit:
	pop	ebp
	ret

align 4
;primary controller	
IRQ_IDE1:
	push	ebp	
	call	FixAddress
	mov	ebp, eax
	
	pushad
	pushfd
	
	call	[ebp + GetSystemLoaded]
	cmp	eax, 1
	je	.go
	jmp	.exit
.go:

	lea 	eax, [ebp + sIRQ0E]
	push	eax
	call	[ebp + Print]

.exit:	
	popfd
	popad	
	pop	ebp
	
	mov	al, 20h
	out	20h, al
	out	0A0h, al
	iretd

align 4
;secondary controller	
IRQ_IDE2:
	push	ebp	
	call	FixAddress
	mov	ebp, eax
	
	pushad
	pushfd
	
	call	[ebp + GetSystemLoaded]
	cmp	eax, 1
	je	.go
	jmp	.exit
.go:

	lea 	eax, [ebp + sIRQ0F]
	push	eax
	call	[ebp + Print]

.exit:	
	popfd
	popad	
	pop	ebp
	
	mov	al, 20h
	out	20h, al
	out	0A0h, al
	iretd

