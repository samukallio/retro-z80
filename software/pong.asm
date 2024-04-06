PONG_ROM_BASE:                	equ $
PONG_RAM_BASE:                	equ GAME_RAM_BASE

PONG_MIN_X:                     equ 5
PONG_MAX_X:                     equ 256-5
PONG_MIN_Y:                     equ 61
PONG_MAX_Y:                     equ 256-61

; --- RAM ---------------------------------------------------------------------

org PONG_RAM_BASE

; Ball position and velocity stored as 8.8 a fixed point value.
pong_ball_position_x:           ds 2
pong_ball_position_y:           ds 2
pong_ball_velocity_x:           ds 2
pong_ball_velocity_y:           ds 2

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
;   Draw ball on the screen.
;
;   Inputs:
;       H   Y position of the ball.
;       L   X position of the ball.
;
pong_draw_ball:
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

    ld ix, pong_ball_sprite

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
;   Draw paddle on the screen.
;
;   Inputs:
;       H   Y position of the paddle.
;       L   X position of the paddle.
;
pong_draw_paddle:
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

    ld ix, pong_paddle_sprite

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
    call pong_draw_ball
_draw_ball:
    ld a, (pong_ball_position_y+1)
    ld (pong_ball_sprite_y), a
    ld h, a
    ld a, (pong_ball_position_x+1)
    ld (pong_ball_sprite_x), a
    ld l, a
    call pong_draw_ball

    ; Draw the left paddle.
    ld hl, pong_paddle1_sprite_reset
    srl (hl)
    jr c, _draw_paddle1
    ld a, (pong_paddle1_sprite_y)
    ld h, a
    ld a, (pong_paddle1_sprite_x)
    ld l, a
    call pong_draw_paddle
_draw_paddle1:
    ld a, (pong_paddle1_position_y+1)
    ld (pong_paddle1_sprite_y), a
    ld h, a
    ld a, 16
    ld (pong_paddle1_sprite_x), a
    ld l, a
    call pong_draw_paddle

    ; Draw the right paddle.
    ld hl, pong_paddle2_sprite_reset
    srl (hl)
    jr c, _draw_paddle2
    ld a, (pong_paddle2_sprite_y)
    ld h, a
    ld a, (pong_paddle2_sprite_x)
    ld l, a
    call pong_draw_paddle
_draw_paddle2:
    ld a, (pong_paddle2_position_y+1)
    ld (pong_paddle2_sprite_y), a
    ld h, a
    ld a, 256-24
    ld (pong_paddle2_sprite_x), a
    ld l, a
    call pong_draw_paddle


    ld a, (VRAM_BASE)

    ret

;
;   Update the game.
;
pong_update:

_move_x:
    ld hl, (pong_ball_position_x)
    ld de, (pong_ball_velocity_x)
    add hl, de
    ex de, hl
    ld a, d
    cp PONG_MIN_X
    jr c, _collide_min_x
    cp PONG_MAX_X - 9
    jr nc, _collide_max_x
    jr _save_x
_collide_min_x:
    ; Calculate X' = MIN_X + (MIN_X - X) = 2*MIN_X - X.  Since the value
    ; is 8.8 fixed point, we multiply by 256.  Also, SBC will subtract
    ; the carry flag (which is set from the comparison that led us here),
    ; so to counter that, we add 1.
    ld hl, 2 * PONG_MIN_X * 256 + 1
    sbc hl, de
    ex de, hl
    jr _collide_x
_collide_max_x:
    ; Calculate X' = (MAX_X-8) - (X - (MAX_X-8)) = 2*(MAX_X-8) - X.
    ld hl, 2 * (PONG_MAX_X - 8) * 256
    sbc hl, de
    ex de, hl
_collide_x:
    ld hl, 0
    ld bc, (pong_ball_velocity_x)
    sbc hl, bc
    ld (pong_ball_velocity_x), hl
_save_x:
    ld (pong_ball_position_x), de

_move_y:
    ld hl, (pong_ball_position_y)
    ld de, (pong_ball_velocity_y)
    add hl, de
    ex de, hl
    ld a, d
    cp PONG_MIN_Y
    jr c, _collide_min_y
    cp PONG_MAX_Y - 9
    jr nc, _collide_max_y
    jr _save_y
_collide_min_y:
    ; Calculate Y' = MIN_Y + (MIN_Y - Y) = 2*MIN_Y - Y.  Since the value
    ; is 8.8 fixed point, we multiply by 256.  Also, SBC will subtract
    ; the carry flag (which is set from the comparison that led us here),
    ; so to counter that, we add 1.
    ld hl, 2 * PONG_MIN_Y * 256 + 1
    sbc hl, de
    ex de, hl
    jr _collide_y
_collide_max_y:
    ; Calculate Y' = (MAX_Y-8) - (Y - (MAX_Y-8)) = 2*(MAX_Y-8) - Y.
    ld hl, 2 * (PONG_MAX_Y - 8) * 256
    sbc hl, de
    ex de, hl
_collide_y:
    ld hl, 0
    ld bc, (pong_ball_velocity_y)
    sbc hl, bc
    ld (pong_ball_velocity_y), hl
_save_y:
    ld (pong_ball_position_y), de

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

    ld de, 50*256
    ld (pong_ball_position_x), de
    ld (pong_ball_position_y), de
    ld de, 768
    ld (pong_ball_velocity_x), de
    ld de, 256
    ld (pong_ball_velocity_y), de

    ret

pong_main:
    call pong_initialize

_loop:
    call pong_render
    call pong_update
    jr _loop
