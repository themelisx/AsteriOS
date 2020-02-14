;Window manager

Init_WinManager:
	pushad
	
	;allocate WindowsArray
	push	dword MAX_WINDOWS * WINDOWS_ARRAY_STRUCT_SIZE
	call	MemAlloc
	mov	dword [WindowsArray], eax
	
	;clean up windows array
	mov	edi, eax
	mov	ecx, MAX_WINDOWS * WINDOWS_ARRAY_STRUCT_SIZE
	shr	ecx, 2				;/4
	mov	eax, 0
	rep	stosd	
	
	popad	
	ret

;Creates a virtual object
;input:
;1st: Position TOP
;2nd: Position LEFT
;3rd: Size HEIGHT
;4th: Size WIDTH
;5th: Title (asciiz)
CreateWindow:
	push	ebp
	mov	ebp, esp
	add	ebp, 8	
	
	pushad

	mov	esi, dword [WindowsArray]
.search:
	cmp	byte [esi], 0			;empty entry ?
	je	.empty_entry
	add	esi, WINDOWS_ARRAY_STRUCT_SIZE
	jmp	.search
.empty_entry:
	mov	eax, dword [ebp+16]
	mov	word [esi+sWindow.top], ax
	
	mov	eax, dword [ebp+12]
	mov	word [esi+sWindow.left], ax
	
	mov	eax, dword [ebp+8]
	mov	word [esi+sWindow.height], ax
	
	mov	eax, dword [ebp+4]
	mov	word [esi+sWindow.width], ax	
	
	mov	edi, esi
	add	edi, sWindow.title
	mov	esi, dword [ebp]
.fill_title:
	lodsb
	;TODO:check if title is bigger than name space size (in struct)
	cmp	al, 0
	je	.title_ok
	stosb
	jmp	.fill_title	
.title_ok:
	stosb
	
	popad
	
	;TODO:return in eax the window ID
	
	pop	ebp
	ret	5*4
	
;returns the address of the window struct of the given window ID
;input: window ID
;output: address of struct
IDtoAddr:
	push	ebp
	mov	ebp, esp
	add	ebp, 8	
	
	push	ecx
	push	edx
	
	mov	eax, dword [ebp]
	mov	ecx, WINDOWS_ARRAY_STRUCT_SIZE
	xor	edx, edx
	mul	ecx	
	
	mov	edx, dword [WindowsArray]
	add	eax, edx
	
	pop	edx
	pop	ecx
	
	pop	ebp
	ret	4
	
;input: Window ID
;output: in EAX returned a pointer to a struct "sWindow" of window informations
;if window ID is invalid (not present) returns 0FFFFFFFFh
GetWindowInfo:
	push	ebp
	mov	ebp, esp
	add	ebp, 8	
	
	push	eax
	push	esi
	
	push	dword [ebp]
	call	IDtoAddr
	
	mov	esi, eax	
	mov	al, byte [esi+sWindow.flags]
	
	test	al, 1			;window present ?
	jz	.error
	
	mov	eax, esi
	jmp	.ok	
.error:
	mov	eax, 0FFFFFFFFh
.ok:	
	pop	esi
	pop	eax
	
	pop	ebp
	ret	4
	
;Deletes the window
DestroyWindow:
	ret
	
;input: ID of window
;output: nothing
HideWindow:
	push	ebp
	mov	ebp, esp
	add	ebp, 8	
	
	push	eax
	push	esi
	
	push	dword [ebp]
	call	IDtoAddr	
	mov	esi, eax
	
	mov	al, byte [esi+sWindow.flags]	
	test	al, 1			;window present ?
	jz	.error
	
	and	al, 11111101b		;clear visible bit
	or	al, 100b		;set dirty bit
	mov	byte [esi+sWindow.flags], al	
	
.error:
	pop	esi
	pop	eax	
	pop	ebp
	ret	4
	
;input: ID of window
;output: nothing
ShowWindow:
	push	ebp
	mov	ebp, esp
	add	ebp, 8	
	
	push	eax
	push	esi
	
	push	dword [ebp]
	call	IDtoAddr	
	mov	esi, eax
	
	mov	al, byte [esi+sWindow.flags]	
	test	al, 1			;window present ?
	jz	.error
	
	or	al, 110b		;set visible & dirty bits
	mov	byte [esi+sWindow.flags], al	
	
.error:
	pop	esi
	pop	eax
	
	pop	ebp
	ret	4
	
;moves the window to given XY
;input:
;1st: ID of window
;2nd: new TOP
;3rd: new LEFT
MoveWindow:
	push	ebp
	mov	ebp, esp
	add	ebp, 8	
	
	push	eax
	push	esi
	
	push	dword [ebp]
	call	IDtoAddr	
	mov	esi, eax
	
	mov	al, byte [esi+sWindow.flags]	
	test	al, 1			;window present ?
	jz	.error	
	
	mov	eax, dword [ebp+4]
	mov	word [esi+sWindow.top], ax
	
	mov	eax, dword [ebp]
	mov	word [esi+sWindow.left], ax	
	
	or	al, 100b		;set dirty bit
	mov	byte [esi+sWindow.flags], al
	
.error:
	pop	esi
	pop	eax
	
	pop	ebp
	ret	3*4
	
;resizes the window to given width/height
;input:
;1st: ID of window
;2nd: new HEIGTH
;3rd: new WIDTH
ResizeWindow:
	push	ebp
	mov	ebp, esp
	add	ebp, 8	
	
	push	eax
	push	esi
	
	push	dword [ebp]
	call	IDtoAddr	
	mov	esi, eax
	
	mov	al, byte [esi+sWindow.flags]	
	test	al, 1			;window present ?
	jz	.error	
	
	mov	eax, dword [ebp+4]
	mov	word [esi+sWindow.height], ax
	
	mov	eax, dword [ebp]
	mov	word [esi+sWindow.width], ax	
	
	or	al, 100b		;set dirty bit
	mov	byte [esi+sWindow.flags], al
	
.error:
	pop	esi
	pop	eax
	
	pop	ebp
	ret	3*4
	
;Changes the Z-Order of a window to zeroe
SetActiveWindow:
	ret