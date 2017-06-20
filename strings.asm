;input:
;1st: fullpath name
;2nd: output buffer
ExtractFileName:
	push	ebp
	mov	ebp, esp
	add	ebp, 8
	
	push	esi
	push	edi
	push	ecx
	
	mov	esi, [ebp+4]
	mov	edi, [ebp]
	
	push	esi
	call	StrLen
	
	mov	ecx, eax
	inc	ecx
	add	esi, eax
.loop:
	dec	ecx
	jz	.exit
	cmp	byte [esi], '\'
	je	.found
	dec	esi
	jmp	.loop
.found:
	inc	esi
.exit:	
	mov	al, byte [esi]
	mov	byte [edi], al
	cmp	al, 0
	je	.exit2
	inc 	esi
	inc	edi
	jmp	.exit
.exit2:
	pop	ecx
	pop	edi
	pop	esi
	pop	ebp
	ret	2*4


;input:
;1st param: input string
;2nd param: output buffer
ToLower:
	push	ebp
	mov	ebp, esp
	add	ebp, 8
	
	push	esi
	push	edi
	
	mov	esi, [ebp+4]
	mov	edi, [ebp]
.loop:
	mov	al, byte [esi]
	cmp	al, 0
	je	.exit
	cmp	al, 'A'
	jb	.donothing
	cmp	al, 'Z'
	jg	.donothing
	add	al, 20h
.donothing:
	mov	byte [edi], al
	inc	esi
	inc	edi
	jmp	.loop
.exit:
	mov	byte [edi], 0	
	pop	edi
	pop	esi
	pop	ebp
	ret	2*4

;input:
;1st param: input string
;2nd param: output buffer
ToUpper:
	push	ebp
	mov	ebp, esp
	add	ebp, 8
	
	push	esi
	push	edi
	
	mov	esi, [ebp+4]
	mov	edi, [ebp]
.loop:
	mov	al, byte [esi]
	cmp	al, 0
	je	.exit
	cmp	al, 'a'
	jb	.donothing
	cmp	al, 'z'
	jg	.donothing
	sub	al, 20h
.donothing:
	mov	byte [edi], al
	inc	esi
	inc	edi
	jmp	.loop
.exit:	
	mov	byte [edi], 0
	pop	edi
	pop	esi
	pop	ebp
	ret	2*4
	
;input: 
;1,2: buffers to compare
;no matter the order
;3rd: size of buffers
;returns eax=0 if equal, -1 if not
MemCmp:
	push	ebp
	mov	ebp, esp
	add	ebp, 8
	
	xor	eax, eax
	push	esi
	push	edi
	push	ecx	
	
	mov	esi, [ebp+8]
	mov	edi, [ebp+4]
	mov	ecx, [ebp]
.Start:
	mov	al, byte [esi]
	mov	ah, byte [edi]
	cmp	al, ah
	jne	.NotEqual
	dec	ecx
	jz	.Equal
	
	inc	esi
	inc	edi
	jmp	.Start
.NotEqual:
	mov	eax, -1
	jmp	.exit
.Equal:	
	xor	eax, eax
.exit:
	pop	ecx
	pop	edi
	pop	esi	
	pop	ebp
	ret	3*4

;1st param: input buffer
;2nd param: output buffer
;3rd param: size to be copied
MemCpy:
	push	ebp
	mov	ebp, esp
	add	ebp, 8
	
	push	esi
	push	edi
	push	ecx
	
	mov	esi, dword [ebp+8]
	mov	edi, dword [ebp+4]
	mov	ecx, dword [ebp]
	
	rep	movsb
	
	pop	ecx
	pop	edi
	pop	esi
	pop	ebp
	ret 	3*4

;1st param: buffer
;2nd param: size
;3rd param: char to set
MemSet:
	push	ebp
	mov	ebp, esp
	add	ebp, 8
	
	push	eax
	push	ecx	
	push	edi	
	
	mov	edi, dword [ebp+8]	;buffer
	mov	ecx, dword [ebp+4]	;length
	mov	eax, dword [ebp]	;char
	
	rep	stosb
	
	pop	edi
	pop	ecx
	pop	eax	
	pop	ebp
	ret	3*4
	

;input: 
;2 strings (ASCIIZ) to compare
;no matter the order
;returns eax=0 if equal, -1 if not
StrCmp:
	push	ebp
	mov	ebp, esp
	add	ebp, 8
	
	xor	eax, eax
	push	esi
	push	edi
	
	mov	esi, [ebp+4]
	mov	edi, [ebp]
.Start:
	mov	al, byte [esi]
	mov	ah, byte [edi]
	cmp	al, ah
	jne	.Exit
	cmp	al, 0
	je	.Equal
	
	inc	esi
	inc	edi
	jmp	.Start
.Exit:
	mov	eax, -1
.Equal:	
	pop	edi
	pop	esi	
	pop	ebp
	ret	2*4

;input:
;1st param source string (null terminated)
;2nd param target string	
;returns in eax the size of string that copied
StrCpy:
	push	ebp
	mov	ebp, esp
	add	ebp, 8
	
	push	esi
	push	edi
	push	ecx
	xor	ecx, ecx
	mov	esi, [ebp+4]
	mov	edi, [ebp]
.Loop:
	mov	al, byte [esi]
	mov	byte [edi], al
	inc	ecx
	inc	esi
	inc	edi
	cmp	al, 0
	jne	.Loop

	dec	ecx	
	mov	eax, ecx
	pop	ecx
	pop	edi
	pop	esi
	pop	ebp
	ret	2*4

;input: esi = string (ASCIIZ)
;returns: strlen in eax
StrLen:
	push	ebp
	mov	ebp, esp
	add	ebp, 8
	
	push	esi
	push	ecx
	xor	ecx, ecx	
	mov	esi, [ebp]
.Loop:
	mov	al, byte [esi]
	cmp	al, 0
	je	.Exit
	inc	ecx
	inc	esi
	jmp	.Loop
.Exit:
	mov	eax, ecx
	pop	ecx
	pop	esi
	pop	ebp
	ret	4
	
;Converts number Decimal format string	
MakeDecimal:
	push	ebp
	mov	ebp, esp
	add	ebp, 8	
	
	push	esi
	push	edi
	push	ebx
	push	ecx
	push	edx
	
	mov	eax, [ebp]
	mov	edi, DecimalBuf
	cmp	eax, 0
	jne	.doit
	mov	edi, DecimalBufT
	mov	byte [edi], '0'
	inc	edi
	jmp	.exit_now
.doit:	
     	mov	ebx, 10
     	xor	ecx, ecx
     	xor	edx, edx
.loop:
	cmp	eax, 0
	je	.exit
	push	edx
	inc	ecx
	xor	edx, edx
	div	ebx
	add	dl, 48
	mov	byte [edi], dl
	inc   	edi
	pop	edx
	inc	edx
	cmp	edx, 3
	jne	.loop
	xor	edx, edx
	mov	byte [edi], '.'
	inc 	edi
	inc	ecx
	jmp	.loop
.exit:
	dec	edi
	mov	esi, edi
	mov	edi, DecimalBufT
	cmp	byte [esi], '.'
	jne	.next
	dec	esi	
.next:
	mov	al, byte [esi]
	mov	byte [edi], al
	inc	edi
	dec	esi
	dec	ecx
	jnz	.next
.exit_now:
	mov	byte [edi], 0
	
	pop	edx
	pop	ecx
	pop	ebx
	pop	edi
	pop	esi
	pop	ebp
     	ret	4
     	
