;debug messages
%ifdef DEBUG

FoundMP			db	'MP Floating Pointer at 0x%x', 13, 0
SetupIRQs		db	'Setting up IRQs', 13, 0
SetupPIC		db	'Setting up PIC', 13, 0
RunUnderVMWare		db	'[Warning] OS running under VMWare, hardware detection maybe fake', 13,  0
InitDisplay		db	'[Init] Display', 13, 0
Debug_InitMemMgr	db	'[Init] Memory Manager', 13, 0
Debug_SetMemPage	db	'Setting virtual mem 0x%x (%d blocks) at 0x%x', 13, 0
Debug_MemoryTable	db	'Memory table at 0x%x (size:%d)', 13, 0
Debug_MemoryMap		db	'Memory map at 0x%x (size:%d)', 13, 0
Debug_FunctionArray	db	'Function array at 0x%x (size:%d)', 13, 0
Debug_SetProcAddress	db	'SetProcAddress:"%s", 0x%x', 13, 0
Debug_InitLoader	db	'[Init] Loader', 13, 0
Debug_GetProcAddress	db	'GetProcAddress:"%s", 0x%x', 13, 0
Debug_ResolveImportTable db	'Resolving Import Table:0x%x', 13, 0
Debug_ResolveExportTable db	'Resolving Export Table:0x%x, image addr:0x%x', 13, 0
Debug_ResolveRelocationTable db	'Resolving Relocation Table:0x%x, image addr:0x%x', 13, 0
Debug_Disable_IRQs	db	'IRQs disabled', 13, 0
Debug_Enable_IRQs	db	'IRQs enabled', 13, 0
Debug_MemAlloc		db	'Allocating memory at 0x%x (%d bytes)', 13, 0
Debug_MemFree		db	'Free memory at 0x%x', 13, 0
Debug_Register_Kernel_Functions db 'Registering Kernel functions...', 13, 0
Debug_HookInterrupt	db	'Setting interrupt 0x%x at 0x%x', 13, 0
Debug_GetInterruptAddress db	'Getting interrupt 0x%x address (addr:0x%x)', 13, 0
Debug_PrintHexView	db	'PrintHexView at: 0x%x (size=%d)', 13, 0
Debug_DevMgr_Init	db	'[Init] Device manager', 13, 0
Debug_FAT12_Init	db	'[Init] FAT12', 13, 0
Debug_FileIO_Init	db	'[Init] File IO', 13, 0
Debug_FAT12_Main	db	'FAT12: Main: action:%d, file:"%s"', 13, 0
Debug_RegisterStorageDevice	db	'Registering storage device:%d, type: 0x%x, driver:0x%x, FS:0x%x', 13, 0
Debug_UnRegisterStorageDevice	db	'UnRegistering storage device:%d', 13, 0 
Debug_OpenFile			db	'Opening file:"%s"', 13, 0
Debug_CloseFile			db	'Closing file:"%s"', 13, 0
Debug_IsFileOpen		db	'Is file "%s" open ? (ret=0x%x)', 13, 0
Debug_LoadFile			db	'Loading file (handle=%x, buf=%x, size=%d)', 13, 0
;Debug_IsDriveMounted		db	'Is drive mounted ? (num=%d, ret=%d)', 13, 0
Debug_SetOpenFile		db	'Set openfile:%s, drv:%x, FS:%x, ptr:%d, size:%d, addr:%x', 13, 0
Debug_FileExists		db	'Is file "%s" exists ? (ret=0x%x)', 13, 0
;Debug_GetDriveDriver		db	'GetDriveDriver drive:%d (ret=0x%x)', 13, 0
;Debug_GetDriveFS		db	'GetDriveFS drive:%d (ret=0x%x)', 13, 0
;Debug_FDC_IRQ6		db	'[IRQ 6] at 0x%x', 13, 0
Debug_Init_FDC		db	'[Init] FDC', 13, 0
Debug_FDC_Stop		db	'[Stop] FDC', 13, 0
;Debug_FDC_StopMotor	db	'FDC Stop motor', 13, 0
;Debug_FDC_StartMotor	db	'FDC Start motor', 13, 0
;Debug_FDC_Done		db	'FDC Done', 13, 0
Debug_FDC_Read		db	'FDC Read: sector:%d, count:%d, buffer:0x%x', 13, 0
Debug_FDC_Write		db	'FDC Write: sector:%d, count:%d, buffer:0x%x', 13, 0
Debug_FDC_Do		db	'FDC Do: Operation:0x%x, fdd:%d, track:%d, head:%d, sector:%d, buffer:0x%x', 13, 0
%endif