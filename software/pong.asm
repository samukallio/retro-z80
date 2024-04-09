PONG_ROM_BASE:                	equ $
PONG_RAM_BASE:                	equ GAME_RAM_BASE

PONG_MIN_X:                     equ 5
PONG_MAX_X:                     equ 256-5
PONG_MIN_Y:                     equ 61
PONG_MAX_Y:                     equ 256-61

; --- RAM ---------------------------------------------------------------------

org PONG_RAM_BASE

; Ball position.
pong_ball_x:                    ds 1
pong_ball_x_delta:              ds 1
pong_ball_x_delay:              ds 1
pong_ball_x_timer:              ds 1

pong_ball_y:                    ds 1
pong_ball_y_delta:              ds 1
pong_ball_y_delay:              ds 1
pong_ball_y_timer:              ds 1

; Paddle positions.
pong_paddle1_position_y:        ds 2
pong_paddle2_position_y:        ds 2

; Ball sprite state.
pong_ball_sprite_reset:         ds 1
pong_ball_sprite_x:             ds 1
pong_ball_sprite_y:             ds 1

; Paddle sprite state.
pong_paddle1_sprite_reset:      ds 1
pong_paddle1_sprite_x:          ds 1
pong_paddle1_sprite_y:          ds 1
pong_paddle2_sprite_reset:      ds 1
pong_paddle2_sprite_x:          ds 1
pong_paddle2_sprite_y:          ds 1

PONG_RAM_SIZE:                	equ $ - PONG_RAM_BASE

if PONG_RAM_SIZE > GAME_RAM_SIZE
    .error "Out of game RAM space!"
endif

; --- ROM ---------------------------------------------------------------------

org PONG_ROM_BASE

pong_ball_sprite:
    db $18, $3C, $7E, $FF, $FF, $7E, $3C, $18
    db $00

pong_paddle_sprite:
    db $3C, $7E, $FF, $FF, $FF, $FF, $FF, $FF
    db $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
    db $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF
    db $FF, $FF, $FF, $FF, $FF, $FF, $7E, $3C
    db $00

;
;   Draw a sprite on the screen.
;
;   Inputs:
;       H   Y position of the sprite.
;       L   X position of the sprite.
;       IX  Pointer to sprite data.
;
pong_draw_sprite:
    ld a, l
    and $07
    srl h
    rr l
    srl h
    rr l
    srl h
    rr l
    ld de, VRAM_BASE
    add hl, de
    ex af, af'

    ;
_line:
    ld a, (ix)
    or a
    jr z, _exit
    inc ix

    ld d, a
    ld e, 0

    ; Shift the sprite row by the fine X amount.
    ex af, af'
    or a
    jr z, _shift_done
    ld b, a
_shift:
    sla d
    rl e
    djnz _shift
_shift_done:
    ex af, af'

    ; Draw the sprite.
_draw:
    ld a, (hl)
    xor d
    ld (hl), a
    inc hl
    ld a, (hl)
    xor e
    ld (hl), a
    ld de, 31
    add hl, de

    jr _line

_exit:
    ex af, af'
    ret

;
;   Update video memory.
;
pong_render:
    call wait_for_vblank

    ; Draw the ball.
    ld hl, pong_ball_sprite_reset
    srl (hl)
    jr c, _draw_ball
    ld a, (pong_ball_sprite_y)
    ld h, a
    ld a, (pong_ball_sprite_x)
    ld l, a
    ld ix, pong_ball_sprite
    call pong_draw_sprite
_draw_ball:
    ld a, (pong_ball_y)
    ld (pong_ball_sprite_y), a
    ld h, a
    ld a, (pong_ball_x)
    ld (pong_ball_sprite_x), a
    ld l, a
    ld ix, pong_ball_sprite
    call pong_draw_sprite

    ; Draw the left paddle.
    ld hl, pong_paddle1_sprite_reset
    srl (hl)
    jr c, _draw_paddle1
    ld a, (pong_paddle1_sprite_y)
    ld h, a
    ld a, (pong_paddle1_sprite_x)
    ld l, a
    ld ix, pong_paddle_sprite
    call pong_draw_sprite
_draw_paddle1:
    ld a, (pong_paddle1_position_y+1)
    ld (pong_paddle1_sprite_y), a
    ld h, a
    ld a, 16
    ld (pong_paddle1_sprite_x), a
    ld l, a
    ld ix, pong_paddle_sprite
    call pong_draw_sprite

    ; Draw the right paddle.
    ld hl, pong_paddle2_sprite_reset
    srl (hl)
    jr c, _draw_paddle2
    ld a, (pong_paddle2_sprite_y)
    ld h, a
    ld a, (pong_paddle2_sprite_x)
    ld l, a
    ld ix, pong_paddle_sprite
    call pong_draw_sprite
_draw_paddle2:
    ld a, (pong_paddle2_position_y+1)
    ld (pong_paddle2_sprite_y), a
    ld h, a
    ld a, 256-24
    ld (pong_paddle2_sprite_x), a
    ld l, a
    ld ix, pong_paddle_sprite
    call pong_draw_sprite


    ld a, (VRAM_BASE)

    ret

pong_update_ball:
    ; B = total number of ticks
    ; C = number of ticks to advance now

    ld a, $FF

    ld b, 32
_loop:
    ; Compute the number of ticks to simulate.
    ld a, (pong_ball_x_timer)
    ld c, a
    ld a, (pong_ball_y_timer)
    cp c
    jr c, _l1
    ld a, c
_l1:
    cp b
    jr c, _l2
    ld a, b
_l2:
    ld c, a

_do_x:
    ld a, (pong_ball_x_timer)
    sub c
    ld (pong_ball_x_timer), a
    jr nz, _do_y
    ; do x

    ld a, (pong_ball_x_delay)
    ld (pong_ball_x_timer), a

    ld a, (pong_ball_x_delta)
    ld d, a
    ld a, (pong_ball_x)
    add a, d
    ld (pong_ball_x), a
    cp PONG_MIN_X
    jr z, _collide_x
    cp PONG_MAX_X - 8
    jr z, _collide_x
    jr _do_y

_collide_x:
    ld a, d
    neg
    ld (pong_ball_x_delta), a

_do_y:
    ld a, (pong_ball_y_timer)
    sub c
    ld (pong_ball_y_timer), a
    jr nz, _next
    ; do y

    ld a, (pong_ball_y_delay)
    ld (pong_ball_y_timer), a

    ld a, (pong_ball_y_delta)
    ld d, a
    ld a, (pong_ball_y)
    add a, d
    ld (pong_ball_y), a
    cp PONG_MIN_Y
    jr z, _collide_y
    cp PONG_MAX_Y - 8
    jr z, _collide_y
    jr _next

_collide_y:
    ld a, d
    neg
    ld (pong_ball_y_delta), a

_next:
    ld a, b
    sub c
    ld b, a
    jr nz, _loop

_exit:
    ret

pong_update:
    call read_input
    ld a, (input_state)
    bit 2, a
    jr nz, _move_up
    bit 3, a
    jr nz, _move_down
    jr _input_done

_move_up:
    ld hl, (pong_paddle1_position_y)
    ld de, -256
    add hl, de
    ld (pong_paddle1_position_y), hl
    jr _input_done

_move_down:
    ld hl, (pong_paddle1_position_y)
    ld de, 256
    add hl, de
    ld (pong_paddle1_position_y), hl
    jr _input_done

_input_done:
    call pong_update_ball

    ret

pong_initialize:
    call clear_screen

    ld hl, $0700
    ld de, $101E
    call draw_rounded_rectangle

    ; Clear RAM.
    ld bc, TETRIS_RAM_SIZE - 1
    ld de, TETRIS_RAM_BASE + 1
    ld hl, TETRIS_RAM_BASE
    ld (hl), 0
    ldir


    ;
    ld a, 1
    ld (pong_paddle1_sprite_reset), a
    ld (pong_paddle2_sprite_reset), a

    ld de, 112*256
    ld (pong_paddle1_position_y), de
    ld (pong_paddle2_position_y), de

    ;
    ld a, 1
    ld (pong_ball_sprite_reset), a

    ld a, 80
    ld (pong_ball_x), a
    ld (pong_ball_y), a

    ;
    ld a, 1
    ld (pong_ball_x_delta), a
    ld (pong_ball_y_delta), a
    ld a, 1
    ld (pong_ball_x_timer), a
    ld (pong_ball_y_timer), a
    ld a, 8
    ld (pong_ball_x_delay), a
    ld a, 4
    ld (pong_ball_y_delay), a

    ret

pong_main:
    call pong_initialize

_loop:
    call pong_render
    call pong_update
    jr _loop
