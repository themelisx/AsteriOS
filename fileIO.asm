;Higher level API for storage devices

;StorageDeviceArray struct
;Flags			db	?
;Type			db	?
;DriverAddress		dd	?
;FSAddress		dd	?
;MediaInfo		dd	?

;OemName			db	"        "      ; 0x03
;BytesPerSector		dw	?               ; 0x0B
;SectorsPerCluster	db	?               ; 0x0D
;ReservedSectors		dw	?               ; 0x0E
;NumberOfFATs		db	?               ; 0x10
;RootEntries		dw	?               ; 0x11
;TotalSectors		dw	?               ; 0x13
;Media			db	?               ; 0x15
;SectorsPerFAT		dw	?               ; 0x16
;SectorsPerTrack		dw	?               ; 0x18
;HeadsPerCylinder	dw	?               ; 0x1A
;HiddenSectors		dd	?               ; 0x1C
;TotalSectorsBig		dd	?               ; 0x20
;DriveNumber		db	?               ; 0x24
;Unused			db	?               ; 0x25
;ExtBootSignature	db	?               ; 0x26
;SerialNumber		dd	?               ; 0x27
;VolumeLabel		db	"           "   ; 0x2B
;FileSystem		db	"        "      ; 0x36
;null			db	0	;null terminated array
;(60 bytes)
Init_FileIO:
	%ifdef DEBUG
	push	Debug_FileIO_Init
	call	Print
	%endif

	call	RegisterFileIOFunctions
	
	push	dword OpenFilesArraySize
	call	MemAlloc
	mov	dword [OpenFilesArray], eax
	
	push	eax
	push	dword OpenFilesArraySize
	push	dword 0
	call	MemSet			;clean up array			
		
	push	dword 512
	call	MemAlloc
	mov	dword [tmpbuf], eax
	
	push	dword StorageDeviceArraySize
	call	MemAlloc
	mov	dword [StorageDeviceArray], eax
	
	push	eax
	push	dword StorageDeviceArraySize
	push	dword 0
	call	MemSet			;clean up array
	
	push	esi	
	;CurrentDrive has the boot drive letter
	mov	esi, CurrentDirectory
	mov	byte [esi], '\'
	mov	byte [esi+1], 0		
	pop	esi
	
	ret
	
RegisterFileIOFunctions:
	push	dword sOpenFile
	push	dword OpenFile
	call	SetProcAddress
	
	push	dword sIsFileOpen
	push	dword IsFileOpen
	call	SetProcAddress
	
	push	dword sCloseFile
	push	dword CloseFile
	call	SetProcAddress
	
	push	dword sLoadFile
	push	dword LoadFile
	call	SetProcAddress
	
	push	dword sGetFileSize
	push	dword GetFileSize
	call	SetProcAddress
	
	push	dword sDirList
	push	dword DirList
	call	SetProcAddress
	
	push	dword sGetCurrentDirectory
	push	dword GetCurrentDirectory
	call	SetProcAddress
	
	push	dword sCreateFile
	push	dword CreateFile
	call	SetProcAddress
	ret

;public
;input:
;1.param: Drive number (0=A, 1=B...)
UnRegisterStorageDevice:
	push	ebp
	mov	ebp, esp
	add	ebp, 8	
	
	push	ebx
	push	ecx
	push	edx
	push	edi
	
	%ifdef DEBUG
	push	dword [ebp]
	push	Debug_UnRegisterStorageDevice
	call	Print
	%endif

	mov	edi, dword [StorageDeviceArray]
	mov	eax, [ebp]		;drive number
	mov	ebx, STORAGE_DEVICE_STRUCT_SIZE
	xor	edx, edx
	mul	ebx
	add	edi, eax
	
	mov	eax, dword [edi+10]	;media info
	push	eax
	call	MemFree
	
	mov	eax, 0
	mov	ecx, STORAGE_DEVICE_STRUCT_SIZE
	rep	stosb

	pop	edi
	pop	edx
	pop	ecx
	pop	ebx
	pop	ebp
	ret 	4

;public
;input:
;1.param: Drive number (0=A, 1=B...)
;2.param: Drive Type
;3.param: driver address
;4.param: FS address
RegisterStorageDevice:
	push	ebp
	mov	ebp, esp
	add	ebp, 8	
	
	%ifdef DEBUG
	push	dword [ebp]
	push	dword [ebp+4]
	push	dword [ebp+8]
	push	dword [ebp+12]
	push	Debug_RegisterStorageDevice
	call	Print
	%endif

	push	edi
	push	edx
	push	ebx
	
	mov	edi, dword [StorageDeviceArray]
	mov	eax, [ebp+12]		;drive number
	mov	ebx, STORAGE_DEVICE_STRUCT_SIZE
	xor	edx, edx
	mul	ebx
	add	edi, eax
	
	;0 registered
	;1 mounted
	;2 removable
	;3 read-only
	;4,5,6,7 unused
	mov	eax, 11b		;set flag register, mounted
	mov	byte [edi], al	
	
	inc	edi	
	mov	eax, [ebp+8]		;drive type
	mov	byte [edi], al
	
	inc	edi	
	mov	eax, [ebp+4]		;driver address
	mov	dword [edi], eax
	
	add	edi, 4
	mov	eax, [ebp]		;FS address
	mov	dword [edi], eax
	
	add	edi, 4
	push	dword MediaInfoSize
	call	MemAlloc
	mov	dword [edi], eax	;media info	
	
	pop	ebx
	pop	edx
	pop	edi
	pop	ebp
	ret	4*4
	
GetCurrentDirectory:
	mov	eax, dword CurrentDrive		;drive and directory
	ret

;param: full path to make dirlist
DirList:
	push	ebp
	mov	ebp, esp
	add	ebp, 8
	
	push	esi
	mov	esi, [ebp]		;fullpath
	movzx	eax, byte [esi]	
	sub	al, 'a'
	;mov	al, 0
	call	GetDriveFS
	push	dword FS_DIRLIST
	push	dword [ebp]
	call	eax			;FS
	pop	esi
	pop	ebp
	ret	4

;public
;input param: fullpath filename (ASCIIZ)
;TODO:check if filename > max path name
OpenFile:
	push	ebp
	mov	ebp, esp
	add	ebp, 8
	
	push	esi
	push	ebx
	
	mov	esi, dword [ebp]
	cmp	byte [esi+1], ':'
	je	.next
	;use current path
	mov	esi, dword [tmpbuf]
	push	dword CurrentDrive
	push	esi
	call	StrCpy
	add	esi, eax
	push	dword [ebp]
	push	esi
	call	ToLower
	jmp	.next1
.next:
	push	dword [ebp]
	push	dword [tmpbuf]
	call	ToLower
.next1:	
	%ifdef DEBUG
	push	dword [tmpbuf]
	push	dword Debug_OpenFile
	call	Print
	%endif

	mov	esi, dword [tmpbuf]
	mov	al, byte [esi]	
	sub	al, 'a'	
	;mov	al, 0
	call	IsDriveMounted
	mov	ebx, -1		;DRIVE_NOT_MOUNTED
	cmp	al, 1
	jne	.exit
	
	push	dword [tmpbuf]
	call	IsFileOpen
	mov	ebx, eax		;file handle
	cmp	eax, -1
	jne	.exit			;already open
	
	push	dword [tmpbuf]
	call	FileExists
	mov	ebx, -1		;FILE_NOT_EXIST
	cmp	eax, -1
	je	.exit
	
	push	dword [tmpbuf]
	call	SetOpenFile
	;returns in eax, -1 if no empty entry, orelse file handle
	mov	ebx, eax

.exit:		
	mov	eax, ebx		;error code or handle
	pop	ebx
	pop	esi
	pop	ebp
	ret	4
	
;input:full path file name (already lowercase)
;returns in eax, file handle or -1 if not free entry
SetOpenFile:
	push	ebp
	mov	ebp, esp
	add	ebp, 8
	
	push	esi
	push	edi
	push	ecx
	
	mov	edi, dword [OpenFilesArray]
	mov	ecx, 0
.loop:
	cmp	ecx, MAX_OPEN_FILES
	jne	.next1
	jmp	.donothing
.next1:
	cmp	byte [edi], 0
	je	.doit
	add	edi, OPEN_FILE_STRUCT_SIZE
	inc	ecx
	jmp	.loop
.doit:
	push	ecx		;keep handle
	
	push	dword [ebp]	;filename
	push	edi
	call	StrCpy
	
	mov	esi, dword [ebp]
	mov	al, byte [esi]
	sub	al, 'a'
	;mov	al, 0
	push	eax			;save drive number
	
;name
;driver
;FS
;File pointer
;size
;memory address
	call	GetDriveDriver
	mov	dword [edi + FILE_NAME_SIZE], eax	;Driver address
	
	pop	eax			;restore drive number
	call	GetDriveFS
	mov	dword [edi + FILE_NAME_SIZE + 4], eax	;FS address
	
	mov	dword [edi + FILE_NAME_SIZE + 8], 0	;file pointer
	
	push	dword FS_GET_FILE_SIZE
	push	dword [ebp]		;file name
	call	eax			;FS
	mov	dword [edi + FILE_NAME_SIZE + 12], eax	;size
	mov	dword [edi + FILE_NAME_SIZE + 16], 0	;memory (loaded). will fill later
	
	%ifdef DEBUG
	push	dword [edi + FILE_NAME_SIZE+16]	;loaded address
	push	dword [edi + FILE_NAME_SIZE+12]	;size
	push	dword [edi + FILE_NAME_SIZE+8]	;Pointer
	push	dword [edi + FILE_NAME_SIZE+4]	;FS
	push	dword [edi + FILE_NAME_SIZE]	;driver
	push	edi
	push	dword Debug_SetOpenFile
	call	Print
	%endif
	
	pop	eax		;restore handle
	jmp	.exit
.donothing:
	mov	eax, -1
.exit:
	pop	ecx
	pop	edi
	pop	esi
	pop	ebp
	ret	4

;input:full path file name (already lowercase)
;returns in eax -1 if not open, or handle
IsFileOpen:
	push	ebp
	mov	ebp, esp
	add	ebp, 8
	
	push	esi
	push	edi
	push	ecx
	
	mov	esi, [ebp]
	mov	edi, dword [OpenFilesArray]
	mov	ecx, 0
.loop:
	cmp	ecx, MAX_OPEN_FILES
	je	.exit
	push	esi
	push	edi
	call	StrCmp
	inc	ecx
	add	edi, OPEN_FILE_STRUCT_SIZE
	cmp	eax, 0
	jne	.loop
	
	dec	ecx
	mov	eax, ecx
	jmp	.exit1	
.exit:
	mov	eax, -1		
.exit1:

	%ifdef DEBUG
	push	eax
	push	eax
	push	dword [ebp]
	push	dword Debug_IsFileOpen
	call	Print
	pop	eax
	%endif

	pop	ecx
	pop	edi
	pop	esi
	pop	ebp
	ret	4
	

;input al: drive number (0=A,... 2=C)
;returns 1 if ok, 0 if not mounted
IsDriveMounted:
	push	esi
	push	ebx
	push	edx
	
	and	eax, 11111b			;max drive = 24
	;push	eax				;save for debug
	mov	esi, dword [StorageDeviceArray]
	mov	ebx, STORAGE_DEVICE_STRUCT_SIZE
	xor	edx, edx
	mul	ebx
	add	esi, eax
	mov	al, byte [esi]
	and	eax, 10b			;keep flag
	ror	eax, 1
	;pop	ebx				;restore of eax for debug
	
	;push	eax	
	;push	eax				;ret value
	;push	ebx				;drive num
	;push	dword Debug_IsDriveMounted
	;call	PrintDebug
	;pop	eax
	
	pop	edx
	pop	ebx
	pop	esi	
	ret
	

;public	
;input:
;1st param: file handle
;2nd param: buffer for readed data
;3rd param: size in bytes to read
LoadFile:
	push	ebp
	mov	ebp, esp
	add	ebp, 8	
	
	%ifdef DEBUG
	push	dword [ebp]
	push	dword [ebp+4]
	push	dword [ebp+8]
	push	dword Debug_LoadFile
	call	Print
	%endif
	
	push	ecx
	push	edx
	push	edi	
		
	mov	ecx, [ebp+8]			;handle
	mov	edi, dword [OpenFilesArray]
	mov	eax, OPEN_FILE_STRUCT_SIZE
	xor	edx, edx
	mul	ecx
	add	edi, eax
	
;name
;driver
;FS
;File pointer
;size
;memory address
	mov	eax, dword [ebp + 4]			;buffer
	mov	dword [edi + FILE_NAME_SIZE + 16], eax	;save loaded address
	
	mov	eax, dword [edi + FILE_NAME_SIZE + 4]	;FS address
	mov	dword [FS_Addr], eax
	
	;this function returns the current sector of file
	;it depends on file pointer position
	push	dword FS_GET_FILE_SECTOR
	push	edi			;file name
	call	dword [FS_Addr]
	;returns in eax the linear sector
	mov	dword [CurrentSector], eax	
	mov	eax, dword [edi + FILE_NAME_SIZE]	;Driver address
	mov	dword [DRV_Addr], eax
	
	mov	esi, dword [ebp+4]
.loop:	
	mov	eax, dword [CurrentSector]
	add	eax, dword [FirstRealSector]
	push	dword IO_READ
	push	eax				;sector
	push	esi
	call	dword [DRV_Addr]
	
	;todo:fix this
	add	esi, 512
	
	;this function returns the current sector of file
	;it depends on file pointer position
	push	dword FS_GET_FILE_NEXT_SECTOR
	push	dword [CurrentSector]
	call	dword [FS_Addr]
	;returns in eax the linear sector
	mov	dword [CurrentSector], eax
	cmp	eax, 0FFFFFFFFh
	je	.exit
	jmp	.loop
.exit:	
	pop	edi
	pop	edx
	pop	ecx
	pop	ebp
	ret	3*4
	
DeleteFile:
	push	ebp
	mov	ebp, esp
	add	ebp, 8	
	
	push	esi
	mov	esi, dword [ebp]
	cmp	byte [esi+1], ':'
	je	.next
	;use current path
	mov	esi, dword [tmpbuf]
	push	dword CurrentDrive
	push	esi
	call	StrCpy
	add	esi, eax
	push	dword [ebp]
	push	esi
	call	ToLower
	jmp	.next1
.next:
	push	dword [ebp]
	push	dword [tmpbuf]
	call	ToLower
.next1:

	push	dword [tmpbuf]
	call	FileExists
	cmp	eax, -1
	je	.exit			;not exists
	
	mov	esi, dword [tmpbuf]
	mov	al, byte [esi]
	sub	al, 'a'
	;mov	al, 0
	call	GetDriveFS
	push	dword FS_DELETE_FILE
	push	dword [tmpbuf]		;file name
	call	eax
	
.exit:
	pop	esi
	pop	ebp
	ret	4
	

;input: fullpath name or name
CreateFile:
	push	ebp
	mov	ebp, esp
	add	ebp, 8	
	
	push	esi
	mov	esi, dword [ebp]
	cmp	byte [esi+1], ':'
	je	.next
	;use current path
	mov	esi, dword [tmpbuf]
	push	dword CurrentDrive
	push	esi
	call	StrCpy
	add	esi, eax
	push	dword [ebp]
	push	esi
	call	ToLower
	jmp	.next1
.next:
	push	dword [ebp]
	push	dword [tmpbuf]
	call	ToLower
.next1:

	push	dword [tmpbuf]
	call	FileExists
	cmp	eax, -1
	jne	.exit			;already exists
	
	mov	esi, dword [tmpbuf]
	mov	al, byte [esi]
	sub	al, 'a'
	;mov	al, 0
	call	GetDriveFS
	push	dword FS_CREATE_FILE
	push	dword [tmpbuf]		;file name
	call	eax
	
.exit:
	pop	esi
	pop	ebp
	ret	4
	
;public
WriteFile:
	ret

;public	
;input:full path file name
;returns in eax -1 if not open
CloseFile:
	push	ebp
	mov	ebp, esp
	add	ebp, 8	
	
	push	esi
	push	edi
	push	edx
	
	mov	esi, dword [ebp]
	cmp	byte [esi+1], ':'
	je	.next
	;use current path
	mov	esi, dword [tmpbuf]
	push	dword CurrentDrive
	push	esi
	call	StrCpy
	add	esi, eax
	push	dword [ebp]
	push	esi
	call	ToLower
	jmp	.next1
.next:
	push	dword [ebp]
	push	dword [tmpbuf]
	call	ToLower
.next1:
	%ifdef DEBUG
	push	dword [tmpbuf]
	push	dword Debug_CloseFile
	call	Print
	%endif

	push	dword [tmpbuf]
	call	IsFileOpen
	cmp	eax, -1
	je	.exit
	
	mov	edi, dword [OpenFilesArray]
	mov	ecx, OPEN_FILE_STRUCT_SIZE
	xor	edx, edx
	mul	ecx
	add	edi, eax
	
	push	edi
	push	dword OPEN_FILE_STRUCT_SIZE
	push	dword 0
	call	MemSet
	
	xor	eax, eax	
.exit:	
	pop	edx
	pop	edi
	pop	esi
	pop	ebp
	ret	4

;public	
;1st param: file handle
;2nd param: file pointer
;returns in eax the new file pointer
SetFilePointer:
	push	ebp
	mov	ebp, esp
	add	ebp, 8
	
	push	ecx
	push	edx
	push	edi
	
	mov	ecx, [ebp+4]	
	mov	edi, dword [OpenFilesArray]
	mov	eax, OPEN_FILE_STRUCT_SIZE
	xor	edx, edx
	mul	ecx
	add	edi, eax
;name
;driver
;FS
;File pointer
;size
;memory address
	add	edi, FILE_NAME_SIZE + 8
	mov	eax, [ebp]			;file pointer
	;TODO: check if pointer > file size
	mov	dword [edi], eax
	
	pop	edi
	pop	edx
	pop	ecx
	pop	ebp
	ret	2*4

;public	
;input: full path file name
;returns eax 0=exists, 1=not exists
FileExists:
	push	ebp
	mov	ebp, esp
	add	ebp, 8
	
	push	esi
	
	push	dword [ebp]
	push	dword [tmpbuf]
	call	ToLower
	mov	esi, dword [tmpbuf]
	mov	al, byte [esi]
	sub	al, 'a'
	;mov	al, 0
	call	GetDriveFS
	
	push	dword FS_FIND_FILE
	push	dword [tmpbuf]
	call	eax			;FS
	;returns in eax, 0=exists, -1=not exists
	
	%ifdef DEBUG
	push	eax
	push	eax
	push	dword [ebp]
	push	dword Debug_FileExists
	call	Print
	pop	eax
	%endif
	
	pop	esi	
	pop	ebp
	ret	4

;input:al=drive number
GetDriveDriver:
	push	esi
	push	ebx
	push	edx
	
	and	eax, 11111b
	;push	eax				;save for debug
	
	mov	esi, dword [StorageDeviceArray]
	
	mov	ebx, STORAGE_DEVICE_STRUCT_SIZE
	xor	edx, edx
	mul	ebx
	add	esi, eax
	mov	eax, dword [esi+2]		;FS address
	
	;pop	ebx				;restore for debug
	
	;push	eax
	;push	eax
	;push	ebx
	;push	dword Debug_GetDriveDriver
	;call	PrintDebug
	;pop	eax
	
	pop	edx
	pop	ebx
	pop	esi
	ret

;input:al=drive number
GetDriveFS:
	push	esi
	push	ebx
	push	edx
	
	and	eax, 11111b
	;push	eax
	
	mov	esi, dword [StorageDeviceArray]
	and	eax, 0FFh
	mov	ebx, STORAGE_DEVICE_STRUCT_SIZE
	xor	edx, edx
	mul	ebx
	add	esi, eax
	mov	eax, dword [esi+6]		;FS address
	
	;pop	ebx
	
	;push	eax
	;push	eax
	;push	ebx
	;push	dword Debug_GetDriveFS
	;call	PrintDebug
	;pop	eax
	
	pop	edx
	pop	ebx
	pop	esi
	ret

;public
;file must be open
;input: file handle
;returns in eax the file size
GetFileSize:
	push	ebp
	mov	ebp, esp
	add	ebp, 8
	
	push	ecx
	push	edx
	push	edi
	
	mov	ecx, [ebp]	
	mov	edi, dword [OpenFilesArray]
	mov	eax, OPEN_FILE_STRUCT_SIZE
	xor	edx, edx
	mul	ecx
	add	edi, eax
;name
;driver
;FS
;File pointer
;size
;memory address
	mov	eax, dword [edi + FILE_NAME_SIZE + 12]	;file size
	
	pop	edi
	pop	edx
	pop	ecx
	pop	ebp
	ret	4

	