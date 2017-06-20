;displays a null terminated string
;using bios functions
Print16:
	pusha
	pushf
	mov	ah, 0Eh
	mov	bx, 0	
Print16_loop:	
	cmp	byte [si], 0
	je	Print16_Ends
	mov	al, [si]
	inc	si
	int	10h
	jmp	Print16_loop
Print16_Ends:
	popf
	popa
	ret	
	
AL2Hex:
	and	ax, 0Fh			;mask low nibble
	add	al, 90h
	daa
	adc 	al, 40h
	daa
	ret


ALIGN 4

RealStart:
	mov	ax, 9000h
	mov	ss, ax
	;TODO: 
	mov	ax, 7000h
	mov	sp, ax
	
	push	cs
	pop	ds
	push	cs
	pop	es
	cld
	
	sti
	
	push	dx
	call	Enable_A20	
	pop	dx
	add	dl, 'a'
	mov	[CurrentDrive], dl	;DL has the boot drive (0=A:, etc)
	
	;get some informations that cannot be read from protected mode
	call	GetBiosInformations
	call	GetMemInfo
	call 	GetCMOSData
	call	GetVGAInfo
	
	;;Change Video Res
	;mov	ax, 4F02h
	;mov   	bx, VGA_MODE
	;;mov	bx, word [rVGAmode]
	;or	bx, 0C000h	;clear flag+use lfb flag	
	;int	10h
	;;VgaFindLFB
	;mov	ax, 4F01h
	;mov	cx, VGA_MODE
	;;mov	cx, word [rVGAmode]
	;or	cx, 0C000h	;clear flag+use lfb flag
	;mov	di, TempBuffer
	;int	10h
	;mov	si, TempBuffer
	;add	si, 28h		;DS:SI + 28h	DWORD	physical address of linear video buffer	
	;mov	edi, LFB
	;movsd
	;;movsd			; 2Ch   DWORD    Pointer to start of offscreen memory
 	;;movsw			; 30h   WORD     Offscreen memory in Kbytes

	;Going to PMode :)	
	; patch things that depend on the load adr
	xor 	ebp, ebp
	mov 	bp, cs
	shl 	ebp, 4
	mov 	[virt_to_phys], ebp

	mov 	eax, ebp
	mov 	[gdt2 + 2], ax
	mov 	[gdt3 + 2], ax	
	shr 	eax,16
	mov 	[gdt2 + 4], al
	mov 	[gdt3 + 4], al	
	mov 	[gdt2 + 7], ah
	mov 	[gdt3 + 7], ah
	
	; point tss descriptor to tss
	mov 	eax, ebp	;[ebp + ProcessArray]	; EAX=linear address of tss
	mov 	[gdt4 + 2], ax
	shr	eax, 16
	mov 	[gdt4 + 4], al
	mov 	[gdt4 + 7], ah

	add 	[gdt_ptr + 2], ebp
	;add 	[idt_ptr + 2], ebp

	; clear NT bit (so iret does normal iret, instead of task-switch),
	; set IOPL=00, and set IF=0 (disable interrupts)
	push 	dword 0
	popfd

	lgdt 	[gdt_ptr]		; enter pmode
	mov 	ebx, cr0
	inc 	bx
	mov 	cr0, ebx

	mov 	ax, SYS_DATA_SEL	; load all segment registers
	mov 	ds, ax
	mov 	ss, ax	
	mov 	fs, ax
	mov 	gs, ax
	mov 	es, ax
	jmp SYS_CODE_SEL:pmode
	
virt_to_phys:
	dd 0

; null descriptor. gdt_ptr could be put here to save a few
; bytes, but that can be confusing.
gdt:
	dw 	0
	dw 	0
	dw 	0
	dw 	0

SYS_CODE_SEL	equ	$-gdt
gdt2:
	dw	0FFFFh		; 4Gb - (0x100000*0x1000 = 4Gb)
	dw	0		; base address=0
	db	0		; base16 to base23=0x00
	db	09Ah		; 0x9=1001=P/DPL/S
	db	0CFh		; limit16 to limit19=0xF
	db	00h		; base24 to base31=0x00

SYS_DATA_SEL	equ	$-gdt
gdt3:
	dw	0FFFFh		; 4Gb - (0x100000*0x1000 = 4Gb)
	dw	0		; base address=0
	dw	9200h		; data read/write
	dw	0CFh		; granularity=4096, 386 (+5th nibble of limit)

LINEAR_SEL	equ	$-gdt
	dw	0FFFFh		; 4Gb - (0x100000*0x1000 = 4Gb)
	dw	0		; base address=0
	dw	9200h		; data read/write
	dw	0CFh		; granularity=4096, 386 (+5th nibble of limit)
TSS_SEL		equ	$-gdt
gdt4:
	dw 	103
	dw 	0		; set to stss
	db 	0
	db 	89h		; present, ring 0, 32-bit available TSS
	db 	0
	db 	0
	
gdt_end:

gdt_ptr:
	dw gdt_end - gdt - 1		; GDT limit
	dd gdt				; linear adr of GDT (set above)
	
