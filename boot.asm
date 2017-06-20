;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                                                          ;;
;;          "BootProg" Loader v 1.2 by Alexei A. Frounze (c) 2000           ;;
;;                                                                          ;;
;;                                                                          ;;
;;                            Contact Information:                          ;;
;;                            ~~~~~~~~~~~~~~~~~~~~                          ;;
;; E-Mail:   alexfru@chat.ru                                                ;;
;; Homepage: http://alexfru.chat.ru                                         ;;
;; Mirror:   http://members.xoom.com/alexfru                                ;;
;;                                                                          ;;
;;                                                                          ;;
;;                                  Thanks:                                 ;;
;;                                  ~~~~~~~                                 ;;
;;      Thanks Thomas Kjoernes (aka NowhereMan) for his excelent idea       ;;
;;                                                                          ;;
;;                                                                          ;;
;;                                 Features:                                ;;
;;                                 ~~~~~~~~~                                ;;
;; - FAT12 supported                                                        ;;
;;                                                                          ;;
;; - Loads particular COM or EXE file placed to the root directory of a disk;;
;;   ("ProgramName" variable holds name of a file to be loaded)             ;;
;;                                                                          ;;
;; - Provides simple information about errors occured during load process   ;;
;;   ("RE" message stands for "Read Error",                                 ;;
;;    "NF" message stands for "file Not Found")                             ;;
;;                                                                          ;;
;;                                                                          ;;
;;                             Known Limitations:                           ;;
;;                             ~~~~~~~~~~~~~~~~~~                           ;;
;; - Works only on the 1st MBR partition which must be a PRI DOS partition  ;;
;;   with FAT12 (File System ID: 1)                                         ;;
;;                                                                          ;;
;;                                                                          ;;
;;                                Known Bugs:                               ;;
;;                                ~~~~~~~~~~~                               ;;
;; - All bugs are fixed as far as I know. The boot sector tested on the     ;;
;;   following types of diskettes: 360KB 5"25, 1.2MB 5"25, 1.44MB 3"5.      ;;
;;                                                                          ;;
;;                                                                          ;;
;;                                Memory Map:                               ;;
;;                                ~~~~~~~~~~~                               ;;
;;                 ������������������������Ŀ                               ;;
;;                 � Interrupt Vector Table � 0000                          ;;
;;                 ������������������������Ĵ                               ;;
;;                 �     BIOS Data Area     � 0040                          ;;
;;                 ������������������������Ĵ                               ;;
;;                 � PrtScr Status / Unused � 0050                          ;;
;;                 ������������������������Ĵ                               ;;
;;                 �   Image Load Address   � 0060                          ;;
;;                 ������������������������Ĵ                               ;;
;;                 �    Available Memory    � nnnn                          ;;
;;                 ������������������������Ĵ                               ;;
;;                 �     2KB Boot Stack     � A000 - 512 - 2KB              ;;
;;                 ������������������������Ĵ                               ;;
;;                 �       Boot Sector      � A000 - 512                    ;;
;;                 ������������������������Ĵ                               ;;
;;                                            A000                          ;;
;;                                                                          ;;
;;                                                                          ;;
;;                   Boot Image Startup (register values):                  ;;
;;                   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~                  ;;
;;  dl = boot drive number                                                  ;;
;;  cs:ip = program entry point                                             ;;
;;  ss:sp = program stack (don't confuse with boot sector's stack)          ;;
;;  COM program defaults: cs = ds = es = ss = 50h, sp = 0, ip = 100h        ;;
;;  EXE program defaults: ds = es = 50h, other stuff depends on EXE header  ;;
;;                                                                          ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

[BITS 16]

?                       equ     0
ImageLoadSeg            equ     60h

[SECTION .text]
[ORG 0]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Boot sector starts here ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        jmp     short   start
        nop
bsOemName               DB      "AsteriOS"      ; 0x03

;;;;;;;;;;;;;;;;;;;;;
;; BPB starts here ;;
;;;;;;;;;;;;;;;;;;;;;

bpbBytesPerSector       DW      ?               ; 0x0B
bpbSectorsPerCluster    DB      ?               ; 0x0D
bpbReservedSectors      DW      ?               ; 0x0E
bpbNumberOfFATs         DB      ?               ; 0x10
bpbRootEntries          DW      ?               ; 0x11
bpbTotalSectors         DW      ?               ; 0x13
bpbMedia                DB      ?               ; 0x15
bpbSectorsPerFAT        DW      ?               ; 0x16
bpbSectorsPerTrack      DW      ?               ; 0x18
bpbHeadsPerCylinder     DW      ?               ; 0x1A
bpbHiddenSectors        DD      ?               ; 0x1C
bpbTotalSectorsBig      DD      ?               ; 0x20

;;;;;;;;;;;;;;;;;;;
;; BPB ends here ;;
;;;;;;;;;;;;;;;;;;;

bsDriveNumber           DB      ?               ; 0x24
bsUnused                DB      ?               ; 0x25
bsExtBootSignature      DB      ?               ; 0x26
bsSerialNumber          DD      ?               ; 0x27
bsVolumeLabel           DB      "ASTERI-OS  "   ; 0x2B
bsFileSystem            DB      "FAT12   "      ; 0x36

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Boot sector code starts here ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

start:
        cld

;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; How much RAM is there? ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        int     12h             ; get conventional memory size (in KBs)
        shl     ax, 6           ; and convert it to paragraphs

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Reserve some memory for the boot sector and the stack ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        sub     ax, 512 / 16    ; reserve 512 bytes for the boot sector code
        mov     es, ax          ; es:0 -> top - 512

        sub     ax, 2048 / 16   ; reserve 2048 bytes for the stack
        mov     ss, ax          ; ss:0 -> top - 512 - 2048
        mov     sp, 2048        ; 2048 bytes for the stack

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Copy ourself to top of memory ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        mov     cx, 256
        mov     si, 7C00h
        xor     di, di
        mov     ds, di
        rep     movsw

;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Jump to relocated code ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        push    es
        push    word main
        retf

main:
        push    cs
        pop     ds

        mov     [bsDriveNumber], dl     ; store boot drive number
        
        call	.here
        db	'Loading AsteriOS', 0
.here:
	pop	si
        mov     ah, 0Eh
        mov     bx, 7
.loop:
        lodsb
        cmp	al, 0
        je	.next
        int     10h
        jmp	.loop
.next:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Reserve some memory for a FAT12 image (6KB max) and load it whole ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        mov     ax, [bpbBytesPerSector]
        shr     ax, 4                   ; ax = sector size in paragraphs
        mov     cx, [bpbSectorsPerFAT]  ; cx = FAT size in sectors
        mul     cx                      ; ax = FAT size in paragraphs

        mov     di, ss
        sub     di, ax
        mov     es, di
        xor     bx, bx                  ; es:bx -> buffer for the FAT

        mov     ax, [bpbHiddenSectors]
        mov     dx, [bpbHiddenSectors+2]
        add     ax, [bpbReservedSectors]
        adc     dx, bx                  ; dx:ax = LBA

        call    ReadSector

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Reserve some memory for a root directory and load it whole ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        mov     bx, ax
        mov     di, dx                  ; save LBA to di:bx

        mov     ax, 32
        mov     si, [bpbRootEntries]
        mul     si
        div     word [bpbBytesPerSector]
        mov     cx, ax                  ; cx = root directory size in sectors

        mov     al, [bpbNumberOfFATs]
        cbw
        mul     word [bpbSectorsPerFAT]
        add     ax, bx
        adc     dx, di                  ; dx:ax = LBA

        push    es                      ; push FAT segment (2nd parameter)

        push    word ImageLoadSeg
        pop     es
        xor     bx, bx                  ; es:bx -> buffer for root directory

        call    ReadSector

        add     ax, cx
        adc     dx, bx                  ; adjust LBA for cluster data

        push    dx
        push    ax                      ; push LBA for data (1st parameter)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Look for a COM/EXE program to be load and run ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        mov     di, bx                  ; es:di -> root entries array
        mov     dx, si                  ; dx = number of root entries
        mov     si, ProgramName         ; ds:si -> program name

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Looks for a file with particular name ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Input:  DS:SI -> file name (11 chars) ;;
;;         ES:DI -> root directory array ;;
;;         DX = number of root entries   ;;
;; Output: SI = cluster number           ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

FindName:
        mov     cx, 11
FindNameCycle:
        cmp     byte [es:di], ch
        je      FindNameFailed          ; end of root directory
        pusha
        repe    cmpsb
        popa
        je      FindNameFound
        add     di, 32
        dec     dx
        jnz     FindNameCycle           ; next root entry
FindNameFailed:
        jmp     ErrFind
FindNameFound:
        mov     si, [es:di+1Ah]         ; si = cluster no.

;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Load entire a program ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;

ReadNextCluster:
        call    ReadCluster
        cmp     si, 0FF8h
        jc      ReadNextCluster         ; if not End Of File

;;;;;;;;;;;;;;;;;;;
;; Type checking ;;
;;;;;;;;;;;;;;;;;;;

        cli                             ; for stack adjustments

        mov     ax, ImageLoadSeg
        mov     es, ax

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Setup and Run COM program ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

        ;mov     ax, es
        ;sub     ax, 10h                 ; "org 100h" stuff :)
        xor	ax, ax
        
        mov     es, ax
        mov     ds, ax
        mov     ss, ax
        xor     sp, sp
        push    word es
        push    word 600h

        mov     dl, [cs:bsDriveNumber]  ; let program know boot drive
        sti
        retf

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Reads a FAT12 cluster      ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Inout:  ES:BX -> buffer    ;;
;;         SI = cluster no    ;;
;; Output: SI = next cluster  ;;
;;         ES:BX -> next addr ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ReadCluster:
        mov     bp, sp

        lea     ax, [si-2]
        xor     ch, ch
        mov     cl, [bpbSectorsPerCluster]
                ; cx = sector count
        mul     cx

        add     ax, [ss:bp+1*2]
        adc     dx, [ss:bp+2*2]
                ; dx:ax = LBA

        call    ReadSector

        mov     ax, [bpbBytesPerSector]
        shr     ax, 4                   ; ax = paragraphs per sector
        mul     cx                      ; ax = paragraphs read

        mov     cx, es
        add     cx, ax
        mov     es, cx                  ; es:bx updated

        mov     ax, 3
        mul     si
        shr     ax, 1
        xchg    ax, si                  ; si = cluster * 3 / 2

        push    ds
        mov     ds, [ss:bp+3*2]         ; ds = FAT segment
        mov     si, [ds:si]             ; si = next cluster
        pop     ds

        jnc     ReadClusterEven

        shr     si, 4

ReadClusterEven:
        and     si, 0FFFh               ; mask cluster value
ReadClusterDone:
        ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Reads a sector using BIOS Int 13h fn 2 ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Input:  DX:AX = LBA                    ;;
;;         CX    = sector count           ;;
;;         ES:BX -> buffer address        ;;
;; Output: CF = 1 if error                ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ReadSector:
        pusha

ReadSectorNext:
        mov     di, 5                   ; attempts to read

ReadSectorRetry:
        pusha
        
        pusha
        mov     ah, 0Eh
        mov     bx, 7
        mov	al, '.'
        int     10h                     ; 1st char
        popa

        div     word [bpbSectorsPerTrack]
                ; ax = LBA / SPT
                ; dx = LBA % SPT         = sector - 1

        mov     cx, dx
        inc     cx
                ; cx = sector no.

        xor     dx, dx
        div     word [bpbHeadsPerCylinder]
                ; ax = (LBA / SPT) / HPC = cylinder
                ; dx = (LBA / SPT) % HPC = head

        mov     ch, al
                ; ch = LSB 0...7 of cylinder no.
        shl     ah, 6
        or      cl, ah
                ; cl = MSB 8...9 of cylinder no. + sector no.

        mov     dh, dl
                ; dh = head no.

        mov     dl, [bsDriveNumber]
                ; dl = drive no.

        mov     ax, 201h
                                        ; al = sector count
                                        ; ah = 2 = read function no.

        int     13h                     ; read sectors
        jnc     ReadSectorDone          ; CF = 0 if no error

        xor     ah, ah                  ; ah = 0 = reset function
        int     13h                     ; reset drive

        popa
        dec     di
        jnz     ReadSectorRetry         ; extra attempt
        jmp     short ErrRead

ReadSectorDone:
        popa
        dec     cx
        jz      ReadSectorDone2         ; last sector

        add     bx, [bpbBytesPerSector] ; adjust offset for next sector
        add     ax, 1
        adc     dx, 0                   ; adjust LBA for next sector
        jmp     short ReadSectorNext

ReadSectorDone2:
        popa
        ret

;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Error Messaging Code ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;

ErrRead:
        mov     si, MsgErrRead
        jmp     short Error
ErrFind:
        mov     si, MsgErrFind
Error:
        mov     ah, 0Eh
        mov     bx, 7
.loop:
        lodsb
        cmp	al, 0
        je	.exit
        int     10h
        jmp	.loop
.exit:
	jmp     short $                 ; hang

;;;;;;;;;;;;;;;;;;;;;;
;; String constants ;;
;;;;;;;;;;;;;;;;;;;;;;

MsgErrRead      db      'Read error', 0
MsgErrFind      db      'File not found', 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Fill free space with zeroes ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

                times (512-13-($-$$)) db 0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Name of a program to be load and run ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ProgramName     db      "KERNEL  OS "   ; name and extension must be padded
                                        ; with spaces (11 bytes total)

;;;;;;;;;;;;;;;;;;;;;;;;;;
;; End of the sector ID ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;

                dw      0AA55h
