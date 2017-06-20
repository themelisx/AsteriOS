M1	equ	01863h	; almost black
M2	equ	0F7B0h	; almost white
M3	equ	00084h	; dark yellow
M4	equ	0FFE0h	; light yellow

align 4
IRQ_Mouse:
	pushad
	
	xor	eax, eax
	in	al, 60h
	
	cmp	al, 0FAh
	jne	.doit
	cmp	byte [MouseEnabled], 1
	je	.doit
	mov	byte [MouseEnabled], 1
	jmp	.exit
.doit:	
	mov	edi, dword [MouseQueue]
	mov	ecx, dword [MouseQueuePtr]
	shl	ecx, 2		;*4
	add	edi, ecx
	mov	dword [edi], eax
	
	inc	dword [MouseQueuePtr]
	
	cmp	dword [MouseQueuePtr], 3
	je	.doit2
	jmp	.exit	
.doit2:
	mov	dword [MouseQueuePtr], 0
	
	mov	esi, dword [MouseQueue]
	mov	eax, dword [esi]
	and	eax, 0Fh
	cmp	eax, 8			;mouse btn up
	jne	.other
	cmp	dword [mouse_btn], 9
	je	.left_btn
	cmp	dword [mouse_btn], 0Ah
	je	.right_btn
	cmp	dword [mouse_btn], 0Ch
	je	.middle_btn
	jmp	.other
.left_btn:
	push	dword MOUSE_LEFT_CLICK
	push	dword [mouse_line]
	push	dword [mouse_pos]
	call	AddMouseEvent
	jmp	.other
.right_btn:
	push	dword MOUSE_RIGHT_CLICK	
	push	dword [mouse_line]
	push	dword [mouse_pos]
	call	AddMouseEvent
	jmp	.other
.middle_btn:
	push	dword MOUSE_MIDDLE_CLICK	
	push	dword [mouse_line]
	push	dword [mouse_pos]
	call	AddMouseEvent
	;jmp	.other
.other:
	mov	dword [mouse_btn], eax
	
	;check X
	mov	eax, dword [esi]
	test	eax, 10h		; test plus/minus flag
	mov	eax, dword [esi+4]
	jz	.mouse_x_add	
	or	eax, 0FFFFFF00h		;extend sign of eax
	neg	eax	
	sub	dword [mouse_pos], eax
	jns	.x_ok
	mov	dword [mouse_pos], 0
	jmp	.x_ok
.mouse_x_add:
	add	dword [mouse_pos], eax
	mov	eax, dword [VGA_Width]
	cmp	dword [mouse_pos], eax
	jng	.x_ok
	mov	dword [mouse_pos], eax
.x_ok:
	
	;check Y
	mov	eax, dword [esi]
	test	eax, 20h		; test plus/minus flag
	mov	eax, dword [esi+8]
	jnz	.mouse_y_add		;y reverse
	
	sub	dword [mouse_line], eax
	jns	.y_ok
	mov	dword [mouse_line], 0
	jmp	.y_ok
.mouse_y_add:
	or	eax, 0FFFFFF00h		;extend sign of eax
	neg	eax
	add	dword [mouse_line], eax
	mov	eax, dword [VGA_Height]
	cmp	dword [mouse_line], eax
	jng	.y_ok
	mov	dword [mouse_line], eax
.y_ok:

	mov	byte [VgaNeedsUpdate], 1
	;this will draw cursor at next irq 0
	
.exit:
	mov	al, 20h
	out	20h, al
	out	0A0h, al	
	popad	
	iretd

;inputs:
;event id
;line (in pixels)
;pos
AddMouseEvent:
	push	ebp
	mov	ebp, esp
	add	ebp, 8
	
	;debug
	push	dword [ebp]
	push	dword [ebp+4]
	push	dword [ebp+8]
	push	dword sMouseEvent
	call	Print
	
	pop	ebp
	ret	3*4

Init_Mouse:
	cli
	
	push	dword 1024*3		;3 bytes for every mouse event
	call	MemAlloc
	mov	dword [MouseQueue], eax
	mov	dword [MouseQueuePtr], 0
	
	mov	byte [MouseEnabled], 0
	mov	byte [MousePresent], 0
	
	push	dword 2Ch
	push	dword IRQ_Mouse
	call	HookInterrupt	
	
	call	Empty_8042
	
	;Send Enable PS2 Mouse command 
	mov	eax, 0A8h	
	out	64h, al
	call	Empty_8042		; eat up 0xFAh=ACK?

	; Send Read "command byte" command
	mov	eax, 20h	
	out	64h, al
	call	Wait_ok_read_8042

	; get command byte and
	; mask it to enable 8042 to
	; generate IRQ1 and IRQ12
	in	al, 60h
	or	al, 3
	push	eax			;save command for latter
	call	Wait_ok_write_8042

	; Send Write "command byte" command
	mov	eax, 60h		
	out	64h, al
	call	Wait_ok_write_8042

	; send the new byte inside
	pop	eax
	out	60h, al

	;Write "next byte is for mouse" command
	;call	Wait_ok_write_8042
	;mov	eax, 0D4h		
	;out	64h, al

	; RESET command
	;call	Wait_ok_write_8042
	;mov	al, 0FFh
	;out	60h, al
	; read FA=Ack
	;call	KBD_8042_Data_Read
	; read AA 
	;call	KBD_8042_Data_Read
	; read ID
	;call	KBD_8042_Data_Read
	
	;Write "next byte is for mouse" command
	call	Wait_ok_write_8042
	mov	eax, 0D4h		
	out	64h, al	
	
	; Mouse Big-Bang! - send the 
	; "enable mouse data reporting" command
	call	Wait_ok_write_8042
	mov	al, 0F4h
	out	60h, al
	
	call	Wait_ok_write_8042

	; Wait "FA=Ack" from mouse
	mov	ecx, 1FFFFh

.loop_wait_ack:
	call	Delay32
	dec	ecx
	jz	.NoMousePresent

	; have smthing for me?
	in	al, 64h
	and	al, 1		
	jz	.loop_wait_ack	

	; is it magic?
	in	al, 60h
	cmp	al, 0FAh
	jnz	.loop_wait_ack
	
	; mouse to middle of screen
	mov	eax, dword [VGA_Width]
	shr	eax,1
	mov	dword [mouse_pos], eax
	
	mov	eax, dword [VGA_Height]
	shr	eax,1
	mov	dword [mouse_line], eax
	
	;name
	;Driver address
	;DMA
	;Channel
	;IRQ
	;Type
	;Flags
	push	dword PS2Mouse
	push	dword IRQ_Mouse
	push	dword 60h	;DMA
	push	dword 0		;channel unused
	push	dword 12	;irq 6
	push	dword DEVICE_MOUSE
	push	dword 1		;bit 0 = enable
	call	RegisterDevice
	
	mov	byte [MousePresent], 1
	mov	byte [VgaNeedsUpdate], 1
	
.NoMousePresent:
	
	sti
	ret

; Wait until we can write
Wait_ok_write_8042:
	push	ecx
	mov	ecx, 01FFFh		;timeout value	
.loop:
	in	al, 64h
	and	al, 10b			;bit 2=output buffer full
	jz	.finish
	dec	ecx	
	jnz	.loop	
.finish:
	pop	ecx
	ret
	
Wait_ok_read_8042:
	push	ecx
	mov	ecx, 01FFFh		;timeout value	
.loop:
	in	al, 64h
	and	al, 1b			;bit 2=output buffer full
	jz	.finish
	dec	ecx	
	jnz	.loop	
.finish:	
	pop	ecx
	ret

Empty_8042:
	nop
.loop_wait:
	call	Delay32
	in	al, 64h		; 8042 status port
	and	al, 1		; something to read from keyboard?
	jz	.no_output_32
	call	Delay32
	in	al, 60h		; yes, then read it
	jmp	.loop_wait	; and of course we ignore it :P
.no_output_32:
	and	al, 10b		; smthing in write buffer?
	jnz	.loop_wait	; yes - loop
	ret
	
KBD_8042_Data_Read:
	push	ecx
	push	edx

	; wait until we have something in buffer
	mov	dx, 64h
.loop_wait1:	
	in	al, dx
	and	al, 10b
	jz	.loop_wait1
	; wait a little
	mov	ecx, 1Fh
.loop_wait2:
	nop
	dec	ecx
	jnz	.loop_wait2
	; then read it
	mov	dx, 60h
	xor	eax, eax		
	in	al, dx
	; return the read value
	
	pop	edx
	pop	ecx
	ret
	
DrawCursor:
	pushad
	
	push	dword [mouse_line]
	push	dword [mouse_pos]
	call	XY2LFB	
	mov	edi, eax
	mov	esi, dword MyCursor
	mov	edx, dword [VGA_Width]
	shl	edx, 1
	
	mov	ecx, 32
.loop:
	push	ecx	
	push	edi
	mov	ecx, 16
.loop2:
	lodsw
	cmp	ax, 0
	je	.next1
	stosw
	jmp	.next2
.next1:
	add	edi, 2
.next2:
	dec	ecx
	jnz	.loop2
	
	pop	edi
	pop	ecx
	add	edi, edx
	dec	ecx
	jnz	.loop
	
	popad
	ret
	
MyCursor	dw	M1,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00
		dw	M3,M1,00,00,00,00,00,00,00,00,00,00,00,00,00,00
		dw	M3,M3,M1,00,00,00,00,00,00,00,00,00,00,00,00,00
		dw	M3,M3,M3,M1,00,00,00,00,00,00,00,00,00,00,00,00
		dw	M3,M4,M3,M3,M1,00,00,00,00,00,00,00,00,00,00,00
		dw	M3,M4,M3,M3,M3,M1,00,00,00,00,00,00,00,00,00,00
		dw	M3,M4,M4,M3,M3,M3,M1,00,00,00,00,00,00,00,00,00
		dw	M3,M4,M4,M3,M3,M3,M3,M1,00,00,00,00,00,00,00,00
		dw	M3,M4,M4,M4,M3,M3,M3,M3,M1,00,00,00,00,00,00,00
		dw	M3,M4,M4,M4,M3,M3,M3,M3,M3,M1,00,00,00,00,00,00
		dw	M3,M4,M4,M3,M1,M1,M1,M1,M1,M1,M1,00,00,00,00,00
		dw	M3,M4,M3,M1,M4,M3,M1,00,00,00,00,00,00,00,00,00
		dw	M3,M3,M1,00,M3,M4,M3,M1,00,00,00,00,00,00,00,00
		dw	M3,M1,00,00,M3,M4,M3,M1,00,00,00,00,00,00,00,00
		dw	M1,00,00,00,00,M3,M4,M3,M1,00,00,00,00,00,00,00
		dw	00,00,00,00,00,M3,M4,M3,M1,00,00,00,00,00,00,00
		dw	00,00,00,00,00,00,M3,M4,M3,M1,00,00,00,00,00,00
		dw	00,00,00,00,00,00,M3,M3,M3,M1,00,00,00,00,00,00
		dw	00,00,00,00,00,00,00,00,M1,M1,00,00,00,00,00,00
		dw	00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00
		dw	00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00
		dw	00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00
		dw	00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00
		dw	00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00
		dw	00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00
		dw	00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00
		dw	00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00
		dw	00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00
		dw	00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00
		dw	00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00
		dw	00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00
		dw	00,00,00,00,00,00,00,00,00,00,00,00,00,00,00,00
		