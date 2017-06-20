;4. Directory Table (FAT12 & FAT16)
;0-10    File name (8 bytes) with extension (3 bytes)
;11      Attribute - a bitvector. 
;Bit 0: read only. 
;Bit 1: hidden.
;Bit 2: system file. 
;Bit 3: volume label. 
;Bit 4: subdirectory.
;Bit 5: archive. 
;Bits 6-7: unused.
;12-21   Reserved (see below)
;22-23   Time (5/6/5 bits, for hour/minutes/doubleseconds)
;24-25   Date (7/4/5 bits, for year-since-1980/month/day)
;26-27   Starting cluster (0 for an empty file)
;28-31   Filesize in bytes

;5. Cluster map for FAT16 (16 bit values (2 bytes), 256 entries per 512 byte sector)
;The cluster map contains 2 byte entries used to identify the next cluster that belongs to the chain. 
;Note that cluster entries 00 and 01 are always reserved. The first cluster that can be used on a newly 
;formatted disk would be 02. So a cluster map might look like this for a single file that is 4K bytes in
;length: (remember that my 64 Meg card has 1K clusters each being 2 sectors @ 512 bytes).
;Clust 00 	Clust 01 	Clust 02 	Clust 03 	Clust 04 	Clust 05 	Clust 06 	Clust 07
;00 00 	00 00 	03 00 	04 00 	05 00 	FF FF 	00 00 	00 00
;The entries for cluster 00 and 01 are reserved, hence the 00 values. The file starts at cluster 02 so that entry points
;to 03 as the next cluster in the chain and so on. Finally, the file ends at cluster 05 which explains the FF FF values 
;which represents a termination in the cluster chain. This would look exactly the same if the file length were 3200 bytes
;instead of 4000. The remaining 800 bytes in the last cluster are wasted space. This is a side-effect of using FAT file 
;systems- the larger the cluster size, the more potential wasted space.

Init_FAT12:
	%ifdef DEBUG
	push	Debug_FAT12_Init
	call	Print
	%endif

	push	dword 512
	call	MemAlloc
	mov	dword [BootSector], eax
	
	call	FAT12_ReadBoot
	call	FAT12_ReadFAT
	call	FAT12_ReadDirectory
	ret

align 4
;1st param: action
;2nd param: fullpath filename (in lowercase)
FAT12_Main:
	push	ebp
	mov	ebp, esp
	add	ebp, 8
	
	;%ifdef DEBUG
	;push	dword [ebp]
	;push	dword [ebp+4]
	;push	Debug_FAT12_Main
	;call	PrintDebug
	;%endif

	mov	eax, [ebp+4]		;What to do
	cmp	eax, FS_FIND_FILE
	jne	.next1	
	
	push	dword [ebp]		;filename
	call	FAT12_FindFile
	cmp	eax, -1
	je	.exit
	xor	eax, eax		;clear sector position
	jmp	.exit
.next1:
	cmp	eax, FS_GET_FILE_SECTOR
	jne	.next2
	
	push	dword [ebp]		;filename
	call	FAT12_FindFile
	jmp	.exit
.next2:
	cmp	eax, FS_GET_FILE_SIZE
	jne	.next3
	
	push	dword [ebp]
	call	FAT12_GetFileSize
	jmp	.exit
.next3:
	cmp	eax, FS_DIRLIST
	jne	.next4
	
	push	dword [ebp]		;drive & directory
	call	FAT12_DirList
	jmp	.exit
.next4:
	cmp	eax, FS_GET_FILE_NEXT_SECTOR
	jne	.next5
	
	push	dword [ebp]
	call	FAT12_FindNextSector
	jmp	.exit
.next5:
	cmp	eax, FS_CREATE_FILE
	jne	.next6
	
	push	dword [ebp]
	call	FAT12_CreateFile
	jmp	.exit
.next6:
	cmp	eax, FS_DELETE_FILE
	jne	.next7
	
	push	dword [ebp]
	call	FAT12_DeleteFile
	jmp	.exit
.next7:

.exit:
	pop	ebp
	ret	2*4
	
FAT12_ReadBoot:
	;cannot used function FDC_Read, cause this function need data from boot sector
	push	dword DMA_READ
	push	dword 0
	push	dword 0
	push	dword 0
	push	dword 1
	push	dword [BootSector]		;buffer
	call	FDC_DO
.loop:
	nop
	call	Delay32
	cmp	byte [FDC_Busy_Flag], 1
	je	.loop
	
	ret

FAT12_ReadFAT:
	pushad
	mov	esi, dword [BootSector]
	xor	edx, edx
	movzx	ebx, byte [esi+10h]		;Number Of FATs
	movzx	eax, word [esi+16h]		;Sectors Per FAT
	mul	ebx				;total sectors to read in eax
	mov	dword [FAT12_FAT_Size], eax
	movzx	ecx, word [esi+0Bh]		;bytes per sector
	xor	edx, edx
	mul	ecx
	mov	ecx, eax
	
	mov	ebx, dword [esi+1Ch]		;Hidden Sectors
	inc	ebx
	mov	dword [FAT12_FAT_Start], ebx	;keep start of FAT
	
	push	ecx
	call	MemAlloc
	mov	[FAT12_FAT_Buffer], eax
	
	push	dword [FAT12_FAT_Size]
	call	MemAlloc
	mov	dword [FAT12_FAT_Map], eax
	
	push	dword [FAT12_FAT_Map]
	push	dword [FAT12_FAT_Size]
	push	dword 0FFFFFFFFh		;dirty area flag
	call	MemSet

	;push	dword [FAT12_FAT_Start]		;start sector
	;push	dword [FAT12_FAT_Size]		;how many sectors to read
	;push	dword [FAT12_FAT_Buffer]	;buffer
	;call	FDC_Read
	
	popad
	ret
	
FAT12_ReadDirectory:
	pushad
	
	mov	esi, dword [BootSector]
	xor	edx, edx
	movzx	ebx, byte [esi+10h]		;Number Of FATs
	movzx	eax, word [esi+16h]		;Sectors Per FAT
	mul	ebx				;total sectors to read in eax
	add	eax, dword [esi+1Ch]		;Hidden Sectors
	inc	eax				;add boot sector	
	mov	dword [FirstRealSector], eax	;inc later
	mov	dword [FAT12_DIR_Start], eax	;keep start of dir	
	xor	edx, edx
	movzx	eax, word [esi+11h]		;Root Entries
	;224/16
	mov	ebx, 16				;16 entries per sector
	div	ebx
	mov	dword [FAT12_DIR_Size], eax	;how many sectors
	add	dword [FirstRealSector], eax
	sub	dword [FirstRealSector], 2	;first 2 are reserved
	
	movzx	ecx, word [esi+0Bh]		;bytes per sector
	xor	edx, edx
	mul	ecx
	mov	ecx, eax
	
	push	ecx
	call	MemAlloc
	mov	dword [FAT12_Dir_Buffer], eax
	
	push	eax				;dword [FAT12_Dir_Buffer]
	push	ecx
	push	dword 0FFFFFFFFh		;dirty area flag
	call	MemSet
	
	;push	dword [FAT12_DIR_Start]
	;push	dword [FAT12_DIR_Size]
	;push	dword [FAT12_Dir_Buffer]	;buffer
	;call	FDC_Read
	popad
	ret

;input:
;1st: file name
;2nd: output buffer (FAT formatted)
FAT12_StrToFileName:
	push	ebp
	mov	ebp, esp
	add	ebp, 8
	
	push	esi
	push	edi
	mov	edi, [ebp]
	mov	esi, [ebp+4]
	xor	ecx, ecx
.loop:
	cmp	byte [esi], '.'
	je	.next1
	cmp	ecx, 8
	je	.next
	mov	al, byte [esi]
	mov	byte [edi], al
	inc	esi
	inc	edi
	inc	ecx
	jmp	.loop
.next1:
	cmp	ecx, 8
	je	.next
	mov	byte [edi], ' '
	inc	edi
	inc	ecx
	jmp	.next1
.next:
	inc	esi
.loop2:
	cmp	ecx, 11
	je	.exit
	mov	al, byte [esi]
	cmp	al, 0
	je	.next2
	mov	byte [edi], al
	inc	edi
	inc	esi
	inc	ecx
	jmp	.loop2
.next2:	
	cmp	ecx, 11
	je	.exit
	mov	byte [edi], ' '
	inc	edi
	inc	ecx
	jmp	.next2
.exit:
	pop	edi
	pop	esi	
	pop	ebp
	ret	2*4
	
;input:
;1st: FAT file name
;2nd: output buffer
FAT12_FilenameToStr:
	push	ebp
	mov	ebp, esp
	add	ebp, 8
	
	push	ecx
	push	esi
	push	edi
	mov	edi, [ebp]
	mov	esi, [ebp+4]
	mov	ecx, 1
.loop:
	cmp	ecx, 9
	je	.next
	mov	al, byte [esi]
	cmp	al, ' '
	je	.next
	mov	byte [edi], al	
	inc	ecx
	inc	esi
	inc	edi
	jmp	.loop
.next:
	mov	ecx, 1
	mov	esi, [ebp+4]
	add	esi, 8
	mov	byte [edi], '.'
	inc	edi
.loop1:
	cmp	ecx, 4
	je	.next1
	mov	al, byte [esi]
	cmp	al, ' '
	je	.next1
	mov	byte [edi], al	
	inc	ecx
	inc	esi
	inc	edi
	jmp	.loop1
.next1:	
	cmp	byte [edi-1], '.'
	jne	.next2
	dec	edi
.next2:
	mov	byte [edi], 0
	
	push	dword [ebp]
	push	dword [ebp]
	call	ToLower	
	
	pop	edi
	pop	esi	
	pop	ecx
	pop	ebp
	ret	2*4
	
;input: full path file name (asciiz)
;TODO: for now only filename is given
;later make a full path scan
;returns in eax the size. -1 if not found
FAT12_GetFileSize:
	push	ebp
	mov	ebp, esp
	add	ebp, 8	
	
	push	esi
	push	edi
	
	push	dword [ebp]		;filename
	push	dword TmpFileName2
	call	ExtractFileName
	
	mov	edi, dword TmpFileName2
	;TODO: change later to current directory
	mov	esi, dword [FAT12_Dir_Buffer]	
.loop:
	cmp	dword [esi], 0FFFFFFFFh	;sector not readed
	jne	.sector_ok
	
	pushad	
	mov	edi, dword [BootSector]
	movzx	ecx, word [edi+0Bh]		;bytes per sector
	mov	eax, esi
	mov	ebx, dword [FAT12_Dir_Buffer]
	sub	eax, ebx
	xor	edx, edx
	div	ecx
	mov	ebx, dword [FAT12_DIR_Start]	;first sector of FAT_Dir
	add	ebx, eax
	push	ebx			;start sector
	push	dword 1			;how many sectors to read
	push	esi			;buffer
	call	FDC_Read
	popad	
.sector_ok:
	mov	eax, -1
	cmp	byte [esi], 0
	je	.exit
	cmp	byte [esi], 0E5h	;file is deleted
	je	.next
	
	movzx	eax, byte [esi+11]	;attrib
	and	eax, 1000b
	cmp	eax, 0
	jne	.next			;volume label
	
	movzx	eax, byte [esi+11]	;attrib directory
	and	eax, 10000b
	cmp	eax, 0
	jne	.next
	
	push	esi
	push	dword TmpFileName
	call	FAT12_FilenameToStr
	
	push	dword TmpFileName
	push	edi
	call	StrCmp
	cmp	eax, 0
	jne	.next
	
	mov	eax, dword [esi+28]		;file size
	jmp	.exit	
.next:
	add	esi, 32
	jmp	.loop
.exit:	
	pop	edi
	pop	esi
	pop	ebp
	ret	4
	
;input filename
FAT12_DeleteFile:
	push	ebp
	mov	ebp, esp
	add	ebp, 8	
	
	pushad
	
	push	dword [ebp]		;filename
	push	dword TmpFileName2
	call	ExtractFileName
	
	mov	edi, dword TmpFileName2
	;TODO: change later to current directory
	mov	esi, dword [FAT12_Dir_Buffer]
.loop:	
	cmp	dword [esi], 0FFFFFFFFh	;sector not readed
	jne	.sector_ok
	
	pushad	
	mov	edi, dword [BootSector]
	movzx	ecx, word [edi+0Bh]		;bytes per sector
	mov	eax, esi
	mov	ebx, dword [FAT12_Dir_Buffer]
	sub	eax, ebx
	xor	edx, edx
	div	ecx
	mov	ebx, dword [FAT12_DIR_Start]	;first sector of FAT_Dir
	add	ebx, eax
	push	ebx			;start sector
	push	dword 1			;how many sectors to read
	push	esi			;buffer
	call	FDC_Read
	popad
	
.sector_ok:
	mov	eax, -1
	cmp	byte [esi], 0		;end of FAT, file not found
	jne	.not_end
	jmp	.error
.not_end:
	cmp	byte [esi], 0E5h	;file is deleted
	je	.next
	
	movzx	eax, byte [esi+11]	;attrib
	and	eax, 1000b
	cmp	eax, 0
	jne	.next			;volume label
	
	movzx	eax, byte [esi+11]	;attrib directory
	and	eax, 10000b
	cmp	eax, 0
	jne	.next
	
	push	esi
	push	dword TmpFileName
	call	FAT12_FilenameToStr
	
	push	dword TmpFileName
	push	edi
	call	StrCmp
	cmp	eax, 0
	jne	.next
	
	mov	byte [esi], 0E5h	;mark deleted
	movzx	ebx, word [esi+26]	;starting cluster
	jmp	.save1
.next:
	;TODO: check if ESI pass end of buffer
	add	esi, 32
	jmp	.loop
	
.save1:
	pushad
	mov	edi, dword [BootSector]
	movzx	ecx, word [edi+0Bh]		;bytes per sector
	mov	eax, esi
	mov	ebx, dword [FAT12_Dir_Buffer]
	sub	eax, ebx
	xor	edx, edx
	div	ecx
	;eax=sector
	sub	esi, edx			;start of sector
	mov	ebx, dword [FAT12_DIR_Start]	;first sector of FAT
	add	ebx, eax
	
	push	ebx			;start sector
	push	dword 1			;how many sectors to write
	push	esi			;buffer
	call	FDC_WriteSectors
	popad	

	mov	dword [LastSector], -1
	mov	byte [SaveNow], 0		;dont save first time
.loop2:
	xor	edx, edx
	mov	eax, ebx	;ebx has the starting/next cluster
	mov	ebx, 15
	mul	ebx
	xor	edx, edx
	mov	ebx, 10
	div	ebx
	and	edx, 1b
	rol	edx, 2
	;result in eax, edx = 0 or 1 to shift left result	
	mov	esi, dword [FAT12_FAT_Buffer]
	add	esi, eax
	
	;read sector
	pushad
	mov	edi, dword [BootSector]
	movzx	ecx, word [edi+0Bh]		;bytes per sector
	mov	eax, esi
	mov	ebx, dword [FAT12_FAT_Buffer]
	sub	eax, ebx
	xor	edx, edx
	div	ecx
	;eax=sector
	cmp	eax, dword [LastSector]
	je	.next2
	
	call	SaveLastSector
.next2:
	mov	dword [LastSector], eax
	
	mov	edi, dword [FAT12_FAT_Map]
	add	edi, eax
	cmp 	byte [edi], 0FFh		;dirty?
	jne	.sector_ok1
	mov	byte [edi], 0			;clean it :)
	sub	esi, edx			;start of sector
	mov	ebx, dword [FAT12_FAT_Start]	;first sector of FAT
	add	ebx, eax
	push	ebx			;start sector
	push	dword 1			;how many sectors to read
	push	esi			;buffer
	call	FDC_Read
.sector_ok1:
	popad
	
	movzx	eax, word [esi]
	mov	ebx, eax
	and	ebx, 0F000h
	
	cmp	edx, 0
	je	.noshift
	mov	ebx, eax
	and 	ebx, 0Fh
	ror	eax, 4
.noshift:
	mov	word [esi], bx	
	mov	byte [SaveNow], 1		;flag on
	
	and	eax, 0FFFh
	mov	ebx, eax			;for next scan
	cmp	eax, 0FFFh
	je	.finish
	jmp	.loop2
.finish:
	call	SaveLastSector
.error:
	popad
	pop	ebp
	ret	4

;saves the sector [LastSector] if [SaveNow] = 1
SaveLastSector:
	cmp	byte [SaveNow], 0
	je	.exit				;not now
	;save sector
	pushad
	mov	eax, dword [LastSector]
	mov	edi, dword [FAT12_FAT_Map]
	add	edi, eax
	mov	byte [edi], 0			;clean it :)
	
	mov	eax, dword [LastSector]
	movzx	ecx, word [edi+0Bh]		;bytes per sector
	xor	edx, edx
	mul	ecx
	mov	esi, dword [FAT12_FAT_Buffer]
	add	esi, eax
	
	push	dword [LastSector]	;start sector
	push	dword 1			;how many sectors to read
	push	esi			;buffer
	call	FDC_WriteSectors
	popad
.exit:
	ret

;input: filename to create
FAT12_CreateFile:
	push	ebp
	mov	ebp, esp
	add	ebp, 8	
	
	push	ebx
	push	esi
	push	edi
	
	push	dword [ebp]
	call	FAT12_FindFile
	cmp	eax, -1
	je	.ok1
	jmp	.exit		;already exists
.ok1:
	
	push	dword [ebp]		;filename
	push	dword TmpFileName2
	call	ExtractFileName
	
	mov	edi, dword TmpFileName2
	;TODO: change later to current directory
	mov	esi, dword [FAT12_Dir_Buffer]
.loop:	
	cmp	dword [esi], 0FFFFFFFFh	;sector not readed
	jne	.sector_ok
	
	pushad	
	mov	edi, dword [BootSector]
	movzx	ecx, word [edi+0Bh]		;bytes per sector
	mov	eax, esi
	mov	ebx, dword [FAT12_Dir_Buffer]
	sub	eax, ebx
	xor	edx, edx
	div	ecx
	mov	ebx, dword [FAT12_DIR_Start]	;first sector of FAT_Dir
	add	ebx, eax
	push	ebx			;start sector
	push	dword 1			;how many sectors to read
	push	esi			;buffer
	call	FDC_Read
	popad
	
.sector_ok:
	cmp	byte [esi], 0
	je	.doit
	cmp	byte [esi], 0E5h	;file is deleted
	je	.doit
	;TODO: check if ESI pass end of buffer
	add	esi, 32
	jmp	.loop
.doit:
;0-10    File name (8 bytes) with extension (3 bytes)
;11      Attribute - a bitvector. 
;Bit 0: read only. 
;Bit 1: hidden.
;Bit 2: system file. 
;Bit 3: volume label. 
;Bit 4: subdirectory.
;Bit 5: archive. 
;Bits 6-7: unused.
;12-21   Reserved (see below)
;22-23   Time (5/6/5 bits, for hour/minutes/doubleseconds)
;24-25   Date (7/4/5 bits, for year-since-1980/month/day)
;26-27   Starting cluster (0 for an empty file)
;28-31   Filesize in bytes
	push	dword TmpFileName2
	push	esi
	call	FAT12_StrToFileName
	;mov	word [esi+22], time
	;mov	word [esi+24], date
	mov	word [esi+26], 0		;starting cluster
	mov	dword [esi+28], 0		;filesize
	
	pushad
	mov	edi, dword [BootSector]
	movzx	ecx, word [edi+0Bh]		;bytes per sector
	mov	eax, esi
	mov	ebx, dword [FAT12_Dir_Buffer]
	sub	eax, ebx
	xor	edx, edx
	div	ecx
	;eax=sector
	sub	esi, edx			;start of sector
	mov	ebx, dword [FAT12_DIR_Start]	;first sector of FAT
	add	ebx, eax
	
	push	ebx			;start sector
	push	dword 1			;how many sectors to write
	push	esi			;buffer
	call	FDC_WriteSectors
	popad
	
.exit:	
	pop	edi
	pop	esi
	pop	ebx
	pop	ebp
	ret	4
	
	
;input: full path file name (asciiz)
;TODO: for now only filename is given
;later make a full path scan
FAT12_FindFile:
	push	ebp
	mov	ebp, esp
	add	ebp, 8	
	
	push	esi
	push	edi
	
	push	dword [ebp]		;filename
	push	dword TmpFileName2
	call	ExtractFileName
	
	mov	edi, dword TmpFileName2
	;TODO: change later to current directory
	mov	esi, dword [FAT12_Dir_Buffer]
.loop:	
	cmp	dword [esi], 0FFFFFFFFh	;sector not readed
	jne	.sector_ok
	
	pushad	
	mov	edi, dword [BootSector]
	movzx	ecx, word [edi+0Bh]		;bytes per sector
	mov	eax, esi
	mov	ebx, dword [FAT12_Dir_Buffer]
	sub	eax, ebx
	xor	edx, edx
	div	ecx
	mov	ebx, dword [FAT12_DIR_Start]	;first sector of FAT_Dir
	add	ebx, eax
	push	ebx			;start sector
	push	dword 1			;how many sectors to read
	push	esi			;buffer
	call	FDC_Read
	popad
	
.sector_ok:
	mov	eax, -1
	cmp	byte [esi], 0
	je	.exit
	cmp	byte [esi], 0E5h	;file is deleted
	je	.next
	
	movzx	eax, byte [esi+11]	;attrib
	and	eax, 1000b
	cmp	eax, 0
	jne	.next			;volume label
	
	movzx	eax, byte [esi+11]	;attrib directory
	and	eax, 10000b
	cmp	eax, 0
	jne	.next
	
	;push	esi
	;call	Print
	;call	PrintCRLF
	
	push	esi
	push	dword TmpFileName
	call	FAT12_FilenameToStr
	
	push	dword TmpFileName
	push	edi
	call	StrCmp
	cmp	eax, 0
	jne	.next
	
	movzx	eax, word [esi+26]		;starting cluster
	jmp	.exit	
.next:
	;TODO: check if ESI pass end of buffer
	add	esi, 32
	jmp	.loop
.exit:	
	pop	edi
	pop	esi
	pop	ebp
	ret	4
	
;input: current sector (of FAT, not real sector)
FAT12_FindNextSector:
	push	ebp
	mov	ebp, esp
	add	ebp, 8	
	
	push	ebx
	push	ecx
	push	edx
	push	esi
	push	edi
	
	xor	edx, edx
	mov	eax, dword [ebp]
	mov	ebx, 15
	mul	ebx
	xor	edx, edx
	mov	ebx, 10
	div	ebx
	and	edx, 1b
	rol	edx, 2
	;result in eax, edx = 0 or 1 to shift left result	
	mov	esi, dword [FAT12_FAT_Buffer]
	add	esi, eax
	
	;read sector
	pushad
	mov	edi, dword [BootSector]
	movzx	ecx, word [edi+0Bh]		;bytes per sector
	mov	eax, esi
	mov	ebx, dword [FAT12_FAT_Buffer]
	sub	eax, ebx
	xor	edx, edx
	div	ecx
	;eax=sector
	mov	edi, dword [FAT12_FAT_Map]
	add	edi, eax
	cmp 	byte [edi], 0FFh		;dirty?
	jne	.sector_ok
	mov	byte [edi], 0			;clean it :)
	sub	esi, edx			;start of sector
	mov	ebx, dword [FAT12_FAT_Start]	;first sector of FAT
	add	ebx, eax
	push	ebx			;start sector
	push	dword 1			;how many sectors to read
	push	esi			;buffer
	call	FDC_Read
.sector_ok:
	popad
	
	movzx	eax, word [esi]
	cmp	edx, 0
	je	.noshift
	ror	eax, 4
.noshift:
	and	eax, 0FFFh
	cmp	eax, 0FFFh
	jne	.exit
	mov	eax, 0FFFFFFFFh
.exit:
	pop	edi
	pop	esi
	pop	edx
	pop	ecx
	pop	ebx
	pop	ebp
	ret	4
	
;todo:
;report volume label
;report serial number
;report size on disk
;report free space
FAT12_DirList:
	push	ebp
	mov	ebp, esp
	add	ebp, 8	
	
	push	ebx
	push	ecx
	push	edx
	push	esi
	
	push	dword [ebp]
	push	dword sDirListAt
	call	Print
	
	mov	dword [DirTotalSize], 0
	mov	dword [DirTotalFiles], 0
	mov	dword [DirTotalDirs], 0	
	
	mov	esi, dword [FAT12_Dir_Buffer]	
.loop:	
	cmp	dword [esi], 0FFFFFFFFh	;sector not readed
	jne	.sector_ok
	
	pushad	
	mov	edi, dword [BootSector]
	movzx	ecx, word [edi+0Bh]		;bytes per sector
	mov	eax, esi
	mov	ebx, dword [FAT12_Dir_Buffer]
	sub	eax, ebx
	xor	edx, edx
	div	ecx
	mov	ebx, dword [FAT12_DIR_Start]	;first sector of FAT_Dir
	add	ebx, eax
	push	ebx			;start sector
	push	dword 1			;how many sectors to read
	push	esi			;buffer
	call	FDC_Read
	popad
	
.sector_ok:
	cmp	byte [esi], 0
	jne	.next1
	jmp	.exit
.next1:
	cmp	byte [esi], 0E5h	;file is deleted
	jne	.here1
	jmp	.next	
.here1:	
	;Attribute - a bitvector. 
	;Bit 0: read only. 
	;Bit 1: hidden.
	;Bit 2: system file. 
	;Bit 3: volume label. 
	;Bit 4: subdirectory.
	;Bit 5: archive. 
	;Bits 6-7: unused.
	movzx	eax, byte [esi+11]	;attrib
	and	eax, 1000b
	cmp	eax, 0
	je	.here2
	jmp	.next			;volume label
.here2:
	
	movzx	eax, byte [esi+11]	;attrib
	and	eax, 10000b
	cmp	eax, 0
	je	.here3
	jmp	.isDir
.here3:
	
	push	esi	
	
	push	esi
	push	dword TmpFileName
	call	FAT12_FilenameToStr
	
	inc	dword [DirTotalFiles]
	;todo:add size on disk
	mov	eax, dword [esi+28]	;filesize
	add	dword [DirTotalSize], eax
	
;22-23   Time (5/6/5 bits, for hour/minutes/doubleseconds)
	movzx	eax, word [esi+22]
	and	eax, 11111b
	shl	eax, 1			;*2
	push	eax
	
	movzx	eax, word [esi+22]
	and	eax, 11111100000b
	ror	eax, 5
	push	eax

	movzx	eax, word [esi+22]
	and	eax, 1111100000000000b
	ror	eax, 11
	push	eax	

;24-25   Date (7/4/5 bits, for year-since-1980/month/day)
	movzx	eax, word [esi+24]
	and	eax, 1111111000000000b
	ror	eax, 9
	add	eax, 1980
	push	eax
	
	movzx	eax, word [esi+24]
	and	eax, 111100000b
	ror	eax, 5
	push	eax
	
	movzx	eax, word [esi+24]
	and	eax, 11111b
	push	eax
	
	push	dword [esi+28]		;filesize
	push	dword TmpFileName
	push	dword sFile
	call	Print
	pop	esi
	jmp	.next	
.isDir:
	inc	dword [DirTotalDirs]
	push	esi
	
	push	esi
	push	dword TmpFileName
	call	FAT12_FilenameToStr
	
	push	dword TmpFileName
	push	dword sDir
	call	Print
	
	pop	esi
.next:
	add	esi, 32
	jmp	.loop
.exit:
	mov	byte [CurrentDirectoryEntry], 0
	
	push	dword [DirTotalSize]	
	push	dword [DirTotalDirs]
	push	dword [DirTotalFiles]
	push	dword DirReport
	call	Print
	
	pop	esi
	pop	edx
	pop	ecx
	pop	ebx
	pop	ebp
	ret	4
	
FAT12_GetInfo:
	push	esi	
	push	dword [fdcbuf]
	push	dword [BootSector]
	push	dword 512
	call	MemCpy
	
	mov	esi, dword [BootSector]
	mov	eax, dword [esi+27h]		;Serial number
	push	eax	
	movzx	eax, byte [esi+26h]		;Ext Boot Signature
	push	eax
	;bypassed 25h
	movzx	eax, byte [esi+24h]		;Drive Number
	push	eax
	mov	eax, dword [esi+20h]		;Total Sectors Big
	push	eax
	mov	eax, dword [esi+1Ch]		;Hidden Sectors
	push	eax
	movzx	eax, word [esi+1Ah]		;Heads Per Cylinder
	push	eax
	movzx	eax, word [esi+18h]		;Sectors Per Track
	push	eax
	movzx	eax, word [esi+16h]		;Sectors Per FAT
	push	eax
	movzx	eax, byte [esi+15h]		;Media
	push	eax
	movzx	eax, word [esi+13h]		;Total Sectors	
	push	eax
	movzx	eax, word [esi+11h]		;Root Entries	
	push	eax
	movzx	eax, byte [esi+10h]		;Number Of FATs	
	push	eax
	movzx	eax, word [esi+0Eh]		;Reserved Sectors
	push	eax
	movzx	eax, byte [esi+0Dh]		;Sectors Per Cluster	
	push	eax
	movzx	eax, word [esi+0Bh]		;Bytes Per Sector					
	push	eax	
	push	dword FAT12_Info
	call	Print
	
	;add	esi, 3				;OEM name
	;push	esi
	;push	dword 8
	;call	PrintC
	
	push	dword FAT12_VolumeLabel
	call	Print	
	add	esi, 2Bh			;volume label
	push	esi
	push	dword 11
	call	PrintC
	call	PrintCRLF
	
	push	dword FAT12_FileSystem
	call	Print
	add	esi, 11				;File system
	push	esi
	push	dword 8
	call	PrintC	
	call	PrintCRLF
	
	pop	esi
	ret