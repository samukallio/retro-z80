; --- Constants ---------------------------------------------------------------

; Physical memory map.
ROM_BASE:               equ $0000
RAM_BASE:               equ $2000
VRAM_BASE:              equ $4000

; Logical memory map.
COMMON_RAM_BASE:        equ $2000   ; RAM for common functionality.
COMMON_RAM_SIZE:        equ 1024
GAME_RAM_BASE:          equ $2400   ; RAM for the active game.
GAME_RAM_SIZE:          equ 1024
STACK_BASE:             equ $3F00
STACK_SIZE:             equ 256

; If the RAM loader mode is enabled, place the program and character data into
; the RAM part of the address space, so that they can be loaded into memory
; by copying bytes $2000-$3FFF of the assembled binary into memory while the
; machine is running.  In this mode, there is less space available for the
; program, since the RAM space is shared between instructions and the runtime
; state.
if defined USE_LOADER

PROGRAM_BASE:           equ $2800
PROGRAM_SIZE:           equ 4096
FONT_BASE:              equ $3800
FONT_SIZE:              equ 1024

else

PROGRAM_BASE:           equ $0100
PROGRAM_SIZE:           equ 6912
FONT_BASE:              equ $1C00
FONT_SIZE:              equ 1024

endif

; Input button bitmask indices.
INPUT_LEFT:             equ 0
INPUT_RIGHT:            equ 1
INPUT_UP:               equ 2
INPUT_DOWN:             equ 3
INPUT_A:                equ 4
INPUT_B:                equ 5
INPUT_START:            equ 6
INPUT_SELECT:           equ 7

INPUT_PORT1:            equ $00     ; Controller Port 1
INPUT_PORT2:            equ $01     ; Controller Port 2

; --- RAM ---------------------------------------------------------------------

org COMMON_RAM_BASE

sp_stash:               ds 2    ; Temporary storage for the stack pointer.

nmi_handler_vector:     ds 2
nmi_handler_enable:     ds 1

input_state:            ds 1    ; Button state bitmask (1 = down).
input_pressed:          ds 1    ; Button press bitmask (1 = pressed).
input_released:         ds 1    ; Button release bitmask (1 = released).

random_state:           ds 4    ; Random number generator state.

; --- Character Data ----------------------------------------------------------

org FONT_BASE

include "font.asm"

; --- Zero Page ---------------------------------------------------------------

org $0000

rst00:
    ld sp, STACK_BASE + STACK_SIZE
    jp start
    db 0, 0
rst08:
    db 0, 0, 0, 0, 0, 0, 0, 0
rst10:
    db 0, 0, 0, 0, 0, 0, 0, 0
rst18:
    db 0, 0, 0, 0, 0, 0, 0, 0
rst20:
    db 0, 0, 0, 0, 0, 0, 0, 0
rst28:
    db 0, 0, 0, 0, 0, 0, 0, 0
rst30:
    db 0, 0, 0, 0, 0, 0, 0, 0
rst38:
    ei
    reti

org $0066

nmi:
    push af
    push hl
    ld a, (nmi_handler_enable)
    and a
    call nz, _call
_exit:
    pop hl
    pop af
    retn
_call:
    ld hl, (nmi_handler_vector)
    jp (hl)

; --- Entry Point -------------------------------------------------------------

if defined USE_LOADER

start:
    im 1
    ei
    ld a, 0
    ld (nmi_handler_enable), a
    ld hl, 0
    ld (nmi_handler_vector), hl
_wait_clock_low:
    in a, (INPUT_PORT1)
    bit 7, a
    jr nz, _wait_clock_low
_wait_clock_high:
    in a, (INPUT_PORT1)
    bit 7, a
    jr z, _wait_clock_high
    and $07
    cp $00
    jr z, _set_h
    cp $01
    jr z, _set_l
    cp $02
    jr z, _write
    cp $03
    jr z, _debug
    cp $04
    jr z, _execute
    jp _wait_clock_low
_set_h:
    in a, (INPUT_PORT2)
    ld h, a
    jp _wait_clock_low
_set_l:
    in a, (INPUT_PORT2)
    ld l, a
    jp _wait_clock_low
_write:
    in a, (INPUT_PORT2)
    ld (hl), a
    inc hl
    jp _wait_clock_low
_debug:
    in a, (INPUT_PORT2)
    ld ($6000), a
    jp _wait_clock_low
_execute:
    jp (hl)

else

start:
    jp main

endif

; --- Program -----------------------------------------------------------------

org PROGRAM_BASE

main:
    jp tetris_main

include "video.asm"
include "tetris.asm"

;
;   Add to BCD number.
;
;   Inputs:
;       HL  Pointer to end of BCD number.
;       BC  Number to add.
;
bcd_add:
    ex af, af'
    dec hl
    ld a, (hl)
    add a, c
    daa
    ld (hl), a
    dec hl
    ld a, (hl)
    adc a, b
    daa
    ld (hl), a
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
