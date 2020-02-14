	push	dword 20h
	push	dword int20_hand
	call	HookInterrrupt
	
	push	dword 21h
	push	dword int21_hand
	call	HookInterrrupt
	
	push	dword 22h
	push	dword int22_hand
	call	HookInterrrupt
	
	push	dword 23h
	push	dword int23_hand
	call	HookInterrrupt
	
	push	dword 24h
	push	dword int24_hand
	call	HookInterrrupt
	
	push	dword 25h
	push	dword int25_hand
	call	HookInterrrupt

	push	dword 26h
	push	dword int26_hand
	call	HookInterrrupt

	push	dword 27h
	push	dword int27_hand
	call	HookInterrrupt
	
	push	dword 28h
	push	dword int28_hand
	call	HookInterrrupt

	push	dword 29h
	push	dword int29_hand
	call	HookInterrrupt
	
	push	dword 2Ah
	push	dword int2A_hand
	call	HookInterrrupt
	
	push	dword 2Bh
	push	dword int2B_hand
	call	HookInterrrupt

	push	dword 2Ch
	push	dword int2C_hand
	call	HookInterrrupt

	push	dword 2Dh
	push	dword int2D_hand
	call	HookInterrrupt
	
	push	dword 2Eh
	push	dword int2E_hand
	call	HookInterrrupt

	push	dword 2Fh
	push	dword int2F_hand
	call	HookInterrrupt
	
	push	dword 30h
	push	dword int30_hand
	call	HookInterrrupt