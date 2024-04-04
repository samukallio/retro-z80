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

include "common.asm"
include "tetris.asm"
include "pong.asm"
include "twister.asm"

if $ > PROGRAM_BASE + PROGRAM_SIZE
    .error "Maximum program size exceeded!"
endif
