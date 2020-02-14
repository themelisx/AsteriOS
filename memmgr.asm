;Memory Manager


;Memory Manager Map
;Map is an array of bytes. Every first bit shows if the current memory block is free or not.
;Every block is for 4096 (0xFFF) bytes of memory. Total size of map 1.048.576 bytes (0x100000)

;Memory Manager Table
;Address		dd	?	;start address
;Size			dd	?	;how many continious entries are allocated. 0xFFFFFFFF max entries.
;So max allocated memory by one can me all memory (4GB)


;bits     purpose
;12-31   address
;11-9 available for whatever you want to use here
;8      global bit -ignored
;7      page size- 0 for 4k
;6      reserved leave 0
;5      acessed, use to identify a page that has been unused since last time you checked
;4      disables cach, leave 0
;3      write through? leave 0
;2      1 for user, 0 for supervisor (1 keeps userland from modifing)
;1      r/w 1 for write, 0 is read only
;0      present, if this is unset this page loaded your os hasnt allocated a place in physical ram and
;	mapped it to this page yet- you load the page from hard drive to a free address you havent used
;	and set the address and present parts.
;	When the present bit is not set you can put whatever in the rest of the entry- its available for
;	programmer use (store offset in page file that contains the data for this page etc).

Init_Paging:
	pushad
	pushfd

	mov 	edi, PAGE_DIR
	mov	ecx, 1024
	mov	eax, PAGE_TABLE
.loop1:
	and	eax, 0FFFFF000h
	or	eax, 11b
	mov	dword [edi], eax
	add	edi, 4
	add	eax, 4096
	loop	.loop1		;clear all entries

	mov	edi, PAGE_TABLE
	mov	eax, 0
	mov	ecx, PAGE_TABLE_SIZE
	shr	ecx, 2		;/4
.loop2:
	and	eax, 0FFFFF000h
	or	eax, 11b
	mov	dword [edi], eax
	add	edi, 4
	add	eax, 1000h
	loop	.loop2


	popfd
	popad
	ret

Enable_Paging:
	; enable paging
        mov     eax, PAGE_DIR
        mov     cr3, eax
        mov     eax, cr0
        or      eax, 80000000h
        mov     cr0, eax

	push	dword PagingEnabled
        call	Print

        ret

;1st param: physical address
;2nd param: size allocated (in blocks)
;3rd param: virtual address
SetMemPage:
	push	ebp
	mov	ebp, esp
	add	ebp, 8

	pushad


	%ifdef DEBUG_2
	push	dword [ebp+8]
	push	dword [ebp+4]
	push	dword [ebp]
	push	Debug_SetMemPage
	call	Print
	%endif

	mov	edi, PAGE_DIR
	mov	eax, dword [ebp + 8]	;physical address
	and	eax, 0FFC00000h		; Keep directory entry index
	shr	eax, 22			;remove lower 22 bits
	add	edi, eax
	mov	eax, dword [edi]
	or	eax, 11b
	mov	dword [edi], eax

	mov	edi, eax
	add	edi, PAGE_TABLE
	and	eax, 0FFFFF000h
	mov	eax, dword [ebp + 8]
	and	eax, 3FF000h	;keep 12-21 bits
	shr	eax, 12		;remove lower 12 bits
	add	edi, eax

	mov	eax, dword [ebp+8]
	mov	ecx, dword [ebp+4]
.loop1:
	and	eax, 0FFFFF000h
	or	eax, 11b
	mov	dword [edi], eax
	add	edi, 4
	add	eax, 1000h
	dec	ecx
	jnz	.loop1

	popad
	pop	ebp
	ret	4*3

Init_MemManager:
	pushad

	%ifdef DEBUG
	push	dword Debug_InitMemMgr
	call	Print
	%endif

	;MAX mem size = 4 GB
	;Memory byte map
	;0 bit = Set if used
	;1-7 bits = Process ID (max 127 processes)
	mov	dword [Memory_Manager_Map], MEM_MGR_MAP
	mov	dword [Memory_Manager_Map_Size], 0FFFFFh	;4 GB / 4096 = FFFFF

	mov	dword [Memory_Manager_Table], MEM_MGR_TABLE
	mov	dword [Memory_Manager_Table_Size], 2000h	;1024 entries * 2 entries * 4 bytes (per entry)

	;clean up all table with zeroes
	mov	edi, dword [Memory_Manager_Map]
	mov	ecx, dword [Memory_Manager_Map_Size]	;memory manager map size (0x100000 blocks * 1 byte).
	shr	ecx, 2				;ecx=ecx/4

	mov	eax, 0
	rep	stosd

	mov	edi, dword [Memory_Manager_Table]
	mov	ecx, dword [Memory_Manager_Table_Size]		;memory manager table size (1024 entries * 8 bytes)
	shr	ecx, 2					;ecx=ecx/4

	mov	eax, 0
	rep	stosd

	;show system memory
	push	dword [TotalMem]
	push	dword SystemRam
	call	Print

	;setting first entry at MMT
	mov	edi, dword [Memory_Manager_Table]
	mov	eax, dword [Memory_Manager_Map]
	mov	dword [edi], eax
	mov	eax, dword [Memory_Manager_Map_Size]
	mov	dword [edi+4], eax
	add	edi, 8					;2 entries * 4 bytes (per entry)
	;setting second entry
	mov	eax, dword [Memory_Manager_Table]
	mov	dword [edi], eax
	mov	eax, dword [Memory_Manager_Table_Size]
	mov	dword [edi+4], eax

	;setting also at MMM (map)
	mov	edi, dword [Memory_Manager_Map]
	mov	eax, edi
	shr	eax, 12			;eax/4096
	add	edi, eax
	mov	ecx, dword [Memory_Manager_Map_Size]
	shr	ecx, 12

	mov	al, 11b
	rep	stosb

	;setting also at MMM (map)
	mov	edi, dword [Memory_Manager_Map]
	mov	eax, dword [Memory_Manager_Table]
	shr	eax, 12			;eax/4096
	add	edi, eax
	mov	ecx, dword [Memory_Manager_Table_Size]
	shr	ecx, 12

	mov	al, 11b
	rep	stosb

	%ifdef PAGING_ON

		push	dword ReportPageingIsOn
		call	Print

		call	Init_Paging

		push	dword [Memory_Manager_Map]
		push	dword 256
		push	dword [Memory_Manager_Map]
		call	SetMemPage

		push	dword [Memory_Manager_Table]
		push	dword 2
		push	dword [Memory_Manager_Table]
		call	SetMemPage

		;setup page directories/tables
		push	dword PAGE_DIR		;address
		push	dword 1000h		;size
		push	dword 1			;owner
		call	MemIsAlloc

		push	dword PAGE_TABLE	;address
		push	dword PAGE_TABLE_SIZE	;size
		push	dword 1			;owner
		call	MemIsAlloc
	%endif

	;setup LFB & OSM
	push	dword OSM_PTR
	push	dword OSM_MAX_SIZE
	push	dword 1
	call	MemIsAlloc

	push	dword [LFB]
	push	dword [OSM_Size]
	push	dword 1
	call	MemIsAlloc

	;setting up bios & system areas

	;ecx = size allocated
	;ebx = address
	push	dword 0			;address (bios)
	push	dword 4096		;size
	push	dword 0			;owner
	call	MemIsAlloc

	push	dword OS_STACK			;reserve space for stack
	push	dword 0FC00h
	push	dword 1			;system process
	call	MemIsAlloc

	;9FC00-9FFFF extended BIOS data area (EBDA)
	;A0000-BFFFF video RAM 	VGA framebuffers
	;C0000-C7FFF ROM 	video BIOS (32K is typical size)
	;C8000-EFFFF NOTHING
	;F0000-FFFFF ROM 	motherboard BIOS (64K is typical size)
	push	dword 9FC00h
	push	dword 603FFh
	push	dword 0
	call	MemIsAlloc

	push	dword [KernelAddress]
	push	dword Kernel_End - Kernel_Start
	push	dword 1
	call	MemIsAlloc

	mov	eax, FUNCTION_ARRAY_STRUCT_SIZE
	mov	ecx, FUNCTION_ARRAY_MAX_ENTRIES
	xor	edx, edx
	mul	ecx
	mov	dword [FunctionArraySize], eax
	push	eax
	call	MemAlloc
	mov	dword [FunctionArray], eax

	%ifdef PAGING_ON
		push	dword 14h
		push	dword IRQ_PageFault
		call	HookInterrupt

		;call	Enable_Paging
	%endif

	popad
	ret

;1st param: size to be allocated (in blocks)
FindFreeMem:
	push	ebp
	mov	ebp, esp
	add	ebp, 8

	push	ebx
	push	ecx
	push	edx
	push	edi

	mov	edi, dword [Memory_Manager_Map]

	mov	esi, edi
	add	esi, dword [Memory_Manager_Map_Size]	;points to the end of map
	dec	esi

	mov	eax, edi
	add	eax, dword [Memory_Manager_Map_Size]
	add	eax, dword [Memory_Manager_Table_Size]
	shr	eax, 12				;/4096
	add	edi, eax			;now points to first free block

	dec	edi

.FindFreeMem1:
	inc	edi
	cmp	edi, esi
	jg	.FindFreeMem_OutOfMem
	test	byte [edi], 1b
	jnz	.FindFreeMem1

	;save first empty entry

	mov	ebx, edi
	dec	edi
	mov	ecx, dword [ebp]		;blocks needed
.FindFreeMem2:
	inc	edi
	test	byte [edi], 1b
	jnz	.FindFreeMem3
	dec	ecx
	jnz	.FindFreeMem2
	jmp	.FindFreeMem4

.FindFreeMem3:
	;space was not enought
	;find another space
	mov	ecx, dword [ebp]
	jmp	.FindFreeMem1

.FindFreeMem4:
	mov	eax, ebx		;saved entry
	sub	eax, dword [Memory_Manager_Map]
	shl	eax, 12			;real address
	;eax has the final real allocated address
	jmp	.FindFreeMem_OK

.FindFreeMem_OutOfMem:
	mov	eax, -1
.FindFreeMem_OK:
	pop	edi
	pop	edx
	pop	ecx
	pop	ebx
	pop	ebp
	ret	4

;returns in EAX the address of the first empty entry
FindFirstMMT_Entry:
	push	edi
	push	esi

	mov	edi, dword [Memory_Manager_Table]
	mov	esi, edi
	add	esi, dword [Memory_Manager_Table_Size]
	sub	esi, 8
.loop:
	add	edi, 8			;first entry is reserved by MMT
	cmp	edi, esi
	je	.error
	cmp	dword [edi+4], 0	;if size is 0, the entry is empty
	jne	.loop
	mov	eax, edi
	jmp	.exit
.error:
	mov	eax, 0FFFFFFFFh		;table is full
.exit:
	pop	esi
	pop	edi
	ret

;1st param = size to be allocated
;returns in eax the address of allocated memory
MemAlloc:
	push	ebp
	mov	ebp, esp
	add	ebp, 8

	push	ebx
	push 	ecx
	push	edx
	push	edi

	mov	eax, [ebp]
	xor	edx, edx
	mov	ecx, 4096	;MemoryBlockSize
	div	ecx
	cmp	edx, 0
	je	.next1
	inc	eax
.next1:
	push	eax		;how many blocks, pushed for FindFreeMem
	call	FindFreeMem
	;returns the address of free memory (in eax)

	cmp	eax, -1
	je	.Error

	push	eax			;save memory address for function RET
	mov	ebx, eax

	call	FindFirstMMT_Entry
	;returns in EAX the address of the entry of MMT
	cmp	eax, 0FFFFFFFFh
	je	.Error

	mov	edi, eax
	mov	dword [edi], ebx	;address
	mov	ecx, dword [ebp]
	mov	dword [edi+4], ecx	;size in bytes

	mov	edi, dword [Memory_Manager_Map]
	shr	ebx, 12
	add	edi, ebx

	mov	eax, dword [ebp]
	xor	edx, edx
	mov	ecx, 4096	;MemoryBlockSize
	div	ecx
	cmp	edx, 0
	je	.next2
	inc	eax
.next2:
	mov	ecx, eax
	mov	ebx, ecx

	;TODO:Get the process ID to save in the map

	mov	al, 1
	rep	stosb

	pop	eax


	%ifdef PAGING_ON
		push	eax
		push	ebx
		push	eax
		call	SetMemPage
	%endif


.Error:
	%ifdef DEBUG_2
	push	eax			;save pointer

	push	dword [ebp]		;size
	push	eax			;address
	push	Debug_MemAlloc
	call	Print

	pop 	eax			;restore pointer
	%endif

	pop	edi
	pop	edx
	pop	ecx
	pop	ebx
	pop	ebp
	;now in EAX exist the absolute address of allocated memory
	ret	4

;1st param = the address of allocated memory
MemFree:
	push	ebp
	mov	ebp, esp
	add	ebp, 8

	push	edi
	push	esi
	push	ebx
	push	ecx

	%ifdef DEBUG_2
	push	dword [ebp]
	push	Debug_MemFree
	call	Print
	%endif

	mov	edi, dword [Memory_Manager_Table]
	mov	esi, edi
	add	esi, dword [Memory_Manager_Table_Size]
	sub	esi, 8
	mov	ebx, dword [ebp]

	.MemFree1:
		add	edi, 8
		cmp	edi, esi
		jg	.exit1
		cmp	dword [edi], ebx
		je	.MemFree_Found_OK
		jmp	.MemFree1
	.exit1:
		mov	eax, -1
		jmp	.MemFree_Exit

	.MemFree_Found_OK:

		mov	eax, dword [edi+4]	;allocated size
		xor	edx, edx
		mov	ecx, 4096	;MemoryBlockSize
		div	ecx
		cmp	edx, 0
		je	.next1
		inc	eax
	.next1:
		mov	ecx, eax

		;free up from the table
		mov	dword [edi], 0		;cleanup address
		mov	dword [edi+4], 0	;cleanup size

		;free up from the map
		mov	edi, dword [Memory_Manager_Map]
		mov	eax, dword [ebp]
		shr	eax, 12
		add	edi, eax

	mov	al, 0
	rep	stosb
	;.Mem_Free_FillMap:
	;	mov	byte [edi], 0
	;	inc	edi
	;	loop	.Mem_Free_FillMap

	;call	PrintRAM
.MemFree_Exit:
	pop	ecx
	pop	ebx
	pop	esi
	pop	edi
	pop	ebp
	ret	4

;1st param: address
;2nd param: size allocated
;3rd param: who is owner
;this functions just sets that an area is already allocated (called ONLY from system)
;used for bios areas e.t.c
MemIsAlloc:
	push	ebp
	mov	ebp, esp
	add	ebp, 8

	push	ebx
	push 	ecx
	push	edx
	push	edi

	call	FindFirstMMT_Entry
	;returns in EAX the address of the entry of MMT
	cmp	eax, 0FFFFFFFFh
	je	.error

	mov	eax, [ebp+4]
	xor	edx, edx
	mov	ecx, 4096	;MemoryBlockSize
	div	ecx
	cmp	edx, 0
	je	.next1
	inc	eax
.next1:
	mov	ecx, eax

	%ifdef PAGING_ON
		push	dword [ebp+8]
		push	ecx
		push	dword [ebp+8]
		call	SetMemPage
	%endif

	mov	edi, eax
	mov	eax, dword [ebp+8]
	mov	dword [edi], eax	;address
	mov	eax, dword [ebp+4]
	mov	dword [edi+4], eax	;size in bytes

	mov	edi, dword [Memory_Manager_Map]
	mov	eax, dword [ebp + 8]
	shr	eax, 12
	add	edi, eax

	mov	eax, dword [ebp]	;owner
	shl	eax, 1			;bypass bit 0
	or	eax, 1b			;set used flag

	rep	stosb
.error:
	%ifdef DEBUG_2
	push	dword [ebp+4]
	push	dword [ebp+8]
	push	Debug_MemAlloc
	call	Print
	%endif

	pop	edi
	pop	edx
	pop	ecx
	pop	ebx
	pop	ebp
	ret	3*4


GetMemoryManagerTable:
		mov	eax, dword [Memory_Manager_Table]
		ret

GetMemoryManagerTableSize:
		mov	eax, dword [Memory_Manager_Table_Size]
		ret

GetSystemRam:
		mov	eax, dword [SystemTotalRam]
		ret

;;;;;;;;;;;;;;;;;;;;;;;;;




;rMemory struct				;4 bytes struct
;Type			db	?	;0 = Free
					;1 = System
					;2 = Bios
					;3 = Video RAM
					;4 = ROM
					;5 = Allocatable (by system or program)

;Memory struct
;Address		dd	?	;start address
;Count of entries	dw	?	;how many continious entries are allocated. 0xFFFF max entries. So max allocated memory by one entry 0x3FFFC00
;Handle ID		dw	?	;Handle ID (0 means that cannot be free this part


;Physical memory layout of the PC
;linear address range	real-mode address range	memory type	use
;0- 	3FF	 	0000:0000-0000:03FF 	RAM	real-mode interrupt vector table (IVT)
;400- 	4FF 		0040:0000-0040:00FF 	BIOS data area (BDA)
;500- 	9FBFF 		0050:0000-9000:FBFF 	free conventional memory (below 1 meg)
;9FC00- 	9FFFF 		9000:FC00-9000:FFFF 	extended BIOS data area (EBDA)
;A0000- 	BFFFF 		A000:0000-B000:FFFF 	video RAM 	VGA framebuffers
;C0000-	C7FFF 		C000:0000-C000:7FFF 	ROM 	video BIOS (32K is typical size)
;C8000-	EFFFF 		C800:0000-E000:FFFF 	NOTHING
;F0000-	FFFFF 		F000:0000-F000:FFFF 	ROM 	motherboard BIOS (64K is typical size)
;100000-	FEBFFFFF 	RAM 			free extended memory (1 meg and above)
;FEC00000-FFFFFFFF 	various 			motherboard BIOS, PnP NVRAM, ACPI, etc.
