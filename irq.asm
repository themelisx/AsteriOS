;TODO:
Delay32:
	nop
	db	0E9h, 0, 0, 0, 0
	db	0E9h, 0, 0, 0, 0
	ret

;input:
;1st param: interrupt number
;2nd param: new address
HookInterrupt:
	push	ebp
	mov	ebp, esp
	add	ebp, 8
	
	push	ebx
	push	ecx
	
	%ifdef DEBUG
	push	dword [ebp]
	push	dword [ebp+4]
	push	Debug_HookInterrupt
	call	Print
	%endif

	mov	eax, [ebp]		;address
	mov	ecx, [ebp+4]		;interrupt number	
	
	shl	ecx, 3			;8 bytes per interrupt
	mov	ebx, idt		;interrupt table address
	add	ebx, ecx

	mov 	[ebx], ax
	shr 	eax, 16
	mov 	[ebx + 6], ax
	
	;set bit flag
	mov	ecx, [ebp+4]		;interrupt number
	mov	eax, 1	
	shl	eax, cl
	not	eax	
	and	eax, [os_irq_mask]
	mov	[os_irq_mask], eax
	
	pop	ecx
	pop	ebx
	pop	ebp
	ret	2*4

;input: interrupt number
;returns in eax the address
GetInterruptAddress:
	push	ebp
	mov	ebp, esp
	add	ebp, 8
	
	push	ebx
	push	ecx
	
	mov	ecx, [ebp]		;interrupt number	
	
	shl	ecx, 3			;8 bytes per interrupt
	mov	ebx, idt		;interrupt table address
	add	ebx, ecx

	xor	eax, eax
	mov	ax, word [ebx + 6]
	ror 	eax, 16
	mov 	ax, word [ebx]	
	
	%ifdef DEBUG
	push	eax
	push	eax
	push	dword [ebp]
	push	Debug_GetInterruptAddress
	call	Print
	pop	eax
	%endif

	pop	ecx
	pop	ebx
	pop	ebp	
	ret	4
	
Setup_IDT:
	; set up interrupt handlers
	
	%ifdef DEBUG
	push	dword SetupIRQs
	call	Print
	%endif
		
	mov 	ecx, 2Fh 	; number of exception handlers
	mov	ebx, idt
	mov 	edx, int00_hand
do_idt:	
	mov 	eax, edx		; EAX=offset of entry point
	mov 	[ebx], ax		; set low 16 bits of gate offset
	shr 	eax, 16
	mov 	[ebx + 6], ax	; set high 16 bits of gate offset
	add 	ebx, 8		; 8 bytes/interrupt gate
	add 	edx, (int01_hand - int00_hand)	; bytes/stub
	
	dec	ecx
	mov	eax, 1	
	shl	eax, cl
	not	eax	
	and	eax, [os_irq_mask]
	mov	[os_irq_mask], eax
	
	cmp	ecx, 0
	jne	do_idt
	
		
; NOTE: the address of the IDT, stored at [idt_ptr + 2],
; was converted to a linear address above
	lidt 	[cs:idt_ptr]
	
	ret
	
Setup_PIC:
	%ifdef DEBUG
	push	dword SetupPIC
	call	Print
	%endif	
	
	in      al,021h
	mov     ah,al
	in      al,0A1h
	mov     cx,ax	

	mov	al,011h 		; ICW1 to both controllers
	out	20h, al			; bit 0=1: ICW4 provided
	call	Delay32			; bit 1=0: cascaded PICs
	out	0A0h, al		; bit 2=0: call address interval 8 
	call	Delay32			; bit 4=1: at 1 (?)
	
	mov	al, 20h 		; ICW2 PIC1 - offset of vectors
	out	21h, al			; irq00:07 mapped to int_20h:27h
	call	Delay32
		
	mov	al, 28h 		; ICW2 PIC2 - offset of vectors
	out	0A1h, al		; irq08:15 mapped to int028h:2fh
	call	Delay32
		
	mov	al,04h			; ICW3 PIC1 (master)
	out	21h, al			; bit 2=1: irq2 is the slave
	call	Delay32
		
	mov	al,02h			; ICW3 PIC2
	out	0A1h, al		; bit 1=1: slave id is 2
	call	Delay32
		
	mov	al,01h			; ICW4 to both controllers
	out	21h, al			; bit 0=1: 8086 mode
	call	Delay32
	out	0A1h, al
	call	Delay32
		
	mov     ax,cx
	out     0A1h,al
	mov     al,ah
	out     021h,al

	mov	ecx,1000h
	
.wait_8259:
	call	Delay32

	dec	ecx
	jnz	.wait_8259	

	mov	eax,-1
	mov	[os_irq_mask],eax
	; mask all irqs
	out     0A1h,al
	out     021h,al	
	
	ret

;Enable IRQs that marked in the mask	
Enable_IRQs:	
	%ifdef DEBUG
	push	Debug_Enable_IRQs
	call	Print
	%endif

	cli
	push	ebx
	mov	ebx, [os_irq_mask]
	mov	al, bl
	out	021h, al	
	mov	al, bh
	out	0A1h, al
	pop	ebx
	sti
	ret

;Disable ALL IRQs
Disable_IRQs:
	%ifdef DEBUG
	push	Debug_Disable_IRQs
	call	Print
	%endif

	cli
	mov	eax,-1
	mov	[os_irq_mask], eax	
	out    	021h, al
	out    	0A1h, al	
	sti
	ret

;----------------------------------------------
; CPU Exceptions,Traps and Aborts first
;----------------------------------------------
; TODO: add handlers for them later
;----------------------------------------------

		align 4
int00_hand:	
		mov	al, 0
		jmp	ExceptionLevel1

		align	4
int01_hand:
		mov	al, 1
		jmp	ExceptionLevel1

		align	4
int02_hand:
		mov	al, 2 
		jmp	ExceptionLevel1

		align 4
int03_hand:
		mov	al, 3 
		jmp	ExceptionLevel1	

		align 4
int04_hand:
		mov	al, 4 
		jmp	ExceptionLevel1

		align 4
int05_hand:
		mov	al, 5 
		jmp	ExceptionLevel1

		align 4
int06_hand:
		mov	al, 6 
		jmp	ExceptionLevel1

		align 4
int07_hand:
		mov	al, 7 
		jmp	ExceptionLevel1

		align 4
int08_hand:
		mov	al, 8 
		jmp	ExceptionLevel3

		align 4
int09_hand:
		mov	al, 9 
		jmp	ExceptionLevel1
		
		align 4
int0A_hand:
		mov	al, 0Ah 
		jmp	ExceptionLevel2

		align 4
int0B_hand:
		mov	al, 0Bh
		jmp	ExceptionLevel2

		align 4
int0C_hand:
		mov	al, 0Ch
		jmp	ExceptionLevel2

		align 4
int0D_hand:
		mov	al, 0Dh 
		jmp	ExceptionLevel2

		align 4
int0E_hand:
		mov	al, 0Eh 
		jmp	ExceptionLevel2

		align 4
int0F_hand:
		mov	al, 0Fh 
		jmp	ExceptionLevel3

		align 4
int10_hand:
		mov	al, 10h
		jmp	ExceptionLevel1

		align 4
int11_hand:
		mov	al, 11h 
		jmp	ExceptionLevel2

		align 4
int12_hand:
		mov	al, 12h 
		jmp	ExceptionLevel1

		align 4
int13_hand:
		mov	al, 13h
		jmp	ExceptionLevel1

		align 4
int14_hand:	;page fault
		mov	al, 14h 
		jmp	ExceptionLevel0

		align 4
int15_hand:
		mov	al, 15h 
		jmp	ExceptionLevel0

		align 4
int16_hand:
		mov	al, 16h 
		jmp	ExceptionLevel0

		align 4
int17_hand:
		mov	al, 17h 
		jmp	ExceptionLevel0

		align 4
int18_hand:
		mov	al, 18h 
		jmp	ExceptionLevel0

		align 4
int19_hand:
		mov	al, 19h 
		jmp	ExceptionLevel0

		align 4
int1A_hand:
		mov	al, 1Ah 
		jmp	ExceptionLevel0
		
		align 4
int1B_hand:
		mov	al, 1Bh 
		jmp	ExceptionLevel0

		align 4
int1C_hand:
		mov	al, 1Ch 
		jmp	ExceptionLevel0

		align 4
int1D_hand:
		mov	al, 1Dh 
		jmp	ExceptionLevel0

		align 4
int1E_hand:
		mov	al, 1Eh 
		jmp	ExceptionLevel0

		align 4
int1F_hand:
		mov	al, 1Fh 
		jmp	ExceptionLevel0
		
		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Interrupts ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;TODO: remove all dummy interrupt functions
		align 4
int20_hand:
		mov	al, 20h 
		jmp	main_int_hand1

		align	4
int21_hand:	
		mov	al, 22h 
		jmp	main_int_hand1		

		align	4
int22_hand:
		mov	al, 22h 
		jmp	main_int_hand1

		align 4
int23_hand:
		mov	al, 23h 
		jmp	main_int_hand1		

		align 4
int24_hand:
		mov	al, 24h 
		jmp	main_int_hand1

		align 4
int25_hand:
		mov	al, 25h 
		jmp	main_int_hand1

		align 4
int26_hand:
		mov	al, 26h 
		jmp	main_int_hand1

		align 4
int27_hand:
		mov	al, 27h 
		jmp	main_int_hand1

		align 4
int28_hand:
		mov	al, 28h 
		jmp	main_int_hand2

		align 4
int29_hand:
		mov	al, 29h 
		jmp	main_int_hand2

		align 4
int2A_hand:
		mov	al, 2Ah 
		jmp	main_int_hand2

		align 4
int2B_hand:
		mov	al, 2Bh 
		jmp	main_int_hand2

		align 4
int2C_hand:
		mov	al, 2Ch 
		jmp	main_int_hand2

		align 4
int2D_hand:
		mov	al, 2Dh 
		jmp	main_int_hand2

		align 4
int2E_hand:
		mov	al, 2Eh 
		jmp	main_int_hand2

		align 4
int2F_hand:
		mov	al, 2Fh 
		jmp	main_int_hand2

		align 4
int30_hand:
		mov	al, 30h 
		jmp	$

		align 4

		
Exit_Interrupt1:
		mov	al,20h
		out	20h,al
		iretd
		
Exit_Interrupt2:
		mov	al,20h
		out	0A0h,al	
		iretd

align 4

ExceptionLevel0:
	;return address of exception eip is already pushed (used now as param)
	and	eax, 0FFh
	push	eax	
	push	dword SystemHalted
	call	Print	
	;call	OSM2LFB
	jmp	$	;halt
		
;Exceptions
ExceptionLevel1:	
	;return address of exception eip is already pushed (used now as param)
	and	eax, 0FFh
	push	eax	
	push	dword ExceptionX
	call	Print
	
	push	dword OS_Main_Loop
	iretd
	
ExceptionLevel2:
	pop	eax
	push	100h
	call	PrintHexView
	;call	OSM2LFB
	jmp $
	;error code already pushed
	;return address of exception eip is already pushed (used now as param)
	and	eax, 0FFh
	push	eax	
	push	dword ExceptionX_ErrorCode
	call	Print
	
	push	dword OS_Main_Loop
	iretd
	
ExceptionLevel3:
	;error code already pushed
	;return address of exception eip is already pushed (used now as param)
	;selector has pushed
	and	eax, 0FFh
	push	eax	
	push	dword ExceptionX_Sel
	call	Print
	
	push	dword 08		;valid selector
	push	dword OS_Main_Loop
	iretd
	
	align 4	
	;page fault	
IRQ_PageFault:
	mov	eax, cr2
	push	eax	
	push	dword PageFault
	call	Print	
	;call	OSM2LFB
	jmp	$	;halt
	
	align	4
	
main_int_hand1:	
	pushad
	and	eax, 0FFh
	sub	eax, 20h
	push	eax
	push	dword Unhandle_IRQ
	call	Print
		
	; send EOI to PIC_A
	mov	al,20h
	out	20h,al
	popad
	iretd
	
	align	4
		
main_int_hand2:	
	pushad
	and	eax, 0FFh
	sub	eax, 20h
	push	eax
	push	dword Unhandle_IRQ
	call	Print
		
	; send EOI to PIC_A
	mov	al,20h
	out	0A0h,al
	popad
	iretd

align 4	
IRQ_2:
	jmp	Exit_Interrupt1
	
;Interrupts	
	align 4	
IRQ_Timer:
	mov	dword [tmp_eax], eax
	pushfd
	pop	eax
	mov	dword [tmp_flags], eax
	
	mov	al,20h
	out	20h,al		
	
	cmp	byte [SystemLoaded], 1
	je	.doit
	jmp	.exit
.doit:

	cmp	byte [Multitasking], 1		;multitasking disabled ?
	je	.do_multitask
	jmp	.no_multi_task
.do_multitask:	
	
	cmp	byte [InitMultitask], 1
	je	.init_multitask
	
	push	ecx
	push	edx
	
	movzx	eax, byte [CurrentProcess]
	xor	edx, edx
	mov	ecx, PROCESS_STRUCT_SIZE
	mul	ecx	
	add	eax, dword [ProcessArray]
	
	pop	edx
	pop	ecx
	
	;save old data
	mov	dword [eax+tss.ebx], ebx
	
	mov	ebx, cr3
	mov	dword [eax+tss.cr3], ebx	
	push	dword [tmp_eax]
	pop	dword [eax+tss.eax]	
	push	dword [tmp_flags]
	pop	dword [eax+tss.eflags]	
	mov	dword [eax+tss.ecx], ecx
	mov	dword [eax+tss.edx], edx
	mov	dword [eax+tss.esi], esi
	mov	dword [eax+tss.edi], edi
	mov	dword [eax+tss.ebp], ebp	
	mov	dword [eax+tss.esp], esp
	mov	word [eax+tss.ss], ss	
	mov	word [eax+tss.ds], ds
	mov	word [eax+tss.es], es
	mov	word [eax+tss.fs], fs
	mov	word [eax+tss.gs], gs	
	mov	dword [eax+tss.status], 1
	
	cmp	byte [VgaNeedsUpdate], 1
	jne	.do_later
	mov	byte [VgaNeedsUpdate], 0
	;call	OSM2LFB
.do_later:

.init_multitask:
	mov	byte [InitMultitask], 0		
	movzx	ebx, byte [CurrentProcess]
.loop:
	inc	ebx
	cmp	ebx, MAX_PROCESSES
	jne	.scan
	xor	ebx, ebx
.scan:	
	mov	eax, ebx
	mov	edi, dword [ProcessArray]
	mov	ecx, PROCESS_STRUCT_SIZE
	xor	edx, edx
	mul	ecx
	add	edi, eax
	cmp	dword [edi+tss.status], 1		;present ? (and not running)
	jne	.loop					;goto next process
	
	mov	byte [CurrentProcess], bl
	mov	eax, edi
	
	push	dword [eax+tss.eax]
	pop	dword [tmp_eax]				;keep eax for the end		
	mov	ebx, dword [eax+tss.cr3]
	mov	cr3, ebx
	push	dword [eax+tss.eflags]
	popfd
	mov	esi, dword [eax+tss.esi]
	mov	edi, dword [eax+tss.edi]
	mov	ebp, dword [eax+tss.ebp]
	mov	ebx, dword [eax+tss.ebx]
	mov	ecx, dword [eax+tss.ecx]
	mov	edx, dword [eax+tss.edx]
	mov	esp, dword [eax+tss.esp]	
	mov	ds, word [eax+tss.ds]	
	mov	es, word [eax+tss.es]
	mov	fs, word [eax+tss.fs]
	mov	gs, word [eax+tss.gs]
	mov	ss, word [eax+tss.ss]	
	mov	eax, dword [tmp_eax]
	jmp	.exit
	
.no_multi_task:		
	
	cmp	byte [SystemLoaded], 1
	jne	.exit	
	
	; check floppy motor
	;mov	eax, dword [FDC_Motor_Timer]
	;cmp	eax, 0
	;je	.exit
	
	;dec	eax
	;mov	dword [FDC_Motor_Timer], eax
	;cmp	eax, 0
	;jne	.exit
	
	;call	FDC_Motor_Off	
.exit:	
	iretd

	