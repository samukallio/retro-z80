COMMON_ROM_BASE:      	equ $

; --- RAM ---------------------------------------------------------------------

org COMMON_RAM_BASE

sp_stash:               ds 2    ; Temporary storage for the stack pointer.

nmi_handler_vector:     ds 2
nmi_handler_enable:     ds 1

input_state:            ds 1    ; Button state bitmask (1 = down).
input_pressed:          ds 1    ; Button press bitmask (1 = pressed).
input_released:         ds 1    ; Button release bitmask (1 = released).

random_state:           ds 4    ; Random number generator state.

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
bcd_add:
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
input_update:
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
random_initialize:
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
random_generate:
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
