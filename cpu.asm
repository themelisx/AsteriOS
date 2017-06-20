;CPU informations
Init_CPU:
	pushad
	mov	eax, 80000002h
	cpuid	
	mov	edi, CPUBrand
	mov	dword [edi], eax
	mov	dword [edi+4], ebx
	mov	dword [edi+8], ecx
	mov	dword [edi+12], edx
	mov	eax, 80000003h
	cpuid	
	mov	dword [edi+16], eax
	mov	dword [edi+20], ebx
	mov	dword [edi+24], ecx
	mov	dword [edi+28], edx
	mov	eax, 80000004h
	cpuid	
	mov	dword [edi+32], eax
	mov	dword [edi+36], ebx
	mov	dword [edi+40], ecx
	mov	dword [edi+44], edx
	mov	byte  [edi+48], 0	

	push	dword CPUBrand	
	push	dword 0		;driver
	push	dword 0		;port
	push	dword 0		;channel unused
	push	dword 0		;irq
	push	dword DEVICE_CPU
	push	dword 1		;bit 0 = enable
	call	RegisterDevice
	
	popad
	ret
	
DetectCPU:
	;Multiple Processor Detection
	;9FC00-9FFFF 	extended BIOS data area (EBDA)
	;F0000-FFFFF	ROM - motherboard BIOS (64K is typical size)
	
	;Finding the MP Floating Pointer Structure
	
	;MP Floating Pointer Structure
	;Field 	Offset 	Length 	Description/Use
	;Signature 	0 	4 bytes 	This 4 byte signature is the ASCII string "_MP_" which the OS should use to find this structure.
	;MPConfig Pointer 	4 	4 bytes 	This is a 4 byte pointer to the MP configuration structure which contains information about the multiprocessor configuration.
	;Length 	8 	1 byte 	This is a 1 byte value specifying the length of this structure in 16 byte paragraphs. This should be 1.
	;Version 	9 	1 byte 	This is a 1 byte value specifying the version of the multiprocessing specification. Either 1 denoting version 1.1, or 4 denoting version 1.4.
	;Checksum 	10 	1 byte 	The sum of all bytes in this floating pointer structure including this checksum byte should be zero.
	;MP Features 1 	11 	1 byte 	This is a byte containing feature flags.
	;MP Features 2 	12 	1 byte 	This is a byte containing feature flags. Bit 7 reflects the presence of the ICMR, which is used in configuring the IO APIC.
	;MP Features 3-5 	13 	3 bytes 	Reserved for future use.
	pushad
	
	mov	esi, 9FC00h
	mov	edi, esi
	mov	ecx, 400h		;9FFFF - 9FC00
	jmp	.loop
.scan2:
	mov	esi, 0F0000h
	mov	edi, esi
	mov	ecx, 0FFFFh
.loop:
	push	esi
	lodsd
	pop	esi
	cmp	eax, '_MP_'
	je	.found
	inc	esi
	dec	ecx
	jnz	.loop
	
	cmp	edi, 0F0000h		;second parse ?
	jne	.scan2
	jmp	.exit
	
.found:
	%ifdef DEBUG
	push	esi
	push	dword FoundMP
	call	Print
	%endif
	
	cmp	byte [esi+mps.mpfeatures1], 0		;If MP Features 1 is non-zero, this indicates that the system is one of 
							;the default configurations as described in the Intel Multiprocessing 
							;Specification Chapter 5.
	je	.ok1
	jmp	.exit
.ok1:
	;if this byte is zero, then the value in MPConfig Pointer is a valid pointer to the 
	;physical address of the MP Configuration Table
	mov	eax, dword [esi+mps.mpconfigptr]
	
	cmp	dword [eax], 'PCMP'	;4 byte signature is the ASCII string "PCMP" which confirms that this table is present.
	je	.ok2
	jmp	.exit
.ok2:
	
	;MP Configuration Table
	;Field 			Offset 	Length 		Description/Use
	;Signature 		0 	4 bytes 	This 4 byte signature is the ASCII string "PCMP" which confirms that this table is present.
	;Base Table Length 	4 	2 bytes 	This 2 byte value represents the length of the base table in bytes, including the header, starting from offset 0.
	;Specification Revision 6 	1 byte 		This 1 byte value represents the revision of the specification which the system complies to. A value of 1 indicates version 1.1, a value of 4 indicates version 1.4.
	;Checksum 		7 	1 byte 		The sum of all bytes in the base table including this checksum and reserved bytes must add to zero.
	;OEM ID 		8 	8 bytes 	An ASCII string that identifies the manufacturer of the system. This string is not null terminated.
	;Product ID 		16 	12 bytes 	An ASCII string that identifies the product family of the system. This string is not null terminated.
	;OEM Table Pointer 	28 	4 bytes 	An optional pointer to an OEM-defined configuration table. If no OEM table is present, this field is zero.
	;OEM Table Size 	32 	2 bytes 	The size (if it exists) of the OEM table. If the OEM table does not exist, this field is zero.
	;Entry Count 		34 	2 bytes 	The number of entries following this base header table in memory. This allows software to find the end of the table when parsing the entries.
	;Address of Local APIC 	36 	4 bytes 	The physical address where each processor's local APIC is mapped. Each processor memory maps its own local APIC into this address range.
	;Extended Table Length 	40 	2 bytes 	The total size of the extended table (entries) in bytes. If there are no extended entries, this field is zero.
	;Extended Table Chksum 	42 	1 byte 		A checksum of all the bytes in the extended table. All off the bytes in the extended table must sum to this value. If there are no extended entries, this field is zero.
	
	cld
	mov	esi, eax
	push	esi
	
	add	esi, mpct.oem
	mov	edi, TempBuffer
	mov	eax, 'CPU:'
	stosd
	mov	ecx, 20			;oem and product id
	rep	movsb
	mov	byte [edi], 0
	
	push	TempBuffer
	call	Print
	
	mov	eax, dword [esi+mps.mpconfigptr]
	push 	dword [eax+mpct.addrlocalAPIC]
	call	PrintHex
	
	mov	esi, 0FEE00000h		;default local APIC addr
	add	esi, 0F0h 		;Spurious-Interrupt Vector Register 	Bits 0-3 Read only, Bits 4-9 Read/Write
	mov	eax, dword [esi]
	or	eax, 10000000b		;enable local apic
	or	eax, 00100000b		;set vector to int 2F
	mov	dword [esi], eax
	
	call	PrintCRLF
	
	pop	esi
	movzx	ecx, word [esi+mpct.entryCount]
	
	;push	ecx
	;call	PrintHex
	;call	PrintCRLF
	
	add	esi, 44		;mpct struct size + 1
	
	;Processor Entry
	;Field 			Offset (in bytes:bits) 	Length 	Description/Use
	;Entry Type 		0 	1 byte 	Since this is a processor entry, this field is set to 0.
	;Local APIC ID 		1 	1 byte 	This is the unique APIC ID number for the processor.
	;Local APIC Ver		2 	1 byte 	This is bits 0-7 of the Local APIC version number register.
	;CPU Enabled Bit 	3:0 	1 bit 	This bit indicates whether the processor is enabled. If this bit is zero, the OS should not attempt to initialize this processor.
	;CPU Bootstrap CPU Bit 	3:1 	1 bit 	This bit indicates that the processor entry refers to the bootstrap processor if set.
	;CPU Signature 		4 	4 bytes 	This is the CPU signature as would be returned by the CPUID instruction. If the processor does not support the CPUID instruction, the BIOS fills this value according to the values in the specification.
	;CPU Feature flags 	8 	4 bytes 	This is the feature flags as would be returned by the CPUID instruction. If the processor does not support the CPUID instruction, the BIOS fills this value according to values in the specification.
	
.loop2:
	cmp	byte [esi+cpuentry.EntryType], 0
	jne	.bus
	
	movzx 	eax, byte [esi+cpuentry.CPUFlags]
	
	test	eax, 00000001b		;If zero, this processor is unusable
	jz	.unusableCPU
	test	eax, 00000010b		;Set if specified processor is the bootstrap processor
	jz	.notBootstrap
	
	push	CPUBootstrap
	call	Print
	jmp	.next
	
.notBootstrap:
	;init this cpu
	push	esi
	mov	esi, 0FEE00000h		;default local APIC addr
	add	esi, 0300h 		;Interrupt Command Register 0-31 	Read/Write
	;mov	eax, dword [esi]	
	;01 00 00000 110 0000010
	mov	eax, 1010000000b
	mov	dword [esi], eax
	pop	esi
	
.next:
	mov 	eax, dword [esi+cpuentry.CPUSignature]
	and 	eax, 0000111100000000b	;family
	ror	eax, 8
	push	eax
	
	mov 	eax, dword [esi+cpuentry.CPUSignature]
	and 	eax, 0000000011110000b	;model
	ror	eax, 4
	push	eax	
	mov 	eax, dword [esi+cpuentry.CPUSignature]
	
	and 	eax, 0000000000001111b	;stepping
	push	eax
	
	movzx 	eax, byte [esi+cpuentry.LocalAPICID]
	push	eax
	push	dword CPUBiosInfo
	call	Print
	
	;lodsd
	;lodsd
	;push	eax
	;call	PrintHex
	;lodsd
	;push	eax
	;call	PrintHex
	;call	PrintCRLF
	;add	esi, 8
.unusableCPU:	
	add	esi, 20	
	jmp	.loop2
	
	;APIC Memory Mappings
	;APIC 	Type 		Default address Alternate Address
	;Local 	APIC 		0xFEE00000 	If specified, the value of the Address of Local APIC field in the MP Configuration Table.
	;First 	IO APIC 	0xFEC00000 	If specified, the value of the IO APIC Address field in the IO APIC entry in the MP Configuration Table.
	;Additional IO APICs 	- 	The value of the IO APIC Address field in the IO APIC entry in the MP Configuration Table.
.bus:
	cmp	byte [esi+busentry.EntryType], 1 	;bus
	jne	.ioapic	
	
	mov	edi, dword BUSname
	mov	eax, dword [esi+busentry.name]
	stosd
	mov	ax, word [esi+busentry.name2]
	stosw
	sub	edi, 6
	
	push	edi	
	movzx	eax, byte [esi+busentry.ID]
	push	eax
	push	BUSBiosInfo
	call	Print
	
	add	esi, 8
	jmp	.bus
	
.ioapic:
	cmp	byte [esi+cpuentry.EntryType], 2 	;IO APIC
	jne	.ioint
	
	add	esi, 8
	jmp	.ioapic
	
.ioint:
	cmp	byte [esi+cpuentry.EntryType], 3 	;IO Interrupt Assignment
	jne	.locint
	
	add	esi, 8
	jmp	.ioint
	
.locint:
	cmp	byte [esi+cpuentry.EntryType], 4 	;Local Interrupt Assignment
	jne	.exit
	
	add	esi, 8
	jmp	.locint
		
.exit:	
	popad
	
	ret
	
ShowCPUInfo:
	pushad
	mov	eax, 0
	cpuid	
	mov	edi, CPUIDInfo
	mov	dword [edi], ebx
	add	edi, 4
	mov	dword [edi], edx
	add	edi, 4
	mov	dword [edi], ecx	
	
	mov	eax, 80000002h
	cpuid	
	mov	edi, CPUBrand
	mov	dword [edi], eax
	mov	dword [edi+4], ebx
	mov	dword [edi+8], ecx
	mov	dword [edi+12], edx
	mov	eax, 80000003h
	cpuid	
	mov	dword [edi+16], eax
	mov	dword [edi+20], ebx
	mov	dword [edi+24], ecx
	mov	dword [edi+28], edx
	mov	eax, 80000004h
	cpuid	
	mov	dword [edi+32], eax
	mov	dword [edi+36], ebx
	mov	dword [edi+40], ecx
	mov	dword [edi+44], edx
	
	mov	eax, 80000005h		;L1 cache
	cpuid
	mov	eax, ecx
	shr	eax, 24
	
	;eax has L1 cache
	push	eax
	
	mov	eax, 80000006h		;L2 cache
	cpuid
	mov	eax, ecx
	shr	eax, 16
	
	;eax has L2 cache
	mov	ebx, eax
	pop	eax			;L1 cache

	push	ebx			;L2
	push	eax			;L1
	push	dword CPUBrand
	push	dword CPUIDInfo
	push	dword CPUInfoStr
	call	Print
	
	;Are we running under VMWare ?
	call	CheckVMWare
	jnc	CPUCheckSpeed
	jmp	CPUdontCheckSpeed
CPUCheckSpeed:
	
;find real CPU spped
	
	in	al, 61h
	and	al, 10h
	mov	ah, al
CPUwait1:
	in	al, 61h
	and	al, 10h
	cmp	al, ah
	jz	CPUwait1

	mov	eax, 0
	cpuid
	
	rdtsc

	mov	dword [tscLo], eax
	mov	dword [tscHi], edx
	mov	ecx, 16500
	
	in	al, 61h
	and	al, 10h
	mov	ah, al
CPUwait2:
	in	al, 61h
	and	al, 10h
	cmp	al, ah
	jz	CPUwait2

	mov	ah,al
	dec	ecx
	jnz	CPUwait2

	mov	eax, 0
	cpuid
	rdtsc
	sub	eax, dword [tscLo]
	sbb	edx, dword [tscHi]

	mov	ebx, 1193181		;PIT input frequency
	mul	ebx
	mov	ebx, 297000		;250*66*18
	div	ebx
	mov	ebx, 1000 ;000
	xor	edx,edx
	div	ebx
	;mov	[os_cpu_frequency_khz],eax	;get KHz
	
	xor	edx,edx
	div	ebx
	;mov	[os_cpu_frequency_mhz],eax	;get Mhz
	
	push	eax
	push	dword CPUSpeed
	call	Print	

CPUdontCheckSpeed:
	popad
	ret
	
        
