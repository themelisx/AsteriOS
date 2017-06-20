;Display routines
Init_Display:
	%ifdef DEBUG
	push	dword InitDisplay
	call	Print
	%endif
	
	push	edx
	
	movzx	eax, word [VESAseg]
	shl	eax, 4
	add	ax, word [VESAoff]	
	cmp	eax, 0
	jne	.next	
	jmp	.error
.next:
	movzx	eax, word [VesaVer]	
	cmp	ah, 2			;Is Vesa 2.0+ ?
	jnb	.Vesa2
	
	movzx	eax, word [VESAseg]
	shl	eax, 4
	add	ax, word [VESAoff]
	push	eax			;name
	
	movzx	eax, word [VesaVer]
	and	eax, 0FFh
	;push	eax
	movzx	eax, word [VesaVer]
	xchg	al, ah
	and	eax, 0FFh
	;push	eax	
		
	;push	dword Vesa1x
	jmp	.exit
	
.Vesa2:	
	movzx	eax, word [VESASV]
	mov	edx, eax
	and	eax, 0FFh
	;push	eax
	xchg 	dl, dh
	and	edx, 0FFh
	;push	edx
	
	movzx	eax, word [VESAPRseg]
	shl	eax, 4
	add	ax, word [VESAPRoff]
	;push	dword eax
	
	movzx	eax, word [VesaMem]
	shl	eax, 6			;eax=eax*64
	shr	eax, 10			;eax=eax/1024
	;push	eax
	
	movzx	eax, word [VESAPNseg]
	shl	eax, 4
	add	ax, word [VESAPNoff]
	;push	dword eax
	
	movzx	eax, word [VESAseg]
	shl	eax, 4
	add	ax, word [VESAoff]
	push	eax
	
	movzx	eax, word [VESAVNseg]
	shl	eax, 4
	add	ax, word [VESAVNoff]
	;push	eax
	
	movzx	eax, word [VesaVer]
	and	eax, 0FFh
	;push	eax
	movzx	eax, word [VesaVer]
	xchg	al, ah
	and	eax, 0FFh
	;push	eax	
		
	;push	dword VesaStr
.exit:
	;name already pushed
	push	dword 0		;driver
	push	dword 0
	push	dword 0
	push	dword 0		;irq ?
	push	dword DEVICE_VGA
	push	dword 0		;bit 1 : (1=enable)
	call	RegisterDevice
.error:
	pop	edx

	push	dword sPrint
	push	dword Print
	call	SetProcAddress
	
	push	dword sPrintC
	push	dword PrintC
	call	SetProcAddress
	
	push	dword sPrintChar
	push	dword PrintChar
	call	SetProcAddress
	
	push	dword sPrintHex
	push	dword PrintHex
	call	SetProcAddress
	
	push	dword sPrintCRLF
	push	dword PrintCRLF
	call	SetProcAddress
	
	push	dword sPrintXY
	push	dword PrintXY
	call	SetProcAddress
	
	push	dword sShowClock
	push	dword ShowClock
	call	SetProcAddress
	
	push	dword sPrintMemoryMap
	push	dword PrintMemoryMap
	call	SetProcAddress
	
	push	dword sPrintIRQList
	push	dword PrintIRQList
	call	SetProcAddress
	
	push	dword sDeleteCurrentChar
	push	dword DeleteCurrentChar
	call	SetProcAddress
	
	push	dword sPrintTextFile
	push	dword PrintTextFile
	call	SetProcAddress
	
	push	dword sPrintHexView
	push	dword PrintHexView
	call	SetProcAddress
	
	ret
	
DeleteCurrentChar:
	;delete char from screen
	sub 	dword [Cursor_Pos], FONT_WIDTH
	mov	al, ' '
	call	PrintChar
	sub 	dword [Cursor_Pos], FONT_WIDTH
	mov	byte [VgaNeedsUpdate], 1
	ret

;1st: buffer
;2nd: size
PrintTextFile:
	push	ebp
	mov	ebp, esp
	add	ebp, 8
	
	push	ebx
	push	ecx
	push	edx
	push	esi
	push	edi
	
	mov	byte [MoveRealCursor], 0
	
	push	dword 80+1
	call	MemAlloc
	mov	edi, eax
	mov	dword [tmp], eax
	
	mov	ecx, dword [ebp]
	inc	ecx
	xor	edx, edx
	xor	ebx, ebx
	mov	esi, dword [ebp+4]
.loop:
	dec	ecx
	jz	.print_it
	inc	edx	
	mov	al, byte [esi]
	
	cmp	edx, 80+1	;chars per line
	je	.next
	mov	byte [edi], al
	inc	edi
.next:
	inc	esi
	cmp	al, 13
	je	.print_it
	jmp	.loop
.print_it:
	mov	byte [edi], 0
	push	dword [tmp]
	call	PrintSimple
	cmp	ecx, 0
	je	.exit
	;inc	ebx
	;cmp	ebx, MAX_LINES-1
	;jne	.next1
	;xor	ebx, ebx
	;push	dword sMore
	;call	Print
	;call	GetKey
	;call	PrintCRLF
;.next1:
	xor	edx, edx
	mov	edi, dword [tmp]
	jmp	.loop
.exit:
	mov	byte [MoveRealCursor], 1
	call	PrintCRLF
	
	push	dword [tmp]
	call	MemFree
	
	pop	edi
	pop	esi
	pop	edx
	pop	ecx
	pop	ebx	
	pop	ebp
	ret	2*4

	
PrintIRQList:
	push	ebx
	push	ecx	
	push	esi
	
	mov	ecx, 20h	
.loop:
	push	ecx
	call	GetInterruptAddress
	
	cmp	eax, 0
	je	.next
	
	mov	ebx, eax
	
	push	eax
	push	ecx
	push	dword IRQAndAddress
	call	Print
	
		push	ecx
		mov	ecx, MAX_OPEN_FILES
		mov	esi, dword [OpenFilesArray]
	.loopfiles:		
		cmp	byte [esi], 0
		je	.nextfile
		
		mov	eax, dword [esi + FILE_NAME_SIZE+16]	;loaded address
		cmp	ebx, eax
		jl	.nextfile
		add	eax, dword [esi + FILE_NAME_SIZE+12]	;size
		cmp	ebx, eax
		jg	.nextfile
		
		push	esi
		push	dword Memory_Table_EntryOwner
		call	Print
		jmp	.ownerfound
		
	.nextfile:
		add	esi, OPEN_FILE_STRUCT_SIZE
		dec	ecx
		jnz	.loopfiles
		call	PrintCRLF
	.ownerfound:
		pop	ecx
.next:
	
	inc	ecx
	cmp	ecx, 30h
	jne	.loop
	
	pop	esi
	pop	ecx
	pop	ebx
	ret	

;1st param: buffer
;2nd param: length to print out
PrintHexView:
	push	ebp
	mov	ebp, esp
	add	ebp, 8
	
	mov	byte [MoveRealCursor], 0
	
	%ifdef DEBUG
	push	dword [ebp]
	push	dword [ebp+4]
	push	Debug_PrintHexView
	call	Print
	%endif
	
	push	esi
	push	ecx
	push	ebx
	push	edx
		
	mov	esi, [ebp+4]	
	mov	ecx, [ebp]
	mov	edx, esi
	xor	ebx, ebx
.loop:	
	movzx	eax, byte [esi]
	push	eax
	call	PrintHex
	mov	al, ' '
	call	PrintChar
	inc	ebx
	cmp	ebx, 16
	jne	.next

.next1:	
	cmp	ecx, 0
	jne	.next2
	dec	esi		;for the last line (if < 16 chars)
.next2:
	pushad
	mov	al, '|'
	call	PrintChar
	mov	al, ' '
	call	PrintChar	
	mov	ecx, esi
	sub	ecx, edx	;number of chars that already printed as hex
	inc	ecx
	mov	esi, edx
.loop1:
	mov	al, byte [esi]
	call	PrintChar
	inc	esi
	loop	.loop1
	popad
	call	PrintCRLF
	
	mov	edx, esi
	inc	edx		;point to next line of 16ada
	xor	ebx, ebx
	
	cmp	ecx, 0
	je	.end
.next:
	inc	esi
	dec	ecx
	jnz	.loop
	
	cmp	esi, edx	;if total_printed / 16 <> 0 then print the rest chars
	jne	.next1
.end:
	mov	byte [MoveRealCursor], 1
	;call	SetRealCursor
	
	pop	edx
	pop	ebx
	pop	ecx
	pop	esi	
	pop	ebp	
	ret	2*4

;1st param = input string
;2nd param = lenght to be printed	
PrintC:
	push	ebp
	mov	ebp, esp
	add	ebp, 8
	
	push	ecx
	push	esi
	push	edi
	mov	ecx, [ebp]
	mov	esi, [ebp+4]
	
	mov	eax, ecx
	inc 	eax
	push	eax	
	call	MemAlloc	;size + 1
	mov	edi, eax
	push	edi		;pushed, ready to free up memory
	
	push	esi
	push	edi
	push	ecx
	call	MemCpy
	
	mov	byte [edi+ecx], 0
	push	edi
	call	PrintSimple
		
	;edi already pushed	
	call	MemFree
	
	pop	edi	
	pop	esi
	pop	ecx
	
	mov	byte [VgaNeedsUpdate], 1
	
	pop	ebp
	ret 	2*4
	

;input
;1st param = input string
;other params depends on the string format (if used %d, %x or %s as C Printf)
Print:
	push	ebp
	mov	ebp, esp
	add	ebp, 8

	push	esi
	push	edi
	push	ebx
	push	ecx
	xor	ebx, ebx	;counter for params

	mov	esi, [ebp]
	mov	edi, esi	;save esi
	
	mov	edi, TempBuffer
	push	esi
	push	edi
	call	StrCpy		;copy string to safe place
	mov	esi, edi
.PrintLoop:
	mov	al, byte [esi]	
	cmp	al, 0
	jne	.PrintLoop1
	jmp	.PrintExit
.PrintLoop1:
	cmp	al, '%'
	je	.PrintParam	
	inc	esi
	jmp	.PrintLoop

.PrintParam:
	add	ebx, 4		;inc param counter
	mov	byte [esi], 0
	push	edi
	call	PrintSimple		;Print str before param
	inc	esi
	mov	al, byte [esi]
	cmp	al, 'x'
	je	.PrintParam_x
	cmp	al, 's'
	je	.PrintParam_s
	cmp	al, 'd'
	je	.PrintParam_d	
	cmp	al, 25h		;%
	je	.PrintParam_No	
	
	;unknown param ?
	;skip it
	jmp	.PrintParam_exit
	
.PrintParam_No:
	call	PrintChar
	sub	ebx, 4
	jmp	.PrintParam_exit

.PrintParam_d:
	mov	eax, [ebp+ebx]
	push	eax
	call	MakeDecimal
	push	dword DecimalBufT
	call	PrintSimple
	jmp	.PrintParam_exit	

.PrintParam_s:
	mov	eax, [ebp+ebx]
	push	eax
	call	PrintSimple
	jmp	.PrintParam_exit
	
.PrintParam_x:
	mov	eax, [ebp+ebx]
	push	eax
	call	PrintHex
	jmp	.PrintParam_exit

.PrintParam_exit:
	inc	esi
	mov	edi, esi
	jmp 	.PrintLoop	

.PrintExit:
	push	edi		;saved esi
	call	PrintSimple

	add	ebx, 4
	mov	edi, dword Print_SetRet
	inc	edi
	mov	byte [edi], bl	;set new ret
.PrintExit_Error:
	mov	byte [VgaNeedsUpdate], 1
	cmp	byte [GUILoaded], 1
	je	.all_ok
	call	OSM2LFB		;print every line, until GUI is loaded and handle var "VgaNeedsUpdate"
.all_ok:
	pop	ecx	
	pop	ebx
	pop	edi
	pop	esi
	pop	ebp
Print_SetRet:
	ret	4		;ret 4 is dummy
				;will replaced from above

PrintMemoryMap:
	push	ebx
	push	ecx
	push	edi
	push	esi
	
	mov	byte [MoveRealCursor], 0
	
	push	dword Memory_Table
	call	Print
	
	mov	edi, dword [Memory_Manager_Table]
	mov	ebx, edi
	add	ebx, dword [Memory_Manager_Table_Size]
	sub	ebx, 8
	
	.loop:	
		cmp	dword [edi+4], 0
		je	.next
		
		push	dword [edi+4]		;size
		push	dword [edi]		;address
		push	dword Memory_Table_Entry
		call	Print
	.next:
		add	edi, 8
		cmp	edi, ebx
		jne	.loop
		
	mov	byte [MoveRealCursor], 1
	;call	SetRealCursor
	
	
	pop	esi
	pop	edi
	pop	ecx
	pop	ebx
	ret

;show total memory
PrintRAM:
	push	ebx
	push	edx
	
	mov	eax, dword [FreeMem]	;bytes
	shr	eax, 10		;in kbytes
	shr	eax, 10		;in MBytes
	
	;push	dword [TotalMem]	;MB
	;push	eax
	;push	dword RamDetected
	;call	Print

	pop	edx
	pop	ebx
	ret
	
;changes the cursor to next line	
PrintCRLF:
	;mov	eax, dword [VGA_Height]
	push	ecx
	call	GetActiveWindowSize
	and	eax, 0FFFF0000h		;keep height
	ror	eax, 16
	mov	ecx, eax
	call	GetActiveWindowXY
	and	eax, 0FFFF0000h		;keep top
	ror	eax, 16
	add	eax, ecx
	;sub	eax, FONT_HEIGHT
	pop	ecx
	
	sub	eax, (FONT_HEIGHT*2)+3
	cmp	dword [Cursor_Line], eax
	jng	.no_scroll	
	call	WindowScrollUp
	sub	dword [Cursor_Line], FONT_HEIGHT
.no_scroll:
	add	dword [Cursor_Line], FONT_HEIGHT
	
	cmp	byte [GUILoaded], 1
	jne	.noGUI
	
	call	GetActiveWindowXY
	and	eax, 0FFFFh		;keep "left" in pixels
	add	eax, 6
	mov	dword [Cursor_Pos], eax
	jmp	.exit
.noGUI:
	mov	dword [Cursor_Pos], 0	
.exit:
	ret

;PrintSimples a character to current cursor position
;input : al:char
PrintChar:
	push	edi
	
	mov	edi, dword CharForPrint
	mov	byte [edi], al
	push	edi
	call	PrintSimple
	
	pop 	edi
	Ret



;PrintSimples a number to hex style at current cursor
;input: 	bx=number
PrintHex:	
	push	ebp
	mov	ebp, esp
	add	ebp, 8
	
	push	ecx
	push	edx
	
	mov	eax, [ebp]
	mov	ecx, eax
	and	ecx, 0FFFF0000h
	cmp	ecx, 0
	jne	.printhex_32
	
	cmp	eax, 0FFh
	jg	.printhex_16
	mov	ecx, 2
	mov	edx, eax
	ror	edx, 4
	jmp	.printhex_loop
.printhex_16:
	;cmp	eax, 0FFFFh
	;jg	.printhex_32
	mov	ecx, 4
	mov	edx, eax
	ror	edx, 12
	jmp	.printhex_loop
.printhex_32:
	mov	ecx, 8
	mov	edx, eax
	ror	edx, 28
.printhex_loop:
	mov	eax, edx	
	and	eax, 0Fh			;mask low nibble
	add	al, 90h
	daa
	adc 	al, 40h
	daa
	
	call	PrintChar
	
	rol	edx, 4
	loop	.printhex_loop
	
	pop	edx
	pop	ecx
.exit:
	pop	ebp	
	
	mov	byte [VgaNeedsUpdate], 1
	
	ret	4
	

;PrintSimples a null terminated str at specific line,pos
;without changing current cursor position
;input:
;1st param string
;2nd param cursor position (bh=line, bl=column)
PrintXY:
	push	ebp
	mov	ebp, esp
	add	ebp, 8
	pushad

	mov	ebx, dword [ebp]
	movzx	eax, bh		;line
	shl	eax, 1		;*2
	mov	ecx, FONT_HEIGHT
	xor	edx, edx
	mul	ecx
	and	ebx, 0FFh	;column
	shl	ebx, 1		;*2
	push	eax		;line
	push	ebx		;pos
	push	dword [ebp+4]	;string
	push	0		;black
	call	DrawTextXY
	
	mov	byte [VgaNeedsUpdate], 1
	
	popad
	pop	ebp
	ret	2 * 4	

; inc system uptime	
Inc_Uptime:	
	inc	byte [uptime_sec]
	cmp	byte [uptime_sec], 60
	jne	.next1
	
	mov	byte [uptime_sec], 0
	inc	byte [uptime_min]
	cmp	byte [uptime_min], 60
	jne	.next1
	
	mov	byte [uptime_min], 0
	inc	byte [uptime_hours]
	cmp	byte [uptime_hours], 24
	jne	.next1
	
	mov	byte [uptime_hours], 0
	inc	byte [uptime_days]
.next1:
	ret
	
PrintUpTime:
	push	ebx
	push	edx
	push	edi
	;UpTimeMask		db	'  d 00:00:00', 0
	mov	edi, dword UpTimeMask	;SCREEN_MEM + 74h	
	mov	ebx, 10
	xor	edx, edx
	
	movzx	eax, word [uptime_days]	
	div	ebx
	add	dl, 48
	cmp	al, 0
	je	.next2
	add	al, 48			
	mov	byte [edi], al
.next2:
	mov	byte [edi+1], dl	
	mov	byte [edi+2], 'd'		;days
	
	movzx 	eax, byte [uptime_hours]
	xor	edx, edx
	div	ebx
	add	al, 48
	add	dl, 48
	mov	byte [edi+4], al
	mov	byte [edi+5], dl
	mov	byte [edi+6], ':'
	
	movzx 	eax, byte [uptime_min]
	xor	edx, edx
	div	ebx
	add	al, 48
	add	dl, 48
	mov	byte [edi+7], al
	mov	byte [edi+8], dl
	mov	byte [edi+9], ':'
	
	movzx 	eax, byte [uptime_sec]
	xor	edx, edx
	div	ebx
	add	al, 48
	add	dl, 48
	mov	byte [edi+10], al
	mov	byte [edi+11], dl

	push	dword 3
	mov	eax, dword [VGA_Width]
	sub	eax, 20*(FONT_WIDTH+1)
	push	eax
	push	dword UpTimeMask
	push	0FFFFh
	call	DrawTextXY
	
	pop	edi
	pop	edx
	pop	ebx
	ret

;Print system clock	
PrintClock:	
	cmp	byte [PrintingClock], 1
	jne	.doit
	ret
.doit:
	mov	byte [PrintingClock], 1
	
	pushad
	
	mov	eax, [cmos_sec]
	mov	[last_sec], eax
	xor	eax, eax
	out	70h, al
	call	Delay
	in	al, 71h
	mov	[cmos_sec], eax
	
	cmp	eax, [last_sec]
	jne	.print_it	
	jmp	.exit	
.print_it:
	call	Inc_Uptime
	call	PrintRAM
	
	cmp	byte [ShowClock], 1
	je	.here1
	jmp	.exit
.here1:	
	call	PrintUpTime
	;call	CPULoad
	;call	Print_OS_Loops
	
	mov	al, 2
	out	70h, al
	call	Delay
	in	al, 71h
	mov	[cmos_min], eax

	mov	al, 4
	out	70h, al
	call	Delay
	in	al, 71h
	mov	[cmos_hour], eax

	mov 	edi, dword ClockMask
	
	mov	eax, dword [cmos_hour]
	call	DecodeTime	
	mov	byte [edi], al
	mov	byte [edi+1], dl
	mov	byte [edi+2], ':'
	
	mov	eax, dword [cmos_min]	
	call	DecodeTime	
	mov	byte [edi+3], al
	mov	byte [edi+4], dl
	mov	byte [edi+5], ':'
	
	mov	eax, dword [cmos_sec]
	call	DecodeTime	
	mov	byte [edi+6], al
	mov	byte [edi+7], dl
	
	push	dword 3
	mov	eax, dword [VGA_Width]
	sub	eax, 8*(FONT_WIDTH+1)
	push	eax
	push	dword ClockMask
	push	0FFFFh
	call	DrawTextXY
	
	mov	byte [VgaNeedsUpdate], 1
	
.exit:	
	popad	
	mov	byte [PrintingClock], 0
	ret
	
;input eax=encoded time (hours, min or sec)
;output al, dl 
DecodeTime:
	push	eax
	and	eax, 0FFh
	shr	eax, 4
	mov	ebx, 10
	xor	edx, edx
	mul	ebx
	pop	ebx
	and	ebx, 0Fh	
	add	eax, ebx
	
	xor	edx, edx
	mov	ebx, 10
	div	ebx
	add	al, 48
	add	dl, 48
	ret
	