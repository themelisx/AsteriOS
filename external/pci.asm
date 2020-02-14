GetPCIinfo:
; AX = vendor ID
; BX = device ID
; returns: BH = PCI bus, BL = PCI device/function
	
	pushad
	
	push	dword ScanPCI
	call	Print
	
	xor	eax, eax
	xor	ebx, ebx
	xor	ecx, ecx
	xor	edx, edx
	
	mov	bh, 0		; scan bus 0 first
.scan_PCI_bus:
	mov	bl, 0		; begin from device 0, function 0
.try_PCI_device:
	mov	eax, 0
	call	read_PCI_configuration
	
	cmp	ax, 0FFFFh
	jz	.donothing
	
	cmp	ax, 0
	je	.donothing
	
	pushad
	mov	ecx, eax
	and	eax, 0FFFFh
	push	eax			;manufacturer ID
	shr	ecx, 16
	and	ecx, 0FFFFh
	push	ecx			;unit ID

	mov	eax, 8
	call	read_PCI_configuration
	
	mov	ecx, eax
	and	eax, 0FFFFh
	push	eax			;revision
	shr	ecx, 16
	and	ecx, 0FFFFh
	push	ecx			;Class code
	
	push	dword PCIInfo
	call	Print
	;call	FindCurWinNextLine
	popad
.donothing:
	inc	bl
	jnz	.try_PCI_device
	inc	bh
	cmp	bh, 16		; try 16 buses (change if needed)
	jne	.scan_PCI_bus
	
	call	PrintCRLF
	;call	FindCurWinNextLine
	
	popad
	ret

read_PCI_configuration:
; BH = PCI bus
; BL = PCI device/function
; AL = address of register
; returns: EAX = value of register
	;cli	interrupts already disabled
	mov	cl, al
	and	cl, 11b		; store offset within double word
	and	al, 11111100b	; align address to double word
	mov	dx, bx
	shl	edx, 8
	mov	dl, al
	mov	eax, 80000000h
	or	eax, edx
	mov	dx, 0CF8h
	out	dx, eax		; map double word at 0CFCh
	mov	dx, 0CFCh
	add	dl, cl		; calculate address of mapped register
	in	eax, dx
	;sti	we dont use interrupts in pmode
	ret 
