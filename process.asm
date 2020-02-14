Init_ProcessManager:
	push	eax
	push	ecx
	push	edx
	
	xor	edx, edx
	mov	eax, MAX_PROCESSES
	mov	ecx, PROCESS_STRUCT_SIZE
	mul	ecx				;PROCESS_STRUCT_SIZE * MAX_PROCESSES

	push	eax
	call	MemAlloc
	mov	dword [ProcessArray], eax

	pop	edx
	pop	ecx
	pop	eax
	ret
	

;1st param: loaded address
;2nd param: stack size
CreateProcess:
	push	ebp
	mov	ebp, esp
	add	ebp, 8	
	
	push	eax
	push	edi	
	push	ecx
	push	ebx
	
	mov	edi, dword [ProcessArray]
	mov	ecx, PROCESS_STRUCT_SIZE
	sub	edi, ecx
	mov	ebx, 0
.loop:	
	inc	ebx
	cmp	ebx, MAX_PROCESSES
	je	.error					;cannot load more!!!
	add	edi, ecx
	cmp	dword [edi+tss.status], 0		;empty record ?
	jne	.loop					;goto next process		
	
	push	dword [ebp]				;stack size
	call	MemAlloc
	add	eax, dword [ebp]
	sub	eax, 4
	
	mov 	dword [edi+tss.esp], eax		;stack	
	mov	word [edi+tss.ss], ss
	
	mov	eax, dword [ebp+4]			;Code to execute
	mov 	dword [edi+tss.eip], eax
	mov	dword [edi+tss.eflags], 0
	mov  	byte [edi+tss.eflags+1], 2		;Enable its interrupts	
	
	mov	dword [edi+tss.status], 1		;present flag		
	
	mov	byte [edi+tss.cr3], 0	
	mov	[edi+tss.ss], ss
	mov	[edi+tss.gs], gs
	mov	[edi+tss.fs], fs	
	mov	[edi+tss.ds], ds
	mov	[edi+tss.es], es
	;mov	[edi+tss.cs], cs
	
	push	ebp
	mov	ebp, esp
	mov	esp, dword [edi+tss.esp]
	push	dword [edi+tss.eflags]
	push	cs
	push	dword [edi+tss.eip]
	mov 	dword [edi+tss.esp], esp	;stack	
	mov	esp, ebp
	pop	ebp	

.error:
	pop	ebx
	pop	ecx
	pop	edi
	pop	eax
	
	pop	ebp
	ret	2*4