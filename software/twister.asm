TWISTER_ROM_BASE:               equ $
TWISTER_RAM_BASE:               equ GAME_RAM_BASE

; --- RAM ---------------------------------------------------------------------

org TWISTER_RAM_BASE

twister_counter1:               ds 2
twister_counter2:               ds 2

twister_phi:                    ds 2
twister_x:                      ds 1
twister_y:                      ds 1
twister_x1:                     ds 1
twister_x2:                     ds 1
twister_x3:                     ds 1
twister_x4:                     ds 1

twister_vram_cursor:            ds 2
twister_vram_buffer:            ds 16*32

TWISTER_RAM_SIZE:               equ $ - PONG_RAM_BASE

if TWISTER_RAM_SIZE > GAME_RAM_SIZE
    .error "Out of game RAM space!"
endif

; --- ROM ---------------------------------------------------------------------

org TWISTER_ROM_BASE

twister_sin_lut:
    db $00, $03, $06, $09, $0C, $0F, $12, $15
    db $18, $1B, $1E, $21, $24, $27, $2A, $2D
    db $30, $33, $36, $39, $3B, $3E, $41, $43
    db $46, $49, $4B, $4E, $50, $52, $55, $57
    db $59, $5B, $5E, $60, $62, $64, $66, $67
    db $69, $6B, $6C, $6E, $70, $71, $72, $74
    db $75, $76, $77, $78, $79, $7A, $7B, $7B
    db $7C, $7D, $7D, $7E, $7E, $7E, $7E, $7E
    db $7F, $7E, $7E, $7E, $7E, $7E, $7D, $7D
    db $7C, $7B, $7B, $7A, $79, $78, $77, $76
    db $75, $74, $72, $71, $70, $6E, $6C, $6B
    db $69, $67, $66, $64, $62, $60, $5E, $5B
    db $59, $57, $55, $52, $50, $4E, $4B, $49
    db $46, $43, $41, $3E, $3B, $39, $36, $33
    db $30, $2D, $2A, $27, $24, $21, $1E, $1B
    db $18, $15, $12, $0F, $0C, $09, $06, $03
    db $00, $FD, $FA, $F7, $F4, $F1, $EE, $EB
    db $E8, $E5, $E2, $DF, $DC, $D9, $D6, $D3
    db $D0, $CD, $CA, $C7, $C5, $C2, $BF, $BD
    db $BA, $B7, $B5, $B2, $B0, $AE, $AB, $A9
    db $A7, $A5, $A2, $A0, $9E, $9C, $9A, $99
    db $97, $95, $94, $92, $90, $8F, $8E, $8C
    db $8B, $8A, $89, $88, $87, $86, $85, $85
    db $84, $83, $83, $82, $82, $82, $82, $82
    db $81, $82, $82, $82, $82, $82, $83, $83
    db $84, $85, $85, $86, $87, $88, $89, $8A
    db $8B, $8C, $8E, $8F, $90, $92, $94, $95
    db $97, $99, $9A, $9C, $9E, $A0, $A2, $A5
    db $A7, $A9, $AB, $AE, $B0, $B2, $B5, $B7
    db $BA, $BD, $BF, $C2, $C5, $C7, $CA, $CD
    db $D0, $D3, $D6, $D9, $DC, $DF, $E2, $E5
    db $E8, $EB, $EE, $F1, $F4, $F7, $FA, $FD

;
;   Compute sine.
;
;   Inputs:
;       A   Phase in binary radians (0-255).
;
;   Outputs:
;       A   Sine value, -127 to +127.
;
twister_sin:
    exx
    ld d, 0
    ld e, a
    ld hl, twister_sin_lut
    add hl, de
    ld a, (hl)
    exx
    ret

;
;   Draw horizontal line in the VRAM buffer.
;
;   Inputs:
;       A   Pattern
;       H   Y
;       D   X start
;       E   X end
;
twister_draw_line:
    ld (r0), a

    ld a, e
    cp d
    ret c

    ; Starting mask
    ld a, 1
    srl d
    jr nc, _start_shift1
    rlca
_start_shift1:
    srl d
    jr nc, _start_shift2
    rlca
    rlca
_start_shift2:
    srl d
    jr nc, _start_shift3
    rlca
    rlca
    rlca
    rlca
_start_shift3:
    dec a
    cpl
    ld b, a

    ; Ending mask
    ld a, 1
    srl e
    jr nc, _end_shift1
    rlca
_end_shift1:
    srl e
    jr nc, _end_shift2
    rlca
    rlca
_end_shift2:
    srl e
    jr nc, _end_shift3
    rlca
    rlca
    rlca
    rlca
_end_shift3:
    dec a
    ld c, a

    ; B = start mask
    ; C = end mask

    ; Save mask
    push bc

    ; HL = buffer address
    ld a, 0
    srl h
    rra
    srl h
    rra
    srl h
    rra
    or d
    ld l, a
    ld bc, twister_vram_buffer
    add hl, bc

    ; Number of bytes
    ld a, e
    sub d
    inc a
    ld b, a

    pop de

_loop:
    dec b
    jr z, _final

    ld a, d
    cpl
    and (hl)
    ld c, a
    ld a, (r0)
    and d

    ld a, (r0)
    and d
    or c

    ld (hl), a
    inc hl

    ld a, $FF
    ld d, a

    jr _loop

_final:
    ld a, d
    and e
    cpl
    and (hl)
    ld c, a
    ld a, (r0)
    and d
    and e
    or c
    ld (hl), a

    ret

twister_main:
    call clear_screen
    ld a, (VRAM_BASE)

    ld de, VRAM_BASE + $1E00
    ld (twister_vram_cursor), de

_frame:
    ; Copy VRAM buffer into VRAM.
    halt
    ld de, (twister_vram_cursor)
    ld hl, twister_vram_buffer
    ld bc, 16*32
    ldir
    ld a, d
    and $5F
    ld d, a
    ld (twister_vram_cursor), de
    ld a, (de)

    ; Clear VRAM buffer.
    ld hl, twister_vram_buffer
    ld d, h
    ld e, l
    ld (hl), 0
    inc de
    ld bc, 16*32-1
    ldir


    ld b, 0
_loop:
    push bc
    push de

    ; Update the timing counters.
    ld hl, (twister_counter1)
    ld de, 12
    add hl, de
    ld (twister_counter1), hl

    ld hl, (twister_counter2)
    ld de, 29
    add hl, de
    ld (twister_counter2), hl

    ; Compute angle.
    ld a, (twister_counter1+1)
    call twister_sin
    sra a
    add a, 80
    ld d, 0
    ld e, a
    ld hl, (twister_phi)
    add hl, de
    ld (twister_phi), hl

    ; Compute Y position.
    ld a, b
    ld (twister_y), a

    ; Compute X position.
    ld a, (twister_counter2+1)
    call twister_sin
    sra a
    sra a
    add a, 128
    ld (twister_x), a

    ; Compute line endpoints.
    ld hl, twister_x
    ld a, (twister_phi+1)
    add a, $00
    call twister_sin
    sra a
    add a, (hl)
    ld (twister_x1), a
    ld a, (twister_phi+1)
    add a, $40
    call twister_sin
    sra a
    add a, (hl)
    ld (twister_x2), a
    ld a, (twister_phi+1)
    add a, $80
    call twister_sin
    sra a
    add a, (hl)
    ld (twister_x3), a
    ld a, (twister_phi+1)
    add a, $C0
    call twister_sin
    sra a
    add a, (hl)
    ld (twister_x4), a

    ; Draw lines.
    ld a, (twister_y)
    ld h, a
    ld a, (twister_x1)
    ld d, a
    ld a, (twister_x2)
    ld e, a
    ld a, $FF
    call twister_draw_line
    ld a, (twister_y)
    ld h, a
    ld a, (twister_x2)
    ld d, a
    ld a, (twister_x3)
    ld e, a
    ld a, $AA
    call twister_draw_line
    ld a, (twister_y)
    ld h, a
    ld a, (twister_x3)
    ld d, a
    ld a, (twister_x4)
    ld e, a
    ld a, $FF
    call twister_draw_line
    ld a, (twister_y)
    ld h, a
    ld a, (twister_x4)
    ld d, a
    ld a, (twister_x1)
    ld e, a
    ld a, $AA
    call twister_draw_line

    pop de
    pop bc

    inc b
    ld a, b
    cp 16
    jp nz, _loop

    jp _frame
