;max 255 windows
;128 bytes defined at WINDOWS_ARRAY_STRUCT_SIZE

STRUC sWindow
.flags		RESB 1		
	;0: set if present
	;1: set if visible
	;2: set if dirty (needs redraw)
.color		RESD 1		;inside color (not frame)
.top 		RESW 1		;in pixels
.left	 	RESW 1
.height		RESW 1		;in pixels
.width 		RESW 1
.z_order	RESB 1
.callback	RESD 1		;pointer to callback function (events)
.title		RESB 110	;109 + 1 bytes (asciiz)
ENDSTRUC 

;64 bytes
STRUC sObject
.parent 	RESD 1		;parent object ID
.type		RESB 1
.color		RESD 1
.visible 	RESB 1		;0=false, 1=true
.top		RESW 1
.left		RESW 1
.height		RESW 1
.width		RESW 1
.name 		RESB 46		;asciiz
ENDSTRUC