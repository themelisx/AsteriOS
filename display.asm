;Display routines

;SCREEN_MEM		EQU	0B7B00h
MAX_LINES		EQU	22
MAX_CHARS_PER_LINE	EQU	80

sMore			dd	'--- press any key to continue ---', 0

Init_Display:
	push	dword sClearScreen
	push	dword ClearScreen
	call	SetProcAddress
	
	push	dword sGetCursor
	push	dword GetCursor
	call	SetProcAddress
	
	push	dword sSetCursor
	push	dword SetCursor
	call	SetProcAddress
	
	push	dword sPrint
	push	dword Print
	call	SetProcAddress
	
	push	dword sPrintChar
	push	dword PrintChar
	call	SetProcAddress
	
	push	dword sPrintHex
	push	dword PrintHex
	call	SetProcAddress
	
	;;;;;
	push	dword sPrintHexView
	push	dword PrintHexView
	call	SetProcAddress	
	
	push	dword sPrintMemoryMap
	push	dword PrintMemoryMap
	call	SetProcAddress	
	
	push	dword sPrintIRQList
	push	dword PrintIRQList
	call	SetProcAddress	
	
	push	dword sPrintTextFile
	push	dword PrintTextFile
	call	SetProcAddress	
	
	push	dword sDeleteCurrentChar
	push	dword DeleteCurrentChar
	call	SetProcAddress	
	;;;;
	
	push	dword sPrintCRLF
	push	dword PrintCRLF
	call	SetProcAddress
	
	push	dword sPrintXY
	push	dword PrintXY
	call	SetProcAddress
	
	push	dword sPrintLine
	push	dword PrintLine
	call	SetProcAddress
	
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
	
	push	dword MAX_CHARS_PER_LINE+1
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
	
	cmp	edx, MAX_CHARS_PER_LINE+1	;chars per line
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
	push	ecx	
	mov	ecx, 20h	
.loop:
	push	ecx
	call	GetInterruptAddress
	
	cmp	eax, 0
	je	.next
	
	push	eax
	push	ecx
	push	dword IRQAndAddress
	call	Print
	call	PrintCRLF
	
.next:
	
	inc	ecx
	cmp	ecx, 30h
	jne	.loop
	
	pop	ecx
	ret	

;input:
;1st param cursor position (bh=line, bl=column)
;2nd param Color,Char 
PrintLine:
	push	ebp
	mov	ebp, esp
	add	ebp, 8
	
	call	GetCursor
	push	eax
	
	mov	eax, [ebp]
	call	SetCursor

	mov eax, 072Dh
	mov	edi, dword [cursor]
	mov	ecx, MAX_CHARS_PER_LINE
	rep	stosw
	
	pop	eax	
	call	SetCursor
	
	pop	ebp
	ret	4

;displays the main screen function bar at line 25
OS_Bars:
	pushad
	pushfd
	cld
	mov	eax, 7020h
	mov	edi, SCREEN_MEM
	mov	ecx, MAX_CHARS_PER_LINE
	rep	stosw
	
	push	dword OS_Title
	push	dword 0		;line 1 column 1
	call	PrintXY	
	
	mov	eax, 7020h
	mov	edi, SCREEN_MEM
	add	edi, 24*160	
	mov	ecx, MAX_CHARS_PER_LINE
	rep	stosw	
	
	push	dword FunctionBarStr
	push	dword 1801h		;line 25 column 1
	call	PrintXY
	popfd
	popad
	ret

;1st param: buffer
;2nd param: legth to print out
PrintHexView:
	push	ebp
	mov	ebp, esp
	add	ebp, 8
	
	;cmp	byte [DebugMode], 1		;debug mode enabled ?
	;jne	.NoDebug
	
	;push	dword [ebp]
	;push	dword [ebp+4]
	;push	Debug_PrintHexView
	;call	Print
.NoDebug:
	
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
Print_Loop:
	mov	al, byte [esi]	
	cmp	al, 0
	jne	Print_Loop_1
	jmp	Print_Exit
Print_Loop_1:
	cmp	al, '%'
	je	Print_Param	
	inc	esi
	jmp	Print_Loop

Print_Param:
	add	ebx, 4		;inc param counter
	mov	byte [esi], 0
	push	edi
	call	PrintSimple		;Print str before param
	inc	esi
	mov	al, byte [esi]
	cmp	al, 'x'
	je	PrintParam_x
	cmp	al, 's'
	je	PrintParam_s
	cmp	al, 'd'
	je	PrintParam_d	
	cmp	al, 25h		;%
	je	PrintParam_No	
	
	;unknown param ?
	;skip it
	jmp	PrintParam_exit
	
PrintParam_No:
	call	PrintChar
	sub	ebx, 4
	jmp	PrintParam_exit

PrintParam_d:
	mov	eax, [ebp+ebx]
	push	eax
	call	MakeDecimal
	push	dword DecimalBufT
	call	PrintSimple
	jmp	PrintParam_exit	

PrintParam_s:
	mov	eax, [ebp+ebx]
	push	eax
	call	PrintSimple
	jmp	PrintParam_exit
	
PrintParam_x:
	mov	eax, [ebp+ebx]
	push	eax
	call	PrintHex
	jmp	PrintParam_exit

PrintParam_exit:
	inc	esi
	mov	edi, esi
	jmp 	Print_Loop	

Print_Exit:
	push	edi		;saved esi
	call	PrintSimple

	add	ebx, 4
	mov	edi, Print_SetRet
	inc	edi
	mov	byte [edi], bl	;set new ret
Print_Exit_Error:
	pop	ecx	
	pop	ebx
	pop	edi
	pop	esi
	pop	ebp
Print_SetRet:
	ret	4		;ret 4 is dummy
				;will replaced from above

PrintMemoryMap:
	pushad
	
	push	dword Memory_Table
	call	Print
	
	mov	ecx, Memory_Manager_Table_Size
	shr	ecx, 3
	mov	edi, Memory_Manager_Table
	
	PrintMemoryMap_Loop:	
		cmp	dword [edi+4], 0
		je	PrintMemoryMap_Next
		
		push	dword [edi+4]		;size
		push	dword [edi]		;address
		push	dword Memory_Table_Entry
		call	Print
		
	PrintMemoryMap_Next:
		add	edi, 8
		loop	PrintMemoryMap_Loop
		
	popad	
	ret

;show total memory
PrintRAM:
	call	GetCursor
	push	eax			;save cursor
	
	mov	eax,  1800h		;line 24 column 0
	call	SetCursor

	movzx	eax, word [dwTotalMem]
	push	eax
	mov	eax, dword [FreeMem]
	shr	eax, 10
	shr	eax, 10	
	push	eax
	push	dword RamDetected
	call	Print

	pop	eax	
	call	SetCursor
	ret	

;changes the cursor to next line	
PrintCRLF:
	cmp	byte [cursor_line], MAX_LINES
	jng	PrintCRLF_Normal
	
	call	ScrollUp
	dec	byte [cursor_line]
PrintCRLF_Normal:
	inc	byte [cursor_line]
	mov	byte [cursor_pos], 0
	
	call	CursorToAddr

	ret
	
DeleteCurrentChar:
	;delete char from screen
	dec 	byte [cursor_pos]
	call	CursorToAddr
	mov	eax, dword [cursor]
	mov	byte [eax], ' '
	ret

;PrintSimples a character to current cursor position
;input : al:char
PrintChar:
	push	edi	
	mov	edi, dword [cursor]
	stosb
	inc 	byte [cursor_pos]
	call	CursorToAddr	
	pop 	edi
	ret



;PrintSimples a number to hex style at current cursor
;input: number
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
	jne	.PrintHex_32
	
	cmp	eax, 0FFh
	jg	.PrintHex_16
	mov	ecx, 2
	mov	edx, eax
	ror	edx, 4
	jmp	.PrintHex_loop
.PrintHex_16:
	;cmp	eax, 0FFFFh
	;jg	.PrintHex_32
	mov	ecx, 4
	mov	edx, eax
	ror	edx, 12
	jmp	.PrintHex_loop
.PrintHex_32:
	mov	ecx, 8
	mov	edx, eax
	ror	edx, 28
.PrintHex_loop:
	mov	eax, edx	
	and	eax, 0Fh			;mask low nibble
	add	al, 90h
	daa
	adc 	al, 40h
	daa
	
	call	PrintChar
	
	rol	edx, 4
	loop	.PrintHex_loop
	
	pop	edx
	pop	ecx
	
	pop	ebp	
	ret	4

;
SetCursor:
	mov	byte [cursor_line], ah
	mov	byte [cursor_pos], al
	call	CursorToAddr
	ret

;
GetCursor:
	mov	ah, byte [cursor_line]
	mov	al, byte [cursor_pos]
	ret
	
;saves screen data to temp memory area
;Save_Screen:
;	pushad
;	mov	edi, Screen_buf
;	mov	esi, SCREEN_MEM
;	mov	ecx, 2000		;2*MAX_CHARS_PER_LINE*25
;	rep	movsw
;	popad
;	ret

;restores screen data from temp memory area
;Restore_Screen:
;	pushad
;	mov	esi, Screen_buf	
;	mov	edi, SCREEN_MEM
;	mov	ecx, 2000		;2*MAX_CHARS_PER_LINE*25
;	rep	movsw
;	popad
;	ret

;clear screen (CLS)
ClearScreen:
	pushad
	
	mov	eax, 0720h
	mov	ecx, MAX_CHARS_PER_LINE*25
	mov	edi, SCREEN_MEM
	rep	stosw
	
	mov	byte [cursor_line], 23
	mov	byte [cursor_pos], 0	
	call	CursorToAddr
	
	call	OS_Bars
	call	PrintRAM
	
	popad
	ret

;converts vars cursor_line and cursor_pos to vga address
CursorToAddr:
	pushad

	xor	eax, eax
	xor	edx, edx
	mov	al, byte [cursor_line]	
	mov	ch, 160
	mul	ch
	push	eax
	mov	al, byte [cursor_pos]
	mov	ch, 2
	mul	ch
	pop	ecx
	add	eax, ecx
	
	add	eax, SCREEN_MEM	
	mov	dword [cursor], eax
	
	popad
	ret
	
ScrollUp:
	pushad
	pushfd
	
	cld	
	mov	esi, SCREEN_MEM
	mov	edi, esi
	add	esi, 2*2*MAX_CHARS_PER_LINE	;add 2 lines
	add	edi, 1*2*MAX_CHARS_PER_LINE	;add 1 line
	mov	ecx, MAX_LINES*MAX_CHARS_PER_LINE	;move MAX_LINES lines (movsw 2 bytes)
	rep 	movsw
	
	mov	eax, 720h		;white-black, space
	mov	edi, SCREEN_MEM
	add	edi, 23*MAX_CHARS_PER_LINE*2	;add 24 lines
	mov	ecx, MAX_CHARS_PER_LINE		;one line
	rep	stosw		;cleanup last line
	
	popfd
	popad
	
	ret

PrintHexXY:
;1st param HEX
;2nd param cursor position (bh=line, bl=column)
	push	ebp
	mov	ebp, esp
	add	ebp, 8
	
	call	GetCursor
	push	eax
	
	mov	eax, [ebp]
	call	SetCursor
	
	push	dword [ebp+4]
	call	PrintHex
	
	pop	eax	
	call	SetCursor
	
	pop	ebp
	ret	2*4

;PrintSimples a null terminated str at specific line,pos
;without changing current cursor position
;input:
;1st param string
;2nd param cursor position (bh=line, bl=column)
PrintXY:
	push	ebp
	mov	ebp, esp
	add	ebp, 8
	
	call	GetCursor
	push	eax
	
	mov	eax, [ebp]
	call	SetCursor
	
	push	dword [ebp+4]
	call	PrintSimple
	
	pop	eax	
	call	SetCursor
	
	pop	ebp
	ret	2 * 4

;input: 
;1st param: null terminated string
PrintSimple:	
	push	ebp
	mov	ebp, esp
	add	ebp, 8
	
	push	esi
	push	edi
	push	edx
	
	mov	esi, [ebp]

	xor	edx, edx	
	mov	edi, dword [cursor]
.PrintSimple_1:
	lodsb
	cmp	al, 0
	je	.PrintSimple_3
	
	cmp	al, 10
	je	.PrintSimple_1
	
	cmp	al, 9
	je	.Print_Tab
	
	cmp	al, 13
	jne	.PrintSimple_2	
	
	call	PrintCRLF
	mov	edi, dword [cursor]
	xor	edx, edx
	
	jmp	.PrintSimple_1
.PrintSimple_2:
	stosb
	;mov	al, cl		;color
	;stosb	
	inc	edi	
	inc	edx	
	jmp	.PrintSimple_1
.Print_Tab:
	push	ecx
	mov	ecx, 8
.Print_Tab1:
	mov	al, 20h
	stosb
	inc	edi
	loop	.Print_Tab1
	pop	ecx
	add	edx, 8
	jmp	.PrintSimple_1
.PrintSimple_3:		
	
	add	byte [cursor_pos], dl
	call	CursorToAddr
	
	pop	edx
	pop	edi
	pop	esi
	pop	ebp
			
	ret	4
	

Print_OS_Loops:
	;pushad
	call	GetCursor
	push	eax
	mov	eax, 0030h
	call	SetCursor
	;mov	ebx, [OS_loops]
	push	dword [OS_loops]
	call	PrintHex
	pop	eax
	call	SetCursor
	;popad
	ret
	
; inc system uptime	
Inc_Uptime:
	pushad
	
	cld
	inc	byte [uptime_sec]
	cmp	byte [uptime_sec], 60
	jne	.exit
	
	mov	byte [uptime_sec], 0
	inc	byte [uptime_min]
	cmp	byte [uptime_min], 60
	jne	.exit
	
	mov	byte [uptime_min], 0
	inc	byte [uptime_hours]
	cmp	byte [uptime_hours], 24
	jne	.exit
	
	mov	byte [uptime_hours], 0
	inc	byte [uptime_days]
.exit:

	;UpTimeMask		db	'  d 00:00:00', 0	
	movzx	ebx, word [uptime_days]
	push	ebx
	call	MakeDecimal
	mov	esi, DecimalBufT
	mov	edi, UpTimeMask	
		
	cmp	word [uptime_days], 10
	jb	.Inc_Uptime_1
	lodsb
	mov	[edi], al
.Inc_Uptime_1:
	inc	edi
	lodsb
	mov	[edi], al
	add	edi, 3
	
	movzx 	ebx, byte [uptime_hours]
	push	ebx
	call	MakeDecimal
	mov	esi, DecimalBufT
	mov	byte [edi], "0"
	cmp	byte [esi+1], 0
	je	.Inc_Uptime_2
	lodsb
	mov	[edi], al	
.Inc_Uptime_2:
	inc	edi
	lodsb
	mov	[edi], al
	add	edi, 2
	
	movzx 	ebx, byte [uptime_min]
	push	ebx
	call	MakeDecimal
	mov	esi, DecimalBufT
	mov	byte [edi], "0"
	cmp	byte [esi+1], 0
	je	.Inc_Uptime_3
	lodsb
	mov	[edi], al	
.Inc_Uptime_3:	
	inc	edi
	lodsb
	mov	[edi], al
	add	edi, 2
	
	movzx 	ebx, byte [uptime_sec]
	push	ebx
	call	MakeDecimal
	mov	esi, DecimalBufT
	mov	byte [edi], "0"
	cmp	byte [esi+1], 0
	je	.Inc_Uptime_4
	lodsb
	mov	[edi], al	
.Inc_Uptime_4:
	inc	edi
	lodsb
	mov	[edi], al
	
	popad
	ret

;PrintSimple system uptime
PrintUpTime:
	mov	eax, UpTimeMask
	push	eax
	push	dword 0039h		;line 1 column 70
	call	PrintXY
	ret

;Print system clock	
PrintClock:
	pushad
	pushfd
	
	cld
	mov	eax, [cmos_sec]
	mov	[last_sec], eax
	xor	eax, eax
	out	70h, al
	call	Delay
	in	al, 71h
	mov	[cmos_sec], eax
	
	cmp	eax, [last_sec]
	jne	.ok	
	jmp	.Exit	
.ok:

	call	Inc_Uptime
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

	mov	eax, ClockMask
	push	eax
	push	dword 0047h		;line 1 column 71
	call	PrintXY
	
	pushad
	mov	eax, dword [cmos_hour]
	push	eax
	and	eax,0ffh
	shr	eax,4
	mov	edx,10
	mul	edx
	pop	edx
	and	edx,0fh	
	add	eax,edx
	
	push	eax
	call	MakeDecimal
	mov	esi, DecimalBufT
	
	mov	edi, SCREEN_MEM + 8Eh
	
	cmp	byte [esi+1], 0
	jne	.ok_1
	mov	al, '0'
	stosb
	inc 	edi	
	movsb
	
	jmp	.ok_1a
.ok_1:
	movsb
	inc 	edi
	movsb
.ok_1a:
	popad
	
	add	edi, 3
	
	pushad
	mov	eax, dword [cmos_min]
	push	eax
	and	eax,0ffh
	shr	eax,4
	mov	edx,10
	mul	edx
	pop	edx
	and	edx,0fh	
	add	eax,edx
	
	push	eax
	call	MakeDecimal
	mov	esi, DecimalBufT	
	
	mov	edi, SCREEN_MEM + 94h
	
	cmp	byte [esi+1], 0
	jne	.ok_2
	mov	al, '0'
	stosb
	
	inc 	edi
	movsb
	jmp	.ok_2a
.ok_2:
	movsb
	inc 	edi
	movsb
.ok_2a:
	popad
	
	add	edi, 3
	
	pushad
	mov	eax, dword [cmos_sec]
	push	eax
	and	eax,0ffh
	shr	eax,4
	mov	edx,10
	mul	edx
	pop	edx
	and	edx,0fh	
	add	eax,edx
	
	push	eax
	call	MakeDecimal
	mov	esi, DecimalBufT
	
	mov	edi, SCREEN_MEM + 9Ah
	
	cmp	byte [esi+1], 0
	jne	.ok_3
	mov	al, '0'
	stosb	
	inc 	edi	
	movsb
	
	jmp	.ok_3a
.ok_3:
	movsb
	inc 	edi
	movsb
.ok_3a:
	
	popad		
	
.Exit:	

	popfd
	popad
	
	ret
	