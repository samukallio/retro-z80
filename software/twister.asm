TWISTER_ROM_BASE:               equ $
TWISTER_RAM_BASE:               equ GAME_RAM_BASE

TWISTER_VRAM_BUFFER_HEIGHT:     equ 16
TWISTER_VRAM_BUFFER_SIZE:       equ 32 * TWISTER_VRAM_BUFFER_HEIGHT

; --- RAM ---------------------------------------------------------------------

org TWISTER_RAM_BASE

; Counters that drive the animation.
twister_counter1:               ds 2
twister_counter2:               ds 2

; Parameters for drawing one line of the twisting column.
twister_phi:                    ds 2    ; Angle of the column.
twister_x:                      ds 1    ; X position of the center of the line.
twister_y:                      ds 1    ; Y position of the line.
twister_x1:                     ds 1    ; X position of the first corner.
twister_x2:                     ds 1    ; X position of the second corner.
twister_x3:                     ds 1    ; X position of the third corner.
twister_x4:                     ds 1    ; X position of the fourth corner.

; Off-screen VRAM buffer.  This buffer is filled up by the code during
; the frame, and is then copied into VRAM during vertical blanking.
twister_vram_cursor:            ds 2    ; Next VRAM destination address.
twister_vram_buffer:            ds TWISTER_VRAM_BUFFER_SIZE

TWISTER_RAM_SIZE:               equ $ - PONG_RAM_BASE

if TWISTER_RAM_SIZE > GAME_RAM_SIZE
    .error "Out of game RAM space!"
endif

; --- ROM ---------------------------------------------------------------------

org TWISTER_ROM_BASE

; Sine lookup table using binary angles (0 to 255 == 0 to 2pi).  We only need
; to store the first 65 values (0 to 90 degrees, inclusive), as the rest are
; easily obtained by symmetry.  The range is -127 to +127, stored as 8-bit
; signed integers.
twister_sin_lut:
    db $00, $03, $06, $09, $0C, $0F, $12, $15
    db $18, $1B, $1E, $21, $24, $27, $2A, $2D
    db $30, $33, $36, $39, $3B, $3E, $41, $43
    db $46, $49, $4B, $4E, $50, $52, $55, $57
    db $59, $5B, $5E, $60, $62, $64, $66, $67
    db $69, $6B, $6C, $6E, $70, $71, $72, $74
    db $75, $76, $77, $78, $79, $7A, $7B, $7B
    db $7C, $7D, $7D, $7E, $7E, $7E, $7E, $7E
    db $7F

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
    ; If the phase is 64-127 or 192-255, then let A = 128 - A,
    ; which effectively reflects the phase about 64 (90 degrees).
    bit 6, a
    jr z, _lookup
    cpl
    add a, $81
_lookup:
    ; Save the phase A into B, and use the value in the lower 7 bits
    ; of A (now in the range 0 to 64, inclusive) to lookup the sine
    ; value.
    ld b, a
    and $7F
    ld d, 0
    ld e, a
    ld hl, twister_sin_lut
    add hl, de
    ld a, (hl)
    ; Use the saved phase to see if we need to invert the sign.
    bit 7, b
    exx
    ret z
    neg
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

;
;   Main program.
;
twister_main:
    call clear_screen
    ld a, (VRAM_BASE)

    ld de, VRAM_BASE
    ld (twister_vram_cursor), de

_frame:
    ; Copy VRAM buffer into VRAM.
    halt
    ld de, (twister_vram_cursor)
    ld hl, twister_vram_buffer
    ld bc, TWISTER_VRAM_BUFFER_SIZE
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
    ld bc, TWISTER_VRAM_BUFFER_SIZE-1
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
    ld d, 0
    ld a, (twister_counter1+1)
    call twister_sin
    sra a
    jp p, _set_angle
    ld d, $FF
_set_angle:
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
    cp TWISTER_VRAM_BUFFER_HEIGHT
    jp nz, _loop

    jp _frame
