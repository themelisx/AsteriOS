ALIGN 4

; 32 ring 0 interrupt gates
idt:
	;times 48	dw 0, SYS_CODE_SEL, 8E00h, 0
	times 48	dw 0, SYS_CODE_SEL, 8E00h, 0

; one ring 3 interrupt gate for syscalls (INT 30h)
	dw 0		; offset 15:0
	dw SYS_CODE_SEL	; selector
	db 0		; (always 0 for interrupt gates)
	db 0EEh		; present,ring 3,'386 interrupt gate
	dw 0		; offset 31:16

idt_end:

idt_ptr:
	dw idt_end - idt - 1	; IDT limit
	dd idt			; linear adr of IDT (set above)