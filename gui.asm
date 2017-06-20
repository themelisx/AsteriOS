InitDesktop:
	pushad
	;
	mov	dword [VGA_Width], VGA_WIDTH
	mov	dword [VGA_Height], VGA_HEIGHT
	;
	mov	eax, dword [VGA_Width]
	mov	ecx, dword [VGA_Height]
	xor	edx, edx
	mul	ecx
	shl	eax, 1			;x*y*2 (16 bpp)
	mov	dword [OSM_Size], eax
	mov	dword [OSM], 100000h
	
	mov	eax, COLOR_BLACK		;COLOR_GRAY
	mov	edi, dword [OSM]
	mov	ecx, dword [OSM_Size]
	shr	ecx, 1
	rep	stosw	
	
	mov	dword [Cursor_Line], 0
	mov	dword [Cursor_Pos], 0
	
	call	OSM2LFB		
	
	popad
	ret
	
DrawDesktop:
	pushad
	
	;mov	eax, dword [VGA_Width]
	;mov	ecx, dword [VGA_Height]
	;xor	edx, edx
	;mul	ecx
	;shl	eax, 1			;x*y*2 (16 bpp)
	mov	dword [OSM_Size], OSM_MAX_SIZE
	mov	dword [OSM], OSM_PTR
	
	;16 bpp mode
	mov	eax, COLOR_GRAY
	mov	edi, dword [OSM]
	mov	ecx, dword [OSM_Size]
	shr	ecx, 1
	rep	stosw	
	
	mov	byte [GUILoaded], 1
	mov	byte [VgaNeedsUpdate], 1
	call	OSM2LFB		
	
	;draw log window
	push	dword OS_Title	
	push	dword 150	;line
	push	dword 20	;position
	push	dword 400	;height
	push	dword 760	;width
	push	dword COLOR_BLUE		;color = blue
	call	DrawWindow
	
	;TODO:Fix this
	mov	dword [Cursor_Line], 150+23
	mov	dword [Cursor_Pos], 20+6	
	
	popad
	ret
	
;no input
;returns in eax the window position 
;16 high bit has the "top" and 16 low has the "left"	
GetActiveWindowXY:
	;push
	
	;TODO:get active window XY
	
	cmp	byte [GUILoaded], 1
	je	.ok
	
	mov	eax, 0
	jmp	.exit
	
.ok:
	mov	eax, 00960014h	
.exit:	
	;pop
	
	ret

;no input
;returns in eax the active window size
;16 high bits has the height, 16 low bits has the width
GetActiveWindowSize:
	;push
	
	;TODO:get active window size
	cmp	byte [GUILoaded], 1
	je	.ok
	
	mov	eax, dword [VGA_Width]
	and	eax, 0FFFFh
	mov	ecx, dword [VGA_Height]
	and	ecx, 0FFFFh
	rol	ecx, 16
	add	eax, ecx
	jmp	.exit	
.ok:
	mov 	eax, 019002F8h
.exit:		
	;pop
	ret

;Line
;Position
;Filename
DrawGifF:
	push	ebp
	mov	ebp, esp
	add	ebp, 8	
	pushad
	
	push	dword [ebp]
	call	OpenFile
	cmp	eax, -1		;file not found
	jne	.found
	
	;file not found
	;draw a simple rect
	push	dword [ebp+8]	;line
	push	dword [ebp+4]	;position
	push	dword 16	;height
	push	dword 16	;width
	push	dword COLOR_BLACK
	call	DrawRect	
	mov	byte [VgaNeedsUpdate], 1		
	jmp	.exit
	
.found:
	mov	ebx, eax
	
	push	ebx
	call	GetFileSize
	mov	ecx, eax	;file size
	
	push	ecx
	call	MemAlloc
	mov	esi, eax
	
	push	esi
	
	push	ebx		;handle
	push	esi		;buffer
	push	ecx		;size
	call	LoadFile
	
	push	dword [ebp]
	call	CloseFile
	
	pop	esi	
	
	push	dword [ebp+8]	;line
	push	dword [ebp+4]	;pos
	push	esi
	call	DrawGif
	
	push	esi
	call	MemFree
	
.exit:
	popad
	pop	ebp
	ret	3*4
	
DrawGif:
	push	ebp
	mov	ebp, esp
	add	ebp, 8	
	pushad
	
	nop
	
.exit:
	popad
	pop	ebp
	ret	3*4

;Line
;Position
;Filename
DrawBmpF:
	push	ebp
	mov	ebp, esp
	add	ebp, 8	
	pushad
	
	push	dword [ebp]
	call	OpenFile
	cmp	eax, -1		;file not found
	jne	.found
	
	;file not found
	;draw a simple rect
	push	dword [ebp+8]	;line
	push	dword [ebp+4]	;position
	push	dword 16	;height
	push	dword 16	;width
	push	dword COLOR_BLACK
	call	DrawRect	
	mov	byte [VgaNeedsUpdate], 1		
	jmp	.exit
	
.found:
	mov	ebx, eax
	
	push	ebx
	call	GetFileSize
	mov	ecx, eax	;file size
	
	push	ecx
	call	MemAlloc
	mov	esi, eax
	
	push	esi
	
	push	ebx		;handle
	push	esi		;buffer
	push	ecx		;size
	call	LoadFile
	
	push	dword [ebp]
	call	CloseFile
	
	pop	esi	
	
	push	dword [ebp+8]	;line
	push	dword [ebp+4]	;pos
	push	esi
	call	DrawBmp
	
	push	esi
	call	MemFree
	
.exit:
	popad
	pop	ebp
	ret	3*4
	

;Line
;Position
;Address of loaded image	
DrawBmp:
	push	ebp
	mov	ebp, esp
	add	ebp, 8	
	pushad	
	
	mov	esi, dword [ebp]	;address of image
	xor	edi, edi		;to check later if not = 0
	
	xor	eax, eax	
	mov	ax, word [esi+28]	;image type (1,4,8,16,24)	
	
	cmp	ax, 16
	jne	.next
	jmp	.DrawNow
.next:
	cmp	ax, 24
	je	.Convert
	
	;unsupported image
	;draw a simple rect
	
	mov	eax, dword [ebp+8]	;line
	mov	ebx, dword [ebp+4]	;position
	
	cmp	eax, -1
	jne	.ok1
	mov	eax, dword [VGA_Height]
	sub	eax, dword [esi+22]	;height
	shr	eax, 1			;/2
.ok1:
	cmp	ebx, -1
	jne	.ok2
	mov	ebx, dword [VGA_Width]
	sub	ebx, dword [esi+18]	;width
	shr	ebx, 1			;/2	
.ok2:	

	push	eax
	push	ebx
	push	dword [esi+22]	;height
	push	dword [esi+18]	;width
	push	dword COLOR_BLACK
	call	DrawRect
	jmp	.finish
	
.Convert:	
	push	esi
		
	mov	ecx, dword [esi+22]	;height
	mov	eax, dword [esi+18]	;width
	xor	edx, edx
	mul	ecx
	mov	ecx, eax		;size of image
	
	push	ecx
	xor	edx, edx
	mov	ecx, 3			;3 bytes per pixel
	mul	ecx	
	push	eax
	call	MemAlloc
	mov	edi, eax
	pop	ecx
	
	push	edi			;save for later
	
	mov	ecx, dword [esi+22]	;height
	mov	ebx, dword [esi+18]	;width
	
	mov	eax, dword [esi+18]	;width
	lea	eax, [eax+eax*2]	;eax*3
	add	eax, 3
	and	eax, 0FFFFFFFCh
	mov	edx, eax
	
	mov	eax, dword [esi+10]	;start of image	
	add	esi, eax	
.LoopHeight:	
	push	esi
	push	ecx	
	mov	ecx, ebx		;width	
.Loopwidth:
	mov	eax, dword [esi]	
	call	Convert24bppTo16bpp	
	mov	[edi], ax
	; next pixel
	add	esi, 3
	add	edi, 2
	loop	.Loopwidth
	
	pop	ecx
	pop	esi
	add	esi, edx		;pitch
	loop	.LoopHeight
	
	pop	edi			;address of ready bmp
	pop	esi	
	
.DrawNow:	
	mov 	eax, dword [ebp+8]	;line	
	cmp	eax, -1
	jne	.ok_line
	
	mov	eax, dword [VGA_Height]
	sub	eax, dword [esi+22]	;height
	shr	eax, 1			;/2
.ok_line:	
	mov	ecx, dword [esi+22]	;height
	add	eax, ecx		;line+height	
	mov	edx, dword [esi+18]	;width
	
	mov	ebx, dword [ebp+4]	;position
	cmp	ebx, -1
	jne	.ok_pos
	mov	ebx, dword [VGA_Width]
	sub	ebx, dword [esi+18]	;width
	shr	ebx, 1			;/2	
.ok_pos:	
	
	push	edi
	
	cmp	edi, 0
	jne	.NewInput
	
	push	eax			;eax keeps line+height
	mov	eax, dword [esi+10]	;start of image
	add	esi, eax
	pop	eax
	
	jmp	.doit
.NewInput:
	mov	esi, edi		;converted image	
	
.doit:		
	push	eax		;line
	push	ebx		;position
	call	XY2OSM
	mov	edi, eax	
	
.loop:
	push	ecx
	push	edi
	mov	ecx, edx		;width
	inc 	ecx
	
.loop_line:
	rep	movsw

	pop	edi
	pop	ecx
	sub	edi, dword [VGA_Width]
	sub	edi, dword [VGA_Width]	
	loop	.loop
	
	pop	edi
	cmp	edi, 0
	je	.finish
	
	push	edi
	call	MemFree
	
.finish:
	mov	byte [VgaNeedsUpdate], 1
		
	popad
	pop	ebp
	ret	3*4
	
	
;line
;position
;height
;width
;color
DrawMainWindow:
	push	ebp
	mov	ebp, esp
	add	ebp, 8	
	pushad

	push	dword OS_Title	
	push	dword [ebp+16]	;line
	push	dword [ebp+12]	;position
	push	dword [ebp+8]	;height
	push	dword [ebp+4]	;width
	push	dword [ebp]
	call	DrawWindow
	
	popad
	pop	ebp
	ret	5*4
	
;line
;position
;height
;width
;color
DrawRect:
	push	ebp
	mov	ebp, esp
	add	ebp, 8	
	pushad
	
	push	dword [ebp+16]	;line
	push	dword [ebp+12]	;position
	call	XY2OSM
	mov	edi, eax
	
	mov	eax, dword [ebp]	;color
	mov	ecx, dword [ebp+8]	;height
.loop:	
	push	ecx
	push	edi
	mov	ecx, dword [ebp+4]	;width
	rep	stosw
	pop	edi
	pop	ecx
	add	edi, dword [VGA_Width]
	add	edi, dword [VGA_Width]
	dec	ecx
	jnz	.loop
	
	mov	byte [VgaNeedsUpdate], 1	
	
	popad
	pop	ebp
	ret	5*4
	

;title
;line
;position
;height
;width
;color
DrawWindow:
	push	ebp
	mov	ebp, esp
	add	ebp, 8	
	pushad
	
	;background rect
	push	dword [ebp+16]	;line
	push	dword [ebp+12]	;position
	push	dword [ebp+8]	;height
	push	dword [ebp+4]	;width
	push	dword COLOR_WHITE
	call	DrawRect
	
	
	;up line
	mov	edx, dword [ebp+16]	;line
	mov	ecx, 3+3+FONT_HEIGHT
.loop1:
	push	edx
	push	dword [ebp+12]		;position
	push	dword [ebp+4]		;width
	push	dword [ebp]		;color
	call	DrawHLine
	inc	edx
	dec	ecx
	jnz	.loop1
	
	mov	eax, dword [ebp+16]	;line
	add	eax, 3
	push	eax
	mov	eax, dword [ebp+12]	;position
	add	eax, 3+8		;FONT_WIDTH + left line
	push	eax
	push	dword [ebp+20]		;text
	push	dword 0FFFFh		;white	
	call	DrawTextXY
	
	;down line
	mov	edx, dword [ebp+16]	;line
	add	edx, dword [ebp+8]	;height
	sub	edx, 3			;3 pixels for up/down lines
	mov	ecx, 3
.loop2:
	push	edx
	push	dword [ebp+12]		;position
	push	dword [ebp+4]		;width
	push	dword [ebp]		;color
	call	DrawHLine
	inc	edx
	dec	ecx
	jnz	.loop2
	
	;left line
	mov	edx, dword [ebp+12]	;position
	mov	ecx, 3
.loop3:
	push	dword [ebp+16]		;line
	push	edx			;position
	push	dword [ebp+8]		;height
	push	dword [ebp]		;color
	call	DrawVLine
	inc	edx
	dec	ecx
	jnz	.loop3
	
	;right line
	mov	edx, dword [ebp+12]	;position
	add	edx, dword [ebp+4]	;width
	sub	edx, 3
	mov	ecx, 3
.loop4:
	push	dword [ebp+16]		;line
	push	edx			;position
	push	dword [ebp+8]		;height
	push	dword [ebp]		;color
	call	DrawVLine
	inc	edx
	dec	ecx
	jnz	.loop4
	
	mov	byte [VgaNeedsUpdate], 1
	
	popad
	pop	ebp
	ret	6*4
	
WindowScrollUp:
	mov	byte [ScrollingWindow], 1
	pushad
	
	call	GetActiveWindowXY
	mov	ebx, eax	;save value
	and	ebx, 0FFFFh	;keep "left"
	shl	ebx, 1		;*2
	and	eax, 0FFFF0000h
	ror	eax, 16
	
	mov	ecx, dword [VGA_Width]
	shl	ecx, 1
	xor	edx, edx
	mul	ecx
	add	eax, ebx	;add position
	
	mov	edi, eax
	add	edi, dword [OSM]
	mov	esi, edi
	
	mov	eax, dword [VGA_Width]
	shl	eax, 1
	mov	ecx, FONT_HEIGHT
	xor	edx, edx
	mul	ecx
	add	esi, eax	
	
	call	GetActiveWindowSize
	mov	ebx, eax
	and	ebx, 0FFFFh	;keep width	
	and	eax, 0FFFF0000h ;keep height
	ror	eax, 16
	;sub	eax, (FONT_HEIGHT * 2)
	mov	ecx, eax
	
	mov 	edx, dword [VGA_Width]
	shl	edx, 1
	
.ScrollUpNextLine:	
	push	ecx
	
	mov	ecx, ebx
	push	esi
	push	edi
	rep	movsw
	pop	edi
	pop	esi
	add	esi, edx
	add	edi, edx
	
	pop	ecx
	dec	ecx
	
	jnz	.ScrollUpNextLine
	
	add	edi, edx		;one line
	
	mov	ecx, FONT_HEIGHT
.ScrollUpNextLine2:	
	push	ecx
	mov	ecx, ebx		;window width
	push	edi
	mov	eax, dword 0;	COLOR_WHITE		;gray
	rep	stosw	
	pop	edi
	add	edi, edx		
	pop	ecx
	dec	ecx
	jnz	.ScrollUpNextLine2
	
	;call	OSM2LFB

	popad
	mov	byte [ScrollingWindow], 0
	mov	byte [VgaNeedsUpdate], 1
	
	
	ret

;text
;;;;;;;color
PrintSimple:
	push	ebp
	mov	ebp, esp
	add	ebp, 8
	pushad

	mov	ebx, dword [ebp]		;text
	mov	edx, dword [Cursor_Pos]		;position
.next_char:
	push	edx			;save position
.no_char:
	;check if i will print out of window
	push	ecx
	call	GetActiveWindowSize
	and	eax, 0FFFFh 	;keep width
	mov	ecx, eax
	call	GetActiveWindowXY
	and	eax, 0FFFFh	;keep "left"
	add	eax, ecx
	sub	eax, 2*6	;active space is 6 pixels inside
	pop	ecx
	
	cmp	edx, eax
	jl	.ok_width
	
	;make word wrap
	jmp	.CRLF_Now
.ok_width:

	push	dword [Cursor_Line]		;line
	push	edx
	call	XY2OSM	
	
	mov	edi, eax
	mov	esi, dword MyFont
	
	movzx	eax, byte [ebx]
	inc	ebx	
	cmp	al, 0
	jne	.ok1
	jmp	.exit
.ok1:
	cmp	al, 10
	je	.no_char	
	cmp	al, 13
	jne	.simple_char

.CRLF_Now:
	call	PrintCRLF
	
	pop	edx
	mov	edx, dword [Cursor_Pos]		;position
	jmp	.next_char

.simple_char:
	add	esi, 256*12
	add	esi, eax
	mov	ecx, FONT_HEIGHT	
.loop2:
	push	ecx
	push	edi
	push	esi
	
	lodsb
	mov	ecx, FONT_WIDTH	
	mov	edx, 1b
.loop1:
	push	eax	
	test	eax, edx
	jz	.next1
	mov	eax, 0			;black
	jmp	.next2
.next1:
	mov	eax, COLOR_WHITE	
.next2:
	stosw
	pop	eax
	rol	edx, 1
	dec	ecx
	jnz	.loop1
	
	pop	esi
	pop	edi
	
	sub	esi, 256	;*8
	mov	eax, dword [VGA_Width]
	shl	eax, 1
	add	edi, eax
	
	pop	ecx
	dec	ecx
	jnz	.loop2
	
	pop	edx
	
	add	edx, FONT_WIDTH ;+ 1
	add 	dword [Cursor_Pos], FONT_WIDTH	;+1
	jmp	.next_char
	
.exit:	
	pop	edx
	
	popad
	pop	ebp
	ret	4


;line (in pixels)
;position (in pixels)
;text
;color
DrawTextXY:
	push	ebp
	mov	ebp, esp
	add	ebp, 8	
	pushad

	mov	ebx, dword [ebp+4]		;text
	mov	edx, dword [ebp+8]		;position
.next_char:
	push	edx			;save position
.no_char:
	push	dword [ebp+12]		;line
	push	edx
	call	XY2OSM
	mov	edi, eax
	mov	esi, dword MyFont
	
	movzx	eax, byte [ebx]
	inc	ebx
	cmp	al, 0
	je	.exit
	cmp	al, 10
	je	.no_char
	cmp	al, 13
	je	.no_char
.simple_char:
	add	esi, 256*12
	add	esi, eax
	mov	ecx, FONT_HEIGHT	
.loop2:
	push	ecx
	push	edi
	push	esi
	
	lodsb
	mov	ecx, FONT_WIDTH	
	mov	edx, 1b
.loop1:
	push	eax	
	test	eax, edx
	jz	.next1
	mov	eax, COLOR_BLUE
	jmp	.next2
.next1:
	mov	eax, dword [ebp]	
.next2:
	stosw
	pop	eax
	rol	edx, 1
	dec	ecx
	jnz	.loop1
	
	pop	esi
	pop	edi
	
	sub	esi, 256	;*8
	mov	eax, dword [VGA_Width]
	shl	eax, 1
	add	edi, eax
	
	pop	ecx
	dec	ecx
	jnz	.loop2
	
	pop	edx
	
	add	edx, FONT_WIDTH ;+ 1
	add 	dword [Cursor_Pos], FONT_WIDTH	;+1
	jmp	.next_char
	
.exit:	
	pop	edx
	
	;call	OSM2LFB
	
	popad
	pop	ebp
	ret	4*4
	

;line
;position
;width
;color
DrawVLine:
	push	ebp
	mov	ebp, esp
	add	ebp, 8	
	pushad
	
	push	dword [ebp+12]		;line
	push	dword [ebp+8]		;position
	call	XY2OSM
	mov	edi, eax	
	mov	ecx, dword [ebp+4]	;size
	mov	eax, dword [ebp]	;color
	mov	edx, dword [VGA_Width]
	shl	edx, 1
.loop:
	mov	word [edi], ax
	add	edi, edx
	dec	ecx
	jnz	.loop	
	
	;call	OSM2LFB
	
	popad
	pop	ebp
	ret	4*4

;line
;position
;hwidth
;color
DrawHLine:
	push	ebp
	mov	ebp, esp
	add	ebp, 8	
	pushad
	
	push	dword [ebp+12]		;line
	push	dword [ebp+8]		;position
	call	XY2OSM
	mov	edi, eax	
	mov	ecx, dword [ebp+4]	;size
	mov	eax, dword [ebp]	;color
	rep	stosw
	
	;call	OSM2LFB
	
	popad
	pop	ebp
	ret	4*4
	
;line
;position
XY2OSM:
	push	ebp
	mov	ebp, esp
	add	ebp, 8
	
	push	ecx
	push	edx
	
	mov	eax, dword [ebp+4]
	mov	ecx, dword [VGA_Width]
	xor	edx, edx
	mul	ecx
	add	eax, dword [ebp]
	shl	eax, 1
	add	eax, dword [OSM]
	
	pop	edx
	pop	ecx
	pop	ebp
	ret	2*4
	
XY2LFB:
	push	ebp
	mov	ebp, esp
	add	ebp, 8
	
	push	ecx
	push	edx
	
	mov	eax, dword [ebp+4]
	mov	ecx, dword [VGA_Width]
	xor	edx, edx
	mul	ecx
	add	eax, dword [ebp]
	shl	eax, 1
	add	eax, dword [LFB]
	
	pop	edx
	pop	ecx
	pop	ebp
	ret	2*4
	
OSM2LFB:
	pushad
	mov	esi, dword [OSM]
	mov	edi, dword [LFB]
	mov	ecx, dword [OSM_Size]
	shr	ecx, 2			;/4
	rep	movsd

	cmp	byte [MousePresent], 0
	je	.exit
	call	DrawCursor
.exit:
	popad
	ret
	
;input: ax = color
;output: ax = new color
Convert15bppTo16bpp:
	push	edx
	and	eax, 0FFFFh		;keep ax only, color is 16 bits
	mov	edx, eax
	and 	eax, 1111011111000000b
	shr	eax, 1
	and	edx, 01Fh
	or	eax, edx
	pop	edx
	ret
	
Convert24bppTo16bpp:
	pushfd
	push	ebx
	push	edx	
	xor	edx, edx			;clear convert destination
	; blue -> 8 to 5 bits
	mov	ebx, eax
	and	ebx, 0ffh
	shr	ebx, 3
	or	edx, ebx	
	; green -> 8 to 6 bits
	mov	ebx, eax
	shr	ebx, 8
	and	ebx, 00ffh
	shr	ebx, 2
	shl	ebx, 5
	or	edx, ebx	
	; red -> 8 to 5 bits
	mov	ebx, eax
	shr	ebx, 16
	and	ebx, 00ffh
	shr	ebx, 3
	shl	ebx, 11
	or	edx, ebx
	mov	eax, edx
	pop	edx
	pop	ebx
	popfd
	ret

;%include 'logo_sm.asm'
;%include 'os_menu1.asm'