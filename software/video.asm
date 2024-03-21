;
;   Wait for the next vertical blanking interval.
;
video_vsync:
    halt
    ret

;
;   Clear the screen.
;
;   Destroys:
;       AF, BC, DE, HL
;
video_clear:
    ; Clear the screen one half at a time.
    ld hl, VRAM_BASE
    ld c, 2

_outer:
    ; Synchronize to be sure that a vertical blank NMI does not
    ; occur while we are using the stack pointer to clear VRAM.
    call video_vsync

    ; Clear half of the screen.
    ld (sp_stash), sp
    ld de, $1000
    add hl, de
    ld sp, hl
    ld b, 0
    ld de, $0000

_inner:
    push de
    push de
    push de
    push de
    push de
    push de
    push de
    push de
    djnz _inner
    ld sp, (sp_stash)

    ; Next half of the screen.
    dec c
    jr nz, _outer

    ; Reset VRAM position.
    ld a, (VRAM_BASE)
    ret

;
;   Draw a rectangular frame.
;
;   Inputs:
;       H   Row (0-31) of the top left corner.
;       L   Column (0-31) of the top left corner.
;       D   Height of the rectangle.
;       E   Width of the rectangle.
;
;   Destroys:
;       A, BC, DE, HL, IX
;
video_draw_frame:
    ld c, d
    ld b, e

    ; Set DE to row/column of the top left corner.
    ; Set HL to row/column of the bottom right corner.
    ex de, hl
    add hl, de
    inc h
    inc l

    ; Draw top left and bottom right corners.
    ld a, $06
    call video_draw_character
    ex de, hl
    ld a, $03
    call video_draw_character
    ex de, hl

    ; Draw top and bottom horizontal lines.
    ld a, $01
_hloop:
    dec l
    call video_draw_character
    ex de, hl
    inc l
    call video_draw_character
    ex de, hl
    djnz _hloop

    ; Draw top right and bottom left corners.
    dec l
    ld a, $05
    call video_draw_character
    ex de, hl
    inc l
    ld a, $04
    call video_draw_character
    ex de, hl

    ; Draw left and right vertical lines.
    ld b, c
    ld a, $02
_vloop:
    dec h
    call video_draw_character
    ex de, hl
    inc h
    call video_draw_character
    ex de, hl
    djnz _vloop

    ret

;
;   Draw a character.
;
;   Inputs:
;       A   Character code to write.
;       H   Row (0-31) to place the character at.
;       L   Column (0-31) to place the character at.
;
;   Destroys:
;       IX
;
video_draw_character:
    ; This is a leaf routine. Use the shadow register set to reduce clobbering.
    push hl
    exx

    ; Compute VRAM address of the 4th pixel line of the row/column.
    ; The 4th row is used, because this way we can reach the first
    ; and last rows using relative offsets (-128 to 127).
    ; IX = VRAM_BASE + HL + $80
    ld bc, VRAM_BASE + $80
    pop ix
    add ix, bc

    ; Compute the font table address of the character to draw.
    ; HL = FONT_BASE + 8 * (A & $7F)
    ld bc, FONT_BASE
    ld h, 0
    ld l, a
    sla l
    add hl, hl
    add hl, hl
    add hl, bc

    ; Draw the character.
    ld (sp_stash), sp
    ld sp, hl
    pop bc
    ld (ix-$80), c
    ld (ix-$60), b
    pop bc
    ld (ix-$40), c
    ld (ix-$20), b
    pop bc
    ld (ix+$00), c
    ld (ix+$20), b
    pop bc
    ld (ix+$40), c
    ld (ix+$60), b
    ld sp, (sp_stash)

    ; Restore original registers.
    exx
    ret

;
;   Write null-terminated string into video memory.
;
;   Inputs:
;       DE  Pointer to string.
;       H   Screen row (0-31) of first character.
;       L   Screen column (0-31) of first character.
;
;   Destroys:
;       AF, BC, DE, HL
;
video_draw_text:
    ; IX = VRAM address of the 4th row of the first character.
    ; The 4th row is used, because this way we can reach the first
    ; and last rows using relative offsets (-128 to 127).
    ld bc, VRAM_BASE + $80
    add hl, bc
    push hl
    pop ix
    ld (sp_stash), sp

_loop:
    ; Load next character. If null terminator, exit loop.
    ld a, (de)
    sla a
    jr z, _done

    ; SP = FONT_BASE + 8 * (A & $7F)
    ld bc, FONT_BASE
    ld h, 0
    ld l, a
    add hl, hl
    add hl, hl
    add hl, bc
    ld sp, hl

    ; Copy character data into VRAM.
    pop hl
    ld (ix-$80), l
    ld (ix-$60), h
    pop hl
    ld (ix-$40), l
    ld (ix-$20), h
    pop hl
    ld (ix+$00), l
    ld (ix+$20), h
    pop hl
    ld (ix+$40), l
    ld (ix+$60), h

    ; Next character.
    inc ix
    inc de
    jp _loop

_done:
    ld sp, (sp_stash)
    ret

;
;   Draw a number (stored as BCD digits) into video memory.
;
;   Parameters:
;       DE  Pointer to number.
;       B   Number of digit pairs to draw.
;       H   Target row.
;       L   Target column.
;
;   Destroys:
;       AF, B, DE, L, IX
;
video_draw_number:
    ; If bit 7 of B is set, skip leading zeroes.
    bit 7, b
    jr nz, _skip

_draw_loop:
    ld a, (de)
_draw_upper:
    and $F0
    rrca
    rrca
    rrca
    rrca
    add a, '0'
    call video_draw_character
    inc l
    ld a, (de)
    inc de
_draw_lower:
    and $0F
    add a, '0'
    call video_draw_character
    inc l
    djnz _draw_loop
    ret

_skip:
    res 7, b
_skip_loop:
    ld a, (de)
    cp $10
    jr nc, _draw_upper
    inc de
    and a
    jr nz, _draw_lower
    djnz _skip_loop

    ld a, '0'
    call video_draw_character
    ret
