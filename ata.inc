; ATA Hard Disk Driver for PizziOS
; Started 17 Sep 1999
; Name changed hd.inc -> ata.inc 24 Aug 2000

; Ata_cmd:
; [esi] -> hd_dsc
; cl = Sector Count
; al = Sector #
; ah = Cylinder Low
; bl = Cylinder High
; bh = Device/Head
; ch = Command
; ds = os_data

ata_cmd:
 push eax
 push ecx
 call ata_grab_drive
 pop ecx
 pop eax
; </ataprecmd><atacmd>
 or dl,011b
 out dx,al ; al -> 03
 dec dl
 mov al,cl
 out dx,al ; cl -> 02
 or dl,0100b
 mov al,bh
 out dx,al ; bh -> 06
 dec dl
 mov al,bl
 out dx,al ; bl -> 05
 dec dl
 shr ax,8
 out dx,al ; ah -> 04
 or dl,0111b

 xor ebx,ebx
 mov bl,[esi+1]
 xor cl,cl
 lea ebx,[ebx + offset hd_i0]
 mov al,ch
 mov [ebx],cl
 out dx,al ; ch -> 07 (CMD)

 ata_cmd_wait:
 mov cl,[ebx]
 test cl,cl
  jz ata_cmd_wait ; yield()?
 in al,dx ; acknowledge interrupt
 test al,1
  jz ata_cmd_success
 stc
 ata_cmd_success:
ret

ata_cmd_full:
 push offset ata_release_drive ; call ata_cmd
 jmp ata_cmd                   ; call ata_release_drive
                               ; ret

read_sector:
; eax is device number
; ebx is sector number
; ds:[edi] is memory address
pushad
mov cx,os_data
push ds
mov ds,cx
read_sector0:
 mov edx,ds:[hd_units]
 cmp eax,edx
  jnb read_sector_err
 shl eax,5
 lea esi,[eax + offset hd_dsc]
 mov eax,[esi+12]
 mov cl,[esi]
 cmp ebx,eax
  ja read_sector_err
 cmp cl,1
  jz ata_read_sector
  ; ... add ATAPI and other interfaces
 ; if (no recognized device)...
 read_sector_err:
 pop ds
 popad
 stc
ret

hd_getbsy:
 push ebx
 lea ecx,[esi+3]
 mov bl,[ecx]
 test bl,0F0h
 jz hd_getbsy1
 lea ecx,[ecx-32]
 hd_getbsy1:
 pop ebx
ret

ata_xlate_chs:
 mov ebp,[esi+22]
 xor edx,edx
 lea ebx,[ebp]
 shr ebx,16 ; s
 and ebp,01Fh ; h
 div ebx
 lea ebx,[edx] ; mov bl,dl
 xor edx,edx
 div ebp
 lea ebx,[ebx+1]
 ; eax = c, edx = h, ebx=s
 mov ch,al
 mov bh,dl ; h
 mov al,bl ; s
 mov bl,ah ; ch
 mov ah,ch ; cl
 or bh,cl
ret

ata_read_sector_chs:
 call ata_xlate_chs
 jmp ata_read_sector_chs_ret

ata_read_sector:
 mov cl,[esi + 2]
 mov eax,ebx ; mov al,bl / mov ah,bh
 shr ebx,16
 test cl,01000000b
  jz ata_read_sector_chs
 or bh,cl
 ata_read_sector_chs_ret:
 mov ecx,02001h ; cmd = 20h: read w/ retries
 call ata_cmd
 test al,08h
  jz ata_read_error
 and dl,0F8h
 mov bx,ds
 pop ds
 mov ebp,(512/4)
 ata_read_pio:
IFDEF ATA_32
  in eax,dx
  dec ebp
  mov [edi],eax
  lea edi,[edi+4]
 jnz ata_read_pio
ELSE
  in ax,dx
  mov cx,ax
  in ax,dx
  and ecx,0ffffh
  shl eax,16
  dec ebp
  lea eax,[ecx+eax]
  mov [edi],eax
  lea edi,[edi+4]
 jnz ata_read_pio
ENDIF
 mov dx,ds
 mov ds,bx
 call ata_release_drive
 mov ds,dx
 popad
 ; clc ; xor clears CF
ret

ata_read_error:
 and dl,0feh
 or dl,06h ; -> 6
 in al,dx ; read error register, ack error
 call ata_release_drive
 pop ds
 popad
 stc
ret

ata_int_3:
 push edx
 mov dl,3
 jmp ata_int_cnvrg
ata_int_2:
 push edx
 mov dl,2
 jmp ata_int_cnvrg
ata_int_1:
 push edx
 mov dl,1
 jmp ata_int_cnvrg
ata_int_0:
 push edx
 xor dl,dl
ata_int_cnvrg:
 sti ; not important, BUT you might not want to switch tasks here?
 and edx,03h

 push eax
; push ebx
 mov ax,os_data
; push ecx
 push ds
 mov ds,ax
; lea ebx,[edx*4 + offset hd_intprocs]
; xor eax,eax
; mov ecx,[ebx] ; get interrupt proc, if there is any
; mov [ebx],eax ; set interrupt proc to 0 to prevent stray interrupts from
; test ecx,ecx  ;   wandering into other procedures.
;  jnz ecx      ; jmp to interrupt proc
; hd_int_ret:
 lea edx,[edx + offset hd_i0]
 mov al,020h
 mov ah,[edx]
 out 0a0h,al
 inc ah
 out 020h,al
 mov [edx],ah
 pop ds
; pop ecx
; pop ebx
 pop eax
 pop edx
iretd

;hd_demo_int_proc:
; push edx
; push esi
; mov esi,[edx*4 + offset hd_intparams]
; mov dx,[esi+10]
; ;...
; pop esi
; pop edx
; jmp hd_int_ret

ata_readerr:
 or dl,087h
 in al,dx ; acknowledge error if there is any by reading from the status
 and dl,011111001b
 in al,dx ;  and error registers.
 pop ds
 popad
 stc
 ret

ata_init:
mov esi,offset hd_init_1
call Print
call get_drives
mov ecx,ds:[hd_units]
mov edi,offset hd_dsc+12
mov esi,offset hd_init_2
mov edx,offset hd_init_num
test ecx,ecx
mov ebx,offset mb_string
jz hd_not_detected
hd_disploop:
 call print ; Unit X:
 mov eax,[edi]
 shr eax,11
 call print_num
 xchg esi,ebx
 call print
 xchg ebx,esi
 lea edi,[edi+32]
 inc byte ptr [edx]
dec ecx
jnz hd_disploop
hd_not_detected:

;call do_crlf
mov dx,0A1h
in al,dx
and al,00110011b ; enable IRQ 14, 15, 10, 11
out dx,al

;mov ebx,offset hd_unexpected_int
;push ebx
;push ebx
;push ebx
;mov eax,020h+14
;call patch_int
;pop ebx
;mov eax,020h+15
;call patch_int
;pop ebx
;mov eax,020h+10
;call patch_int
;pop ebx
;mov eax,020h+11
;call patch_int
;
ret


;1F0, 170, 1E8, 168
get_drives:
  xor ecx,ecx
  xor ebp,ebp
   get_drives_loop:
    call scan_for_drive ; ecx = num of hd_dsc, ebp = drive select
    sbb ecx,0
    shl ebp,1
    inc ecx
    inc ebp
    test ebp,08h
   jz get_drives_loop
 mov ds:[hd_units],ecx
ret

ata_poll: ;dx = "near" the base register. if it's pointing
          ; anywhere between hd[0] and hd[7] it'll work.
push eax
push edx
or dl,07h ; hd[7]:status
 ata_poll_loop:
  in al,dx
  test al,080h     ; BSY
   jnz ata_poll_loop ; lock up point?
;  xor al,8
;  test al,09h ; if (DRQ && !ERR)
;   jz hd_poll_success
;;
  test al,08h      ; DRQ
   jnz ata_poll_success
;/;
  stc
 ata_poll_success:
 ; Note: If (success) CF = 0 since TEST always sets CF (and OF) to 0.
pop edx
pop eax
ret


scan_for_drive:
;In:                 Out: !CF = drive found
;ecx = hd_dsc #            CF = no drive found
;ebp = Drive #       Preserves: ecx, ebp
push ecx
push ebp
 mov edi,ebp
 shr edi,1
 lea edi,[edi*2+offset hd_params]
 mov dx,[edi]
 or dl,07h
 in al,dx
 inc al
  jz scan_for_drive_fail ; there's no HD controller here
 call ata_poll ; wait for !BSY. returns error since no DRQ.

; push eax
; mov al,0b1h
; call do_crlf
; call print_hex
; pop eax

 dec dl ; hd[6]: drive/head
 mov ax,bp
 and al,1
 or al,0Ah
 shl al,4
 out dx,al
 inc dl ; hd[7]: status/command
 in al,dx
 xor al,07Fh
 test al,07Fh
  jz scan_for_drive_fail ; drive not present.

; push eax
; mov al,0b2h
; call do_crlf
; call print_hex
; pop eax

 shl ecx,5
 mov al,11101100b
 out dx,al
 lea esi,[ecx + offset hd_dsc]

 mov ecx,100
 call common_delay
 call ata_poll
  jc scan_for_drive_fail

; mov al,0A1h
; call print_hex

 and dl,0F8h ; hd[0]: data
 xor cl,cl
 mov edi,offset hd_buffer
 scan_for_drive_io:
  dec cl
  in ax,dx
  mov [edi],ax
  lea edi,[edi+2]
  jnz scan_for_drive_io
 mov edi,offset hd_buffer
 mov al,[edi]
 xor al,01000000b
 test al,11000000b
  jnz scan_for_drive_fail ; if (!HD || REMOVABLE) fail

; push eax
; mov al,0A2h
; call print_hex
; pop eax

 mov ebx,ebp
 and bl,1
 shl bl,4
 or bl,010100000b ; bl=|1|0|1|DRV|:|0|0|0|0|

 mov ax,[edi+49*2]
 shr eax,8
 mov [esi+2],bl ; during the renaming stalls, store bl
 mov bh,al
 shl al,2
 and bh,2
 and al,4
 or bh,1 ; assume CHS works
 or al,bh


 ; and al,11111101b ; FOR TESTING ONLY - disables LBA


 mov [esi+18],al ; store canuse info
 mov ebx,ebp
 mov al,1
 shr ebx,1
 mov [esi],al   ; 1 = ATA HD
 mov [esi+1],bl ; [0,1,2,3] = IRQ codes (corresponding to irq's [14,15,10,11])
 mov eax,edx
 and al,0F8h
 mov [esi+10],ax ; base register

; push eax
; mov al,0A3h
; call print_hex
; pop eax

 mov ebx,[edi+60*2]
 dec ebx
 mov [esi+12],ebx ; assume LBA for size info for now

; begin chs
 xor eax,eax
 mov ax,[edi+1*2] ; c
 lea ebx,[eax-1]
 xor ecx,ecx
 mov cx,[edi+6*2] ; s
 mov [esi+4],bx
 mul ecx
 mov dx,[edi+3*2] ; h
 mov [esi+8],cx
 mov [esi+6],dx
 and edx,01Fh
 mul edx
 lea ebx,[eax-1]
 lea eax,[eax-1] ; avoids dependency
 and ebx,0F0000000h
 or edx,ebx
  jnz scan_for_drive_nochs ; CHS overflow

 ; if data in word 49 isn't trustable, comment this out
 mov cl,[esi+18]
 test cl,010b
  jz scan_for_drive_nolba

 mov ebx,[esi+12]
 call scan_for_drive_checklba
 rol ebx,16 ; check for reversed word orders
 call scan_for_drive_checklba
 rol ebx,16

 jmp scan_for_drive_nolba
; Note:
; this part is only necessary if bits 8 and 9 in word 49 are not to be
;  trusted.
; mov ecx,[esi+6] ; huge drives use fake values for CHS (source: Linux)
; mov dx,[esi+4]
; or cl,01h ; there are two valid values for the 1 bit in the heads field
; cmp dx,16382 ; 16383 cyllendars
;  jnz scan_for_drive_nolba
; cmp ecx,(62*65536 + 15) ; 63 sectors, 15 or 16 heads
;  jnz scan_for_drive_nolba
; jmp scan_for_drive_nochs

scan_for_drive_uselba0:
 mov [esi+12],ebx
scan_for_drive_uselba: 
 mov al,[esi+2]
 or al,01000000b
 mov [esi+2],al
 jmp scan_for_drive_success


 scan_for_drive_nolba:
 mov bl,[esi+18]
 mov [esi+12],eax
 test bl,1
  jz scan_for_drive_fail
 ;jmp scan_for_drive_usechs

 scan_for_drive_usechs:
  mov al,[esi+2]
  and al,10110000b ; clear lba
  mov [esi+2],al
  mov bh,al
  mov edx,[esi+4]
  mov cl,[esi+8]
  mov al,[esi+6]
  mov [esi+20],edx
  dec al
  mov dx,[esi+8]
  and al,00001111b
  mov [esi+24],dx
  or bh,al
  mov ch,091h
  xor edx,edx ; int proc = 0 (no proc)
  call ata_cmd_full
;   jc scan_for_drive_fail
  ;jmp scan_for_drive_success

scan_for_drive_success:
 test ebp,1
 jz scan_for_drive_not2nd
  mov ax,[esi+10]
  sub ax,[esi-22]
  jnz scan_for_drive_not2nd
  mov byte ptr [esi+3],0F0h
 scan_for_drive_not2nd:
; push eax
; mov al,0AAh
; call print_hex
; pop eax

clc
pop ebp
pop ecx
ret

 scan_for_drive_checklba: ; checks size reported by LBA against that reported
                          ;  by CHS.
  lea edx,[ebx] ; eax=ecx = chs, edx=ebx = lba
  lea ecx,[eax]
  sub edx,eax
  shr ecx,3 ; 1/8th discrepency tolerated
  cmp edx,ecx ; cmp d(sizes),12.5%
  pop ecx
  jna scan_for_drive_uselba0
  jmp ecx

 scan_for_drive_nochs:
  mov cl,[esi+18]
  and cl,0FEh
  mov [esi+18],cl
  test cl,010b
   jnz scan_for_drive_uselba
  ;jmp scan_for_drive_fail

scan_for_drive_fail:

; push eax
; mov al,0AFh
; call print_hex
; pop eax

stc
pop ebp
pop ecx
ret


ata_grab_drive:
 ata_grab_drive_tryagain:
  sti
 mov dx,[esi+0Ah] ; hd_base
 or dl,07h
 call hd_getbsy
 ata_grab_drive_waitbusy:
 in al,dx
 cmp al,01h ; ERR
  jz ata_grab_drive_okgoahead
 test al,080h ; BSY
  jnz ata_grab_drive_waitbusy ; yield()? get_on_queue()?
 test al,040h ; DRDY
  jz ata_grab_drive_waitbusy
 ata_grab_drive_okgoahead:
 mov al,[ecx]
 test al,al
  jnz ata_grab_drive_waitbusy
 ; <dx> = 01??????
 cli
 mov al,[ecx]
 test al,al
 jnz ata_grab_drive_tryagain
 or al,1
 mov [ecx],al
 and dl,0f8h
 sti
ret

ata_release_drive:
 xor al,al
 call hd_getbsy
 mov [ecx],al
ret

