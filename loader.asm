;Function Array Struct
;DWORD		Address	of Function	(4 bytes)
;ASCIIZ str	Name of function	(28 bytes)

;import Table Struct
;Function name (null terminated)
;(label): Function Address dword
;array terminates with null (byte)

;export table struct
;Function name (null terminated)
;dword size (in bytes) from the start of executable to the start of the function
;array terminates with null (byte)

;relocation table struct
;dword offset of image start points to dword that must relocate
;array terminates with null (DWORD)

Init_Loader:
	pushad

	%ifdef DEBUG
	push	Debug_InitLoader
	call	Print
	%endif

	push	dword [FunctionArray]
	push	dword [FunctionArraySize]
	push	dword 0
	call	MemSet

	push	dword sSetProcAddress
	push	dword SetProcAddress
	call	SetProcAddress

	push	dword sGetProcAddress
	push	dword GetProcAddress
	call	SetProcAddress

	push	dword sLoadExecutable
	push	dword LoadExecutable
	call	SetProcAddress

	popad
	ret

;input eax = addr of function name to call
ExternalFunction:
	push	eax
	call	GetProcAddress
	cmp	eax, -1
	je	.exit
	call	eax
.exit:
	ret

;input:
;1st param: Function name (ASCIIZ)
;2nd param: Function address
;returns:
;-1 if cannot find empty record in array or if function name is > than record size
SetProcAddress:
	push	ebp
	mov	ebp, esp
	add	ebp, 8
	push	edi
	push	ecx

	;push	dword [ebp]
	;push	dword [ebp+4]
	;push	Debug_SetProcAddress
	;call	PrintDebug

	mov	edi, dword [FunctionArray]
	xor	ecx, ecx
.loop:
	cmp	ecx, FUNCTION_ARRAY_MAX_ENTRIES
	je	.exit
	cmp	dword [edi], 0
	je	.doit

	inc	ecx
	add	edi, FUNCTION_ARRAY_STRUCT_SIZE
	jmp	.loop
.doit:
	mov	eax, dword [ebp]
	mov	dword [edi], eax	;save address
	push	dword [ebp+4]
	call	StrLen
	cmp	eax, FUNCTION_ARRAY_STRUCT_SIZE - 5 	;Struct - address (4) - null termianted (1)
	jg	.exit
	add	edi, 4
	push	dword [ebp+4]
	push	dword edi
	call	ToLower
	xor	eax, eax
	jmp	.exit_OK
.exit:
	mov	eax, -1
.exit_OK:
	pop	ecx
	pop	edi
	pop	ebp
	ret 	2 * 4

;input:
;1st param: Function name
;returns in eax the function address
GetProcAddress:
	push	ebp
	mov	ebp, esp
	add	ebp, 8

	push 	edi
	push	ecx

	xor	ecx, ecx
	mov	edi, dword [FunctionArray]

	add	edi, 4			;bypass address

	push	dword [ebp]
	push	dword TempBuffer
	call	ToLower
.Loop:
	push	dword TempBuffer
	push	dword edi
	call	StrCmp
	cmp	eax, -1
	jne	.Found
	inc	ecx
	cmp	ecx, FUNCTION_ARRAY_MAX_ENTRIES
	je	.exit
	add	edi, FUNCTION_ARRAY_STRUCT_SIZE
	jmp	.Loop
.Found:
	sub	edi, 4
	mov	eax, dword [edi]	;get address
	jmp	.exit_OK
.exit:
	cmp	byte [ReportNotFound], 1	;report it
	jne	.ReadyToExit
	;Use this to report
	push	dword [ebp]
	push	dword CannotFindImport
	call	Print
.ReadyToExit:
	mov	eax, -1
.exit_OK:
	;push	eax			;save return status
	;push	eax
	;push	dword [ebp]
	;push	Debug_GetProcAddress
	;call	PrintDebug
	;pop	eax			;restore status
	pop	ecx
	pop	edi
	pop	ebp
	ret	4

;input: import table address
ResolveImportTable:
	push	ebp
	mov	ebp, esp
	add	ebp, 8

	%ifdef DEBUG
	push	dword [ebp]
	push	Debug_ResolveImportTable
	call	Print
	%endif

	push	esi
	mov	esi, dword [ebp]
.Start:
	cmp	byte [esi], 0
	je	.exit_OK

	mov	byte [ReportNotFound], 1	;report it

	push	esi
	call	GetProcAddress
	cmp	eax, -1
	je	.exit

	push	eax			;save address

	push 	esi
	call	StrLen

	add	esi, eax
	add	esi, 1			;1 for null terminated
	pop	eax			;restore address

	mov	dword [esi], eax
	add	esi, 4			;bypass	address
	jmp	.Start
.exit_OK:
	xor	eax, eax
.exit:
	pop	esi
	pop	ebp
	ret	4


;input:
;1st: export table address
;2nd: image loaded address
RegisterExportTable:
	push	ebp
	mov	ebp, esp
	add	ebp, 8

	%ifdef DEBUG
	push	dword [ebp]
	push	dword [ebp+4]
	push	Debug_ResolveExportTable
	call	Print
	%endif

	push	esi
	push	ecx

	mov	esi, [ebp+4]
.loop:
	cmp	byte [esi], 0
	je	.ok

	mov	byte [ReportNotFound], 0	;dont report

	push	esi
	call	GetProcAddress

	cmp	eax, -1			;function already register ?
	jne	.exit

	push	esi			;save function name ptr

	push	esi
	call	StrLen

	mov	ecx, eax		;save length
	add	esi, eax
	inc	esi
	mov	eax, dword [esi]	;function address
	add	eax, dword [ebp]	;image loaded address

	pop	esi			;restore function name

	push	esi
	push	eax
	call	SetProcAddress

	cmp	eax, -1
	je	.exit
	add	esi, ecx
	add	esi, 5			;1 null, 4 address
	jmp	.loop
.ok:
	xor 	eax, eax
.exit:
	pop	ecx
	pop	esi
	pop	ebp
	ret	2*4

;input:
;1st: relocation table address
;2nd: image loaded address
ResolveRelocations:
	push	ebp
	mov	ebp, esp
	add	ebp, 8

	;TODO:
	;resolve imports
	%ifdef DEBUG
	push	dword [ebp]
	push	dword [ebp+4]
	push	Debug_ResolveRelocationTable
	call	Print
	%endif

	pushad

	mov	esi, [ebp+4]
	mov	edi, [ebp]		;image loaded address
.loop:
	lodsd
	cmp	eax, 0		;end of array?
	je	.ok

	mov	ebx, dword [edi+eax]
	add	ebx, dword [ebp]
	mov	dword [edi+eax], ebx
	jmp	.loop

.ok:
	popad

	pop	ebp
	ret	2*4

;input:
;1st param: address of loaded executable
;returns -1 on failure, orelse zero
LoadExecutable:
	push	ebp
	mov	ebp, esp
	add	ebp, 8

	push	esi
	push	ebx

	%ifdef DEBUG
	push	dword [ebp]
	push	dword LoadingExecutable
	call	Print
	%endif
;executable header 38 bytes
;Signature		db	'AsteriOS'
;HeaderVersion		db	00010001b		;v.1.0 (4 hi-bits major version, 4 lo-bits minor version)
;ExecutableCRC		dd	?			;including rest of header
;ExecutableFlags		db	00111010b		;check below (execute init & stop, contains import & export)
;ImportTableOffset	dd	ImportTable - Driver_Start
;ExportTableOffset	dd	ExportTable - Driver_Start
;RelocationTableOffset	dd	RelocationTable - Driver_Start
;InitFunctionOffset	dd	DriverInit - Driver_Start
;StopFunctionOffset	dd	DriverStop - Driver_Start
;EntryPoint		dd	?

	push	dword [ebp]	;address
	push	dword DrvSignature
	push	dword 8		;signature size
	call	MemCmp
	cmp	eax, 0
	je	.next
		push	dword NoExecutable
		call	Print
		jmp	.error
.next:
	mov	esi, dword [ebp]	;address

	movzx	eax, byte [esi+8]	;header version
	call	IsHeaderCombatible
	cmp	eax, 0FFFFFFFFh
	jne	.next1
		push	dword NoExecutableHeader
		call	Print
		jmp	.error
.next1:
	;TODO: check CRC
	;mov	eax, dword [esi+9]	;"ExecutableCRC" (dword)
;.next2:

;executable flags (0=no, 1=yes)
;0 = Execute EIP
;1 = Execute Init function
;2 = Execute Stop function
;3 = Contains Import table
;4 = Contains Export table
;5 = Contains Relocations
;6 = Executable is encrypted
;7 = Executable is compressed

	movzx	ebx, byte [esi+13]	;"ExecutableFlags" (byte)

	test	ebx, 10000000b
	jz	.next3
		;call	Decompress
		;cmp	eax, -1
		;je	.error
.next3:
	test	ebx, 1000000b
	jz	.next4
		;call	Decrypt
		;cmp	eax, -1
		;je	.error
.next4:
	test	ebx, 100000b
	jz	.next5
		mov	eax, dword [esi+22]	;offset
		add	eax, dword [ebp]	;add image base
		push	eax			;Relocation table address
		push	dword [ebp]		;image base
		call	ResolveRelocations
		cmp	eax, -1
		je	.error
.next5:
	test	ebx, 10000b
	jz	.next6
		mov	eax, dword [esi+18]	;offset
		add	eax, dword [ebp]	;add image base
		push	eax			;Export table address
		push	dword [ebp]		;image base
		call	RegisterExportTable
		cmp	eax, -1
		je	.error

.next6:
	test	ebx, 1000b
	jz	.next7
		mov	eax, dword [esi+14]	;"ImportTableAddress" dword (offset from start of image)
		add	eax, dword [ebp]	;add image base
		push	eax
		call	ResolveImportTable
		cmp	eax, -1
		je	.error
.next7:
	test	ebx, 10b
	jz	.next8
		pushad
		pushfd
		mov	eax, dword [esi+26]	;offset of Init
		add	eax, dword [ebp]	;add image base
		call	eax
		;TODO:
		;cmp	eax, -1
		;je	.error
		popfd
		popad
.next8:
	test	ebx, 1b
	jz	.next9
		pushad
		pushfd
		mov	eax, dword [esi+34]	;offset of Entry point
		add	eax, dword [ebp]	;add image base
		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		;call	eax
		push	eax			    		;Code to execute
		push	dword 4*1024			;stack size
		call	CreateProcess
		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		popfd
		popad
		;if Entry point executed, then is a simple EXE
		;so return -1 to unload
		jmp	.error
.next9:
	xor	eax, eax

	;push	dword [ebp]
	;push	dword [ebp]
	;call	SetMemOwner

	jmp	.exit
.error:
	mov	eax, -1
.exit:
	pop	ebx
	pop	esi
	pop	ebp
	ret	4

;input al=header version
IsHeaderCombatible:
	;MAX version number = v.15.15 :(
	push	eax
	and	eax, 11110000b		;keep hi 4 bits (of byte)
	ror	eax, 4
	cmp	eax, LOWEST_MAJOR_VERSION
	jb	.NotOk1
	pop	eax
	and	eax, 00001111b		;keep low 4 bits (of byte)
	cmp	eax, LOWEST_MINOR_VERSION
	jb	.NotOk2
	xor	eax, eax
	ret
.NotOk1:
	pop	eax
.NotOk2:
	mov	eax, 0FFFFFFFFh
	ret
