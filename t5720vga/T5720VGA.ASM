.MODEL  TINY
.CODE
LOCALS
;------------------------------------------------------------------------------
CMOS_CRC16_HI	EQU	7Ch
CMOS_CRC16_LO	EQU	7Dh
CMOS_VGA_MEM	EQU	64h
;------------------------------------------------------------------------------
	ORG     100h

Start:
;------------------------------------------------------------------------------
; ax - multipurpose
; bh - memory size setting (cmos byte)
; bl - memory size to allocate
; cx - multipurpose
; dx - cmos checksum
; bp - index / tmp var
;------------------------------------------------------------------------------
	mov	dx, OFFSET str_intro
	call	PrintString

	mov	al, CMOS_CRC16_HI
	call	GetCMOSByte
	mov	dh,al

	mov	al, CMOS_CRC16_LO
	call	GetCMOSByte
	mov	dl, al			; dx = cmos checksum

	or	dx, dx			; is checksum <> 0
	jnz	@@passed
	mov	dx, OFFSET str_warning	; bogus checksum, blocked port access probably
	call	PrintString
	jmp	@@exit

@@passed:
	mov	di, OFFSET str_checksum
	call	WordToStr		; convert dx to string

	mov	al, CMOS_VGA_MEM
	call	GetCMOSByte
	xor	ah, ah			; subtract setting byte from current checksum
	sub	dx, ax			; it will be updated later

	mov	bh, al			; keep current setting in bh
	and	al, 0Ch			; mask, keep vga share menory bits only
	shr	al, 1			; (al >> 2, al << 1), this will serve as index
	mov 	bp, ax			; move it to index register
	mov	si, WORD PTR [str_settings + bp] ; get current setting string
	mov	di, OFFSET str_setting
	movsw				; and copy it
	movsb

	call	GetParameters		; bl = memory size to allocate if returned from

	xor	ah, ah
	mov	al, bl			; al = new setting
	shl	al, 1			; *2 to create index
	mov	bp, ax			; move it to index register
	mov	si, WORD PTR [str_settings + bp] ; get new setting string
	mov	di, OFFSET str_setting
	movsw				; copy string
	movsb

	shl	al, 1			; *2 to place new setting bits at right position (bits 2 and 3)
	mov	ah, bh			; ah = current setting
	and	ah, 0F3h		; clear vga share memory bits in current setting
	or	al, ah			; copy other bits from current to new setting
	xor	ah, ah
	add	dx, ax			; update checksum
	mov	bl, al			; keep new settings byte

	mov	di, OFFSET str_checksum
	call	WordToStr		; convert dx to string

	xchg	dx, bp			; keep current checksum

	mov	dx, OFFSET str_new
	call	PrintString
	mov	dx, OFFSET str_setting
	call	PrintString

	xchg	bp, dx			; restore it

	cmp	bl, bh			; compare new with current settings
	jne	@@update

	mov	dx, OFFSET str_match	; new setting matches current, no need to update
	call	PrintString
	jmp	short @@exit

@@update:
	mov	ah, bl			; update CMOS setting and checksum
	mov	al, CMOS_VGA_MEM
	call	SetCMOSByte

	mov	ah, dh
	mov	al, CMOS_CRC16_HI
	call	SetCMOSByte
	mov	ah, dl
	mov	al, CMOS_CRC16_LO
	call	SetCMOSByte

	mov	cx, dx			; move checksum to cx

	mov	dx, OFFSET str_update
	call	PrintString
	mov	dx, OFFSET str_failed

	mov	al, CMOS_VGA_MEM	; verify CMOS
	call	GetCMOSByte
	cmp	al, bl
	jne	@@failed

	mov	al, CMOS_CRC16_HI
	call	GetCMOSByte
	cmp	al, ch
	jne	@@failed

	mov	al, CMOS_CRC16_LO
	call	GetCMOSByte
	cmp	al, cl
	jne	@@failed

	mov	dx, OFFSET str_success
@@failed:
	call	PrintString

@@exit:
	mov	ah, 4Ch			; exit
	int	21h
	ret

;------------------------------------------------------------------------------

PrintString PROC
	mov	ah, 9
	int	21h
	ret
ENDP


GetParameters PROC
	cmp	BYTE PTR ds:[80h], 4	; parameters string length
	jne	@@128
@@16:
	cmp	WORD PTR ds:[83h], '61'	; skip space and slash, check parameter value
	jne	@@32
	xor	bl, bl			; 16MB
	ret
@@32:
	cmp	WORD PTR ds:[83h], '23'	; skip space and slash, check parameter value
	jne	@@64
	mov	bl, 1			; 32MB
	ret
@@64:
	cmp	WORD PTR ds:[83h], '46'	; skip space and slash, check parameter value
	jne	@@128
	mov	bl, 2			; 64MB
	ret
@@128:
	cmp	BYTE PTR ds:[80h], 5	; parameters str length
	jne	@@usage
	cmp	WORD PTR ds:[83h], '21'	; skip space and slash, check parameter value
	jne	@@usage
	cmp	BYTE PTR ds:[85h], '8'	; this one is 3 bytes long
	jne	@@usage
	mov	bl, 3			; 128MB
	ret

@@usage:
	mov	dx, OFFSET str_usage
	call	PrintString

	mov	dx, OFFSET str_current
	call	PrintString
	mov	dx, OFFSET str_setting
	call	PrintString

	mov	ah, 4Ch			; exit
	int	21h
	ret
ENDP


GetCMOSByte PROC
	xchg	bx, bx
	nop
	out	70h, al			; write to cmos address port
	jcxz	$+2			; delay
	jcxz	$+2	
	xchg	bx, bx
	in	al, 71h			; read from cmos data port
	jcxz	$+2
	jcxz	$+2	
	ret
ENDP


SetCMOSByte PROC
	nop
	out	70h, al			; write to cmos address port
	jcxz	$+2			; delay
	jcxz	$+2
	xchg	al, ah
	out	71h, al			; write to cmos data port
	jcxz	$+2
	jcxz	$+2	
	ret
ENDP


WordToStr PROC
	mov	cx, 4			; 4 digits / letters
@@convert:
	rol	dx, 4			; most significant nibble goes least significant
	mov	ax, dx			; copy to accumulator
	and	ax, 000Fh		; leave least significant nibble, clear others
	add	al, '0'			; convert to ascii digit
	cmp	al, '9'                 ; check if it's letter
	jna	@@not_letter
	add	al, 7                   ; update to ascii letter
@@not_letter:
	stosb				; store ascii
	loop	@@convert		; do another nibble
	ret
ENDP


;------------------------------------------------------------------------------
.DATA
;------------------------------------------------------------------------------

str_intro:
	DB	"HP T5720 VGA Share Memory Setup Utility v1.00", 13, 10
	DB	"Coded by: tmk, e-mail: tmk@tuta.io", 13, 10
	DB	"Project page: https://github.com/gitendo/t5720/", 13, 10, 13, 10, "$"
str_usage:
	DB	"Usage: T5720VGA.COM [Option]", 13, 10
	DB	"       /16  - allocate  16MB to the integrated graphics processor", 13, 10
	DB	"       /32  - allocate  32MB to the integrated graphics processor", 13, 10
	DB	"       /64  - allocate  64MB to the integrated graphics processor", 13, 10
	DB	"       /128 - allocate 128MB to the integrated graphics processor", 13, 10, 13, 10, "$"
str_settings:
	DW 	@@16, @@32, @@64, @@128
@@16:
	DB	" 16"
@@32:
	DB	" 32"
@@64:
	DB	" 64"
@@128:
	DB	"128"
str_warning:
	DB	"Can't access CMOS ports directly! Use it with DOS or Windows 9x only!", 13, 10, "$"
str_current:
	DB	"Current memory setting:", "$"
str_new:
	DB	"New memory setting:", "$"
str_setting:
	DB	"000MB, checksum: "
str_checksum:
	DB	"0000h", 13, 10, 13, 10, "$"
str_match:
	DB	"This memory setting is already in effect.", 13, 10, "$"
str_update:
	DB	"CMOS update ", "$"
str_success:
	DB	"successful! Reboot for the change to take effect.", 13, 10, "$"
str_failed:
	DB	"failed!", 13, 10, "$"

;------------------------------------------------------------------------------
        END     Start		; defines the entry point as start
;------------------------------------------------------------------------------
