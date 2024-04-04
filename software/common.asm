COMMON_ROM_BASE:      	equ $

; --- RAM ---------------------------------------------------------------------

org COMMON_RAM_BASE

; Temporary storage for the stack pointer.
sp_stash:               ds 2

; Temporary storage, for spilling registers into RAM.
r0:                     ds 2
r1:                     ds 2
r2:                     ds 2
r3:                     ds 2
r4:                     ds 2
r5:                     ds 2
r6:                     ds 2
r7:                     ds 2

; Custom NMI handler.
nmi_handler_vector:     ds 2
nmi_handler_enable:     ds 1

; Controller state.
input_state:            ds 1    ; Button state bitmask (1 = down).
input_pressed:          ds 1    ; Button press bitmask (1 = pressed).
input_released:         ds 1    ; Button release bitmask (1 = released).

; Random number generator state.
random_state:           ds 4

; --- Program -----------------------------------------------------------------

org COMMON_ROM_BASE

;
;   Computes the unsigned 8-bit modulo operation.
;
;   Inputs:
;       A   Dividend.
;       B   Divisor.
;
;   Outputs:
;       A   Remainder.
;
;   Destroys:
;       C
;
modulo:
    ld c, b
_shift:
    rlc c
    jr nc, _shift
_check:
    cp b
    ret c
_subtract:
    rrc c
    sub c
    jr nc, _check
    add a, c
    jr _subtract

;
;   Add to BCD number.
;
;   Inputs:
;       DE  Pointer to BCD number.
;       HL  Number to add.
;
;   Destroys:
;       DE, H
;
add_bcd:
    ex af, af'

    ; Add to first two digits.
    ld a, (de)
    add a, l
    daa
    ld (de), a

    ; Add to next two digits.
_loop:
    inc de
    ld a, (de)
    adc a, h
    daa
    ld (de), a

    ; Keep propagating the carry to higher digits.
    ld h, 0
    jr c, _loop

    ex af, af'
    ret

;
;   Handle input update.
;
read_input:
    ld hl, input_state
    ld b, (hl)
    ld a, 0
    in a, (INPUT_PORT2)
    ld c, a
    ld (hl), a

    ld a, b
    cpl
    and c
    ld (input_pressed), a

    ld a, c
    cpl
    and b
    ld (input_released), a

    ret

;
;   Initialize the random number generator.
;
initialize_random:
    exx
    ld de, $F1EE
    ld hl, $EEEE
    ld (random_state+0), de
    ld (random_state+2), hl
    exx
    ret

;
;   Generate a pseudorandom number.
;
;   Inputs:
;       A   Number of rounds to advance the state.
;
;   Outputs:
;       A   Generated number.
;
random:
    exx
    ld b, a
    ld de, (random_state+0)
    ld hl, (random_state+2)
_loop:
    ; C = D - rotate_left(E, 1)
    ld a, e
    rlca
    neg
    add a, d
    ld c, a
    ; D = E ^ rotate_left(H, 4)
    ld a, h
    rlca
    rlca
    rlca
    rlca
    xor e
    ld d, a
    ; E = H + L
    ld a, l
    add a, h
    ld e, a
    ; H = L + C
    ld a, c
    add a, l
    ld h, a
    ; L = C + D
    ld a, d
    add a, c
    ld l, a
    djnz _loop
    ld (random_state+0), de
    ld (random_state+2), hl
    exx
    ret

;
;   Wait for the next vertical blanking interval.
;
wait_for_vblank:
    halt
    ret

;
;   Clear the screen.
;
;   Destroys:
;       AF, BC, DE, HL
;
clear_screen:
    ; Clear the screen one half at a time.
    ld hl, VRAM_BASE
    ld c, 2

_outer:
    ; Synchronize to be sure that a vertical blank NMI does not
    ; occur while we are using the stack pointer to clear VRAM.
    call wait_for_vblank

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
draw_rounded_rectangle:
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
    call draw_character
    ex de, hl
    ld a, $03
    call draw_character
    ex de, hl

    ; Draw top and bottom horizontal lines.
    ld a, $01
_hloop:
    dec l
    call draw_character
    ex de, hl
    inc l
    call draw_character
    ex de, hl
    djnz _hloop

    ; Draw top right and bottom left corners.
    dec l
    ld a, $05
    call draw_character
    ex de, hl
    inc l
    ld a, $04
    call draw_character
    ex de, hl

    ; Draw left and right vertical lines.
    ld b, c
    ld a, $02
_vloop:
    dec h
    call draw_character
    ex de, hl
    inc h
    call draw_character
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
draw_character:
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
draw_text:
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
;       B   Number of digits to draw.
;       DE  Pointer to number.
;       H   Target row.
;       L   Target column.
;
;   Destroys:
;       AF, B, DE, L, IX
;
draw_number:
    ; Move DE to one past the last byte of the number.
    ld a, b
    add a, e
    ld e, a
    jr nc, _loop
    inc d

_loop:
    ; Load and draw upper digit.
    dec de
    ld a, (de)
    and $F0
    rrca
    rrca
    rrca
    rrca
    add a, '0'
    call draw_character
    inc l

    ; Load and draw lower digit.
    ld a, (de)
    and $0F
    add a, '0'
    call draw_character
    inc l

    djnz _loop
    ret

;
;   Draw a number (stored as BCD digits) into video memory
;   without leading zeroes, right-justified.
;
;   Parameters:
;       B   Length of the number, in bytes.
;       DE  Pointer to number.
;       H   Target row.
;       L   Target column.
;
;   Destroys:
;       AF, BC, DE, L, IX
;
draw_number_right:
    ; Move DE to one past the last byte of the number.
    ld a, b
    add a, e
    ld e, a
    jr nc, _skip_loop
    inc d

_skip_loop:
    dec de
    ld a, (de)
    dec b
    jr z, _skip_done
    or a
    jr nz, _skip_done
    ld a, ' '
    call draw_character
    inc l
    call draw_character
    inc l
    jr _skip_loop

_skip_done:
    ; If the upper digit of the current byte is zero, then it should also
    ; be skipped.
    and $F0
    jr nz, _draw_upper

    ld a, ' '
    call draw_character
    inc l

    ; Load and draw lower digit from current byte.
_load_lower:
    ld a, (de)
    and $0F
_draw_lower:
    add a, '0'
    call draw_character
    inc l
    dec b
    ret m

    ; Load and draw upper digit from current byte.
_load_upper:
    dec de
    ld a, (de)
    and $F0
_draw_upper:
    rrca
    rrca
    rrca
    rrca
    add a, '0'
    call draw_character
    inc l
    jr _load_lower

    ret

;
;   Draw a number (stored as BCD digits) into video memory
;   without leading zeroes, left-justified.
;
;   Parameters:
;       B   Length of the number, in bytes.
;       DE  Pointer to number.
;       H   Target row.
;       L   Target column.
;
;   Destroys:
;       AF, BC, DE, L, IX
;
draw_number_left:
    ; Move DE to one past the last byte of the number.
    ld a, b
    add a, e
    ld e, a
    jr nc, _skip
    inc d

    ; Skip leading zero bytes.
_skip:
    ld c, 0
_skip_loop:
    dec de
    ld a, (de)
    dec b
    jr z, _skip_done
    or a
    jr nz, _skip_done
    inc c
    jr _skip_loop
_skip_done:
    ; C is the number of non-zero leading bytes.  To get the number of
    ; non-zero leading digits, double C and add 1 if the upper digit of
    ; the current byte is zero.
    cp $10
    rl c
    ; If the upper digit of the current byte is zero, then it should also
    ; be skipped.
    and $F0
    jr nz, _draw_upper

    ; Load and draw lower digit from current byte.
_load_lower:
    ld a, (de)
    and $0F
_draw_lower:
    add a, '0'
    call draw_character
    inc l
    dec b
    jp m, _load_space

    ; Load and draw upper digit from current byte.
_load_upper:
    dec de
    ld a, (de)
    and $F0
_draw_upper:
    rrca
    rrca
    rrca
    rrca
    add a, '0'
    call draw_character
    inc l
    jr _load_lower

    ; Draw trailing space.
_load_space:
    ld b, c
    ld a, ' '
_draw_space:
    call draw_character
    inc l
    djnz _draw_space
    ret
