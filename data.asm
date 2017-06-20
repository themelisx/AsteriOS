struc	tss
.back	resw	2
.esp0	resd	1
.ss0	resw	2
.esp1	resd	1
.ss1	resw	2
.esp2	resd	1
.ss2	resw	2
.cr3	resd	1
.eip	resd	1
.eflags	resd	1
.eax	resd	1
.ecx	resd	1
.edx	resd	1
.ebx	resd	1
.esp	resd	1
.ebp	resd	1
.esi	resd	1
.edi	resd	1
.es	resw	2
.cs	resw	2
.ss	resw	2
.ds	resw	2
.fs	resw	2
.gs	resw	2
.ldt	resw	2
.trap	resw	1
.io	resw	1
.status resd	1
	endstruc

struc	mps	;MP Floating Pointer Structure
.signature	resd	1
.mpconfigptr	resd	1
.length		resb	1
.version	resb	1
.checksum	resb	1
.mpfeatures1	resb	1
.mpfeatures2	resb	1
.mpfeatures3	resb	1
.mpfeatures4	resb	1
.mpfeatures5	resb	1
	endstruc
	
struc	mpct	;MP Configuration Table
.signature	resd	1
.basetablelen	resw	1
.revision	resb	1
.checksum	resb	1
.oem		resb	8	;not null terminated
.productID	resb	12	;not null terminated
.OEMtableptr	resd	1
.OEMtablesize	resw	1
.entryCount	resw	1
.addrlocalAPIC	resd	1
.exttablelen	resw	1
.exttablechksum	resb	1
.firstentry	resb	1
endstruc

struc cpuentry	;CPU entries
.EntryType 	resb	1	;1 byte 	Since this is a processor entry, this field is set to 0.
.LocalAPICID 	resb 	1	;1 byte 	This is the unique APIC ID number for the processor.
.LocalAPICVer 	resb 	1	;1 byte 	This is bits 0-7 of the Local APIC version number register.
.CPUFlags	resb	1	;Enabled Bit 		 3:0 	1 bit 	This bit indicates whether the processor is enabled. If this bit is zero, the OS should not attempt to initialize this processor.
				;Bootstrap Processor Bit 3:1 	1 bit 	This bit indicates that the processor entry refers to the bootstrap processor if set.
.CPUSignature 	resd	1	;4 bytes 	This is the CPU signature as would be returned by the CPUID instruction. If the processor does not support the CPUID instruction, the BIOS fills this value according to the values in the specification.
.CPUFeatureFlags resd 	1	;4 bytes 	This is the feature flags as would be returned by the CPUID instruction. If the processor does not support the CPUID instruction, the BIOS fills this value according to values in the specification.
endstruc

struc busentry
.EntryType	resb	1
.ID		resb	1
.name		resd	1
.name2		resw	1
endstruc

BUSBiosInfo		db	'BUS ID:%d %s', 13, 0
BUSname			db	'xxxxxx', 0


%ifdef DEBUG
DebugMode		db	0	;1=enable
sPrintDebug		db	'PrintDebug', 0
sGetDebugMode		db	'GetDebugMode', 0
sSetDebugMode		db	'SetDebugMode', 0
%endif

WindowsArray		dd	0

ProcessArray		dd	0
CurrentProcess		db	0
InitMultitask		db	0

ReportNotFound		db	1	;report if not found (GetProcAddress)
SystemLoaded		db	0	;1=loaded
Multitasking		db	0	;1=enabled
tmp_eax			dd	0	;needed at multitasking
tmp_flags		dd	0
ShowClock		db	0	;1=show
PrintingClock		db	0

sMouseEvent		db	'mouse event #:%d at line:%d, pos:%d', 13, 0
PS2Mouse		db	'PS/2 mouse', 0
MousePresent		db	0
MouseEnabled		db	0
MouseQueue		dd	?
MouseQueuePtr		dd	?
mouse_x			dd	?
mouse_y			dd	?
mouse_btn		dd	?
mouse_line		dd	?
mouse_pos		dd	?

Mouse_Report		db	'pos:%d line:%d', 13, 0

VGA_Resolution db 'Video resolution: %dx%d',13,0

ScrollingWindow	db	0
GUILoaded	db	0
VgaNeedsUpdate	db	0
CharForPrint	db	' ', 0
cursor_line db  ?
cursor_pos	db  ?
cursor		dd	?
dwTotalMem  dw  ?
;Cursor_Line	dd	?
;Cursor_Pos	dd	?
VGA_Width	dd	?
VGA_Height	dd	?
LFB		dd	?	;pointer of LFB
OSM		dd	?	;Pointer to start of offscreen memory
OSM_Size	dd	?	;Offscreen memory in bytes
;rVGAmode	dw	?	;selected VGA mode
;rRAMsize	dw	?	;RAM size


Memory_Manager_Map		dd	?
Memory_Manager_Map_Size		dd	?
Memory_Manager_Table		dd	?
Memory_Manager_Table_Size 	dd	?
FunctionArray			dd	?
FunctionArraySize		dd	?

KernelAddress		dd	?

SaveNow			db	0
LastSector		dd	?

sGetKeyboardQueue	db	'GetKeyboardQueue', 0
GetKeyboardQueue	dd	0
sCheckCmdLineBuffer	db	'CheckCmdLineBuffer', 0
KeyboardCallback	dd	0
sSetKeyboardCallback db 'SetKeyboardCallback', 0
sGetKeyboardCallback db 'GetKeyboardCallback', 0

;kernel Strings
OS_Title		db	'AsteriOS v.0.16', 0
sKernelFileName		db	'a:\kernel.os', 0
myImage1 db 'a:\logo_sm.bmp', 0
LoadingMsg		db	'Loading AsteriOS...', 13, 'kernel v.0.16 (13/07/2010)', 13, 0
SystemHalted		db	13, 13, 'System Halted. Exception: 0x%x at 0x%x', 0
ExceptionX		db	13, 'Exception: 0x%x at 0x%x', 13, 0
ExceptionX_ErrorCode	db	13, 'Exception: 0x%x at 0x%x (error code:0x%x)', 13, 0
ExceptionX_Sel		db	13, 'Exception: 0x%x at selector 0x%x EIP 0x%x (error code:0x%x)', 13, 0
FunctionBarStr		db	' ', 0
;CurProcess		db	'CP:%d', 13, 0
OS_Prompt		db	'AsteriOS %s>', 0
ReportPageingIsOn db 'Memory paging enabled', 13, 0
System_Loaded		db	'System loaded', 13, 0
PagingEnabled		db	'Paging enabled', 13, 0
PageFault		db	'Page fault at 0x%x', 0
Memory_Table		db	'Memory map:', 13, 0
Memory_Table_Entry	db	'%x, size:%x', 13, 0
Memory_Table_EntryOwner db	' (%s)', 13, 0
sBios			db	'BIOS', 0
RamDetected		db	' RAM:%d/%d MB ', 0
SystemRam		db	'System memory: %d MB', 13, 0
Unhandle_IRQ		db	'Unhandle IRQ:0x%x', 13, 0
UpTimeMask		db	' ?d ??:??:??', 0
ClockMask		db	'  :  :  ', 0
Memory			db	'0123456789ABCDEF'
HexBuf			db	'    ', 0
DecimalBuf times 15	db	0
DecimalBufT times 15	db	0
Hardware_Info		db	'BIOS:%s', 13, 0
CannotFindImport	db	'Cannot find import: "%s"', 13, 0
PressAnyKey		db	'Press any key...', 13, 0
sDone			db	'Done', 13, 0

os_menu_bmp		db	'os_menu.bmp', 0
desktop_background	db	'desktop.bmp', 0

;device manager

;device's struct (10 bytes)
;DriverAddress			dd	?
;DMA Port			dw	?
;Channel			db	?
;IRQ				db	?
;Type				db	?
;Flags				db	?
	;0=enable
;DeviceName	times 42	db	?


;bus/port			dd	?
;device				dd	?
;function			dd	?
;vendor_id			dd	?
;device_id			dd	?
;class_code			dd	?
;subclass_code			dd	?
;revision_id			dd	?
;44+42


ScanPCI			db	'Scanning PCI...', 13, 0
PCIInfo			db	'PCI: %x %x %x %x', 13, 0

DeviceArray		dd	?

Debug_RegisterDevice	db	'Found: %s, driver:%x, DMA:%x, IRQ:%x', 13, 0

sRegisterDevice		db	'RegisterDevice', 0
sUnregisterDevice	db	'UnregisterDevice', 0

;display
MoveRealCursor		db 	0
VesaVBE2		db	'VBE2'
VESAoff			dw	?
VESAseg			dw	?
VESAVNoff		dw	?
VESAVNseg		dw	?
VESAPNoff		dw	?
VESAPNseg		dw	?
VESAPRoff		dw	?
VESAPRseg		dw	?
VESASV			dw	?
VesaVer			dw	?
Vesa1x			db	'VESA %d.%d %s', 13, 0
VesaStr			db	'VESA %d.%d %s', 13, '%s %s RAM:%d MB', 13, 'revision %s, software v.%d.%d', 13, 0
VesaMem			dw	?

;fat12
FAT12_Info		db	'BytesPerSector:%d', 13, \
				'SectorsPerCluster:%d', 13, \
				'ReservedSectors:%d', 13, \
				'NumberOfFATs:%d', 13, \
				'RootEntries:%d', 13, \
				'TotalSectors:%d', 13, \
				'Media:0x%x', 13, \
				'SectorsPerFAT:%d', 13, \
				'SectorsPerTrack:%d', 13, \
				'HeadsPerCylinder:%d', 13, \
				'HiddenSectors:%d', 13, \
				'TotalSectorsBig:0x%x', 13, \
				'DriveNumber:%d', 13, \
				'ExtBootSignature:0x%x', 13, \
				'SerialNumber:%x', 13, 0

FAT12_VolumeLabel	db      'Volume Label:', 0
FAT12_FileSystem	db      'File system:', 0



sDirListAt		db	'Directory listing at: "%s"', 13, 13, 0
sFile			db	'%s (%d bytes), %d/%d/%d %d:%d:%d', 13, 0
sDir			db	'<%s>', 13, 0
DirReport		db	13, '%d file(s), %d subdir(s)', 13, 'Total size: %d bytes', 13, 0

CurrentDirectoryEntry	db	0
DirTotalSize		dd	?
DirTotalFiles		dd	?
DirTotalDirs		dd	?
FirstRealSector		dd	?
BootSector		dd	?
FAT12_FAT_Map		dd	?
FAT12_FAT_Start		dd	?
FAT12_FAT_Size		dd	?
FAT12_DIR_Start		dd	?
FAT12_DIR_Size		dd	?
FAT12_Dir_Buffer	dd	?
FAT12_FAT_Buffer		dd	?
TmpFileName		times 13	db	?
TmpFileName2		times 13	db	?

;fileio
StorageDeviceArray		dd	?
;Open files array keeps file name, Driver addr, FS addr, and file pointer
OpenFilesArray			dd	?
;;;
CurrentDrive			db	'?:'
CurrentDirectory times 255 	db	0
;;;
tmpbuf				dd	?
CurrentSector			dd	?
FS_Addr				dd	?
DRV_Addr			dd	?

;floppy
Floppy360		db 	'Floppy 360 KB', 0
Floppy120		db	'Floppy 1.2 MB', 0
Floppy720		db	'Floppy 720 KB', 0
Floppy144		db	'Floppy 1.44 MB', 0

FDC_Motor_Timer		dd	?

track 			db 	0
sector 			db 	0
head			db 	0
fdcbuf			dd	0

FDC_Busy_Flag		db	0

dmamode			db 	0
fdc_irq_func		dd 	0
fdc_pump_func		dd 	0
fdc_st0			db 	0		;status register 0 of last resultphase.

sInit_FDC		db	'Init_FDC', 0
sFDC_Stop		db	'FDC_Stop', 0
sFDC_DO 		db	'FDC_Do', 0

;FDC_BufferOverFlow	db	'FDC buffer overflow', 13, 0

;loader
NoExecutable		db	'Executable is not compatible', 13, 0
NoExecutableHeader	db	'Executable header is not compatible', 13, 0
DrvSignature		db	'AsteriOS'

SystemIni		db	'system.ini', 0

;loader
LoadingExecutable	db	'Loading executable at 0x%x', 13, 0
ExecutableHeaderVersion	db	'Header version:%d.%d', 13, 0

;function names
sIsFileOpen		db	'IsFileOpen', 0
sGetMaxOpenFiles	db	'GetMaxOpenFiles', 0
sGetOpenFilesArray	db	'GetOpenFilesArray', 0
sSetProcAddress		db	'SetProcAddress', 0
sGetProcAddress		db	'GetProcAddress', 0
sCheckVMWare		db	'CheckVMWare', 0
sMemSet			db	'MemSet', 0
sStrCmp			db	'StrCmp', 0
sStrCpy			db	'StrCpy', 0
sStrLen			db	'StrLen', 0
sSetClockMode		db	'SetClockMode', 0
sClearScreen		db	'ClearScreen', 0
sGetCursor		db	'GetCursor', 0
sSetCursor		db	'SetCursor', 0

sPrintLine		db	'PrintLine', 0
sPrint			db	'Print', 0
sPrintC			db	'PrintC', 0
sPrintChar		db	'PrintChar', 0
sPrintHex		db	'PrintHex', 0
sPrintHexView		db	'PrintHexView', 0
sPrintCRLF		db	'PrintCRLF', 0
sPrintXY		db	'PrintXY', 0
sPrintMemoryMap		db	'PrintMemoryMap', 0
sShowClock		db	'ShowClock', 0
sPrintIRQList		db	'PrintIRQList', 0
sDeleteCurrentChar	db	'DeleteCurrentChar', 0
sPrintTextFile		db	'PrintTextFile', 0
sLoadExecutable		db	'LoadExecutable', 0
sDisable_IRQs		db	'Disable_IRQs', 0
sEnable_IRQ		db	'Enable_IRQ', 0
sEnable_IRQs		db	'Enable_IRQs', 0
sMemAlloc		db	'MemAlloc', 0
sMemFree		db	'MemFree', 0
sMemCpy			db	'MemCpy', 0
sHookInterrupt		db	'HookInterrupt', 0
sGetInterruptAddress	db	'GetInterruptAddress', 0
sGetSystemLoaded	db	'GetSystemLoaded', 0
sToUpper		db	'ToUpper', 0
sToLower		db	'ToLower', 0
sGetOSPrompt		db	'GetOSPrompt', 0
sOpenFile		db	'OpenFile', 0
sCloseFile		db	'CloseFile', 0
sGetFileSize		db	'GetFileSize', 0
sLoadFile		db	'LoadFile', 0
sDirList		db	'DirList', 0
sGetCurrentDirectory	db	'GetCurrentDirectory', 0
sCreateFile		db	'CreateFile', 0

IRQAndAddress		db	'IRQ 0x%x at 0x%x', 0

sDEVICE_CPU		db	'CPU', 0
sDEVICE_RAM		db	'RAM', 0
sDEVICE_VGA		db	'VGA', 0
sDEVICE_KEYBOARD	db	'Keyboard', 0
sDEVICE_MOUSE		db	'Mouse', 0
sDEVICE_IDE		db	'IDE', 0
sDEVICE_FLOPPY		db	'Floppy', 0
sDEVICE_NETWORK		db	'Network', 0
sDEVICE_USB		db	'USB', 0
sDEVICE_SOUND		db	'Sound', 0
sDEVICE_SERIALPORT	db	'COM', 0
sDEVICE_PARALERPORT	db	'LPT', 0
sDEVICE_MODEM		db	'Modem', 0
sDEVICE_PCMCIA		db	'PCMCIA', 0


;MemMgr
Mem_First_Entry		dd	?
FreeMem			dd	?
;MemoryBlockSize		dd	?

TotalMem		dd	?
dbNumHardDisks		db	?
dbNumFloppyDisks	db	?
dbInstEquipment		db	?
dbFloppyType		db	?

os_irq_mask		dd	0ffffffffh
dbBootDrive		db	?

uptime_sec		db	0
uptime_min		db	0
uptime_hours		db	0
uptime_days		dw	0		;max 0xFFFF days!

last_sec		dd	"0000"
cmos_sec		dd	"1234"
cmos_min		dd	"1234"
cmos_hour		dd	"1234"

OS_loops		dd	0
OS_loops2		dd	0

MyCounter1		db	'counter 1', 0
MyCounter2		db	'counter 2', 0

;cpu.asm
CPUBootstrap		db	'Boot ', 0
CPUBiosInfo		db	'CPU ID:%d, stepping:%x, model:%x, family:%x', 13, 0
CPUInfoStr		db	'CPU: %s, %s', 13, 'L1 cache:%d kb, L2 cache:%d kb', 13, 0
CPUIDInfo		db 	'????????????', 0
CPUBrand		db	'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx', 0
tscLo			dd	?
tscHi			dd	?
CPUSpeed		db 	'CPU speed: %d MHz', 13, 0

hBat			dd	?
szBat			dd	?
bufBat			dd	?
tmpBat			dd	?

h1			dd	?
buf			dd	?
sz			dd	?

startCount		dd 	0,0
totalCount		dd	0,0
CPU_Load_Flag		db	0
temp        		dd	0
sCPULoad		db	'CPU load: %d%%  ', 0

tmp			dd	?

;MyCDROMport		dw	0
;MyCDROMdrive		db	0
;port			dw	0
;drive			db	0
;command			db	0
;ATA_Buffer		dd	?

;CheckingATA		db	'Checking ATA, cmd:0x%x, port:0x%x, drive:0x%x', 13, 0
;ScaningHD		db	'Scaning HD drives...', 13, 0
;ScaningCD		db	'Scaning CD/DVD drives...', 13, 0
;ATAPMaster		db	'Primary Master: %s', 13, 0
;ATAPSlave		db	'Primary Slave: %s', 13, 0
;ATASMaster		db	'Secondary Master: %s', 13, 0
;ATASSlave		db	'Secondary Slave: %s', 13, 0

BiosSignature		times 512	db	?
TempBuffer		times 512	db	?