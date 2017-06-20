Init_DeviceManager:
	%ifdef DEBUG
	push	Debug_DevMgr_Init
	call	Print
	%endif

	push	dword sRegisterDevice
	push	dword RegisterDevice
	call	SetProcAddress
	
	push	dword sUnregisterDevice
	push	dword UnregisterDevice
	call	SetProcAddress
	
	push	DEVICE_ARRAY_SIZE
	call	MemAlloc
	
	mov	dword [DeviceArray], eax
	
	push	eax
	push	dword DEVICE_ARRAY_SIZE
	push	dword 0FFFFFFFFh
	call	MemSet			;clean up array	
	
	ret

;device's struct (10 bytes)
;DriverAddress			dd	?
;DMA Port			dw	?
;Channel			db	?
;IRQ				db	?
;Type				db	?
;Flags				db	?

;register device
;input:

;Name
;Driver address
;DMA
;Channel
;IRQ
;Type
;Flags
RegisterDevice:
	push	ebp
	mov	ebp, esp
	add	ebp, 8
	
	;%ifdef DEBUG
	push	dword [ebp+8]
	push	dword [ebp+16]	
	push	dword [ebp+20]
	push	dword [ebp+24]	
	push	Debug_RegisterDevice
	call	Print
	;%endif
	
	push	ecx
	push	edi
	
	mov	edi, dword [DeviceArray]
	mov	ecx, DEVICE_ARRAY_MAX_ENTRIES
	
.loop:	
	cmp	dword [edi], 0FFFFFFFFh		;empty place
	je	.doit
	
	add	edi, DEVICE_ARRAY_STRUCT_SIZE
	dec	ecx
	jnz	.loop
	
	mov	eax, -1
	jmp	.exit
.doit:
	mov	eax, dword [ebp+20]	;driver address DD
	mov	dword [edi], eax
	mov	eax, dword [ebp+26]	;dma DW
	mov	word [edi+4], ax
	mov	eax, dword [ebp+12]	;channel
	mov	byte [edi+6], al
	mov	eax, dword [ebp+8]	;irq
	mov	byte [edi+7], al
	mov	eax, dword [ebp+4]	;type
	mov	byte [edi+8], al
	mov	eax, dword [ebp]	;flags
	mov	byte [edi+9], al
	
	push	dword [ebp+24]	;name
	add	edi, 10
	push	edi
	call	StrCpy
	xor	eax, eax
.exit:
	pop	edi
	pop	ecx
	pop	ebp
	ret	7*4

;input:
;1st param: ?
UnregisterDevice:
	ret

DisableDevice:
	ret

EnableDevice:
	ret

;returns in eax the address of device driver	
GetDeviceDriver:
	ret
	
SetDeviceDriver:
	ret
	
GetDeviceType:
	ret
	
GetDeviceName:
	ret
	
