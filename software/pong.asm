PONG_ROM_BASE:                	equ $
PONG_RAM_BASE:                	equ GAME_RAM_BASE

PONG_MIN_X:                     equ 5
PONG_MAX_X:                     equ 256-5
PONG_MIN_Y:                     equ 61
PONG_MAX_Y:                     equ 256-61
PONG_PADDLE1_X:                 equ 24
PONG_PADDLE2_X:                 equ 256-24
PONG_FRAME_TICKS:               equ 16

; --- RAM ---------------------------------------------------------------------

org PONG_RAM_BASE

; Ball state.
pong_ball_x:                    ds 1    ; X position.
pong_ball_x_delta:              ds 1    ; X delta (when timer reaches zero).
pong_ball_x_delay:              ds 1    ; X movement timer preset value.
pong_ball_x_timer:              ds 1    ; X movement timer.
pong_ball_y:                    ds 1    ; Y position.
pong_ball_y_delta:              ds 1    ; Y delta (when timer reaches zero).
pong_ball_y_delay:              ds 1    ; Y movement timer preset value.
pong_ball_y_timer:              ds 1    ; Y movement timer.

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
    db $3C, $7E, $FF, $FF, $FF, $FF, $7E, $3C
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
;   Draw a sprite on the screen, ignoring fine X position.
;
;   Inputs:
;       H   Y position of the sprite.
;       L   X position of the sprite (bottom 3 bits discarded).
;       DE  Pointer to sprite data.
;
pong_draw_sprite_aligned:
    srl h
    rr l
    srl h
    rr l
    srl h
    rr l
    ld bc, VRAM_BASE
    add hl, bc

    ld bc, 32
_draw:
    ld a, (de)
    or a
    ret z
    inc de
    xor (hl)
    ld (hl), a
    add hl, bc
    jr _draw

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
    ld de, pong_paddle_sprite
    call pong_draw_sprite_aligned
_draw_paddle1:
    ld a, (pong_paddle1_position_y+1)
    ld (pong_paddle1_sprite_y), a
    ld h, a
    ld a, 16
    ld (pong_paddle1_sprite_x), a
    ld l, a
    ld de, pong_paddle_sprite
    call pong_draw_sprite_aligned

    ; Draw the right paddle.
    ld hl, pong_paddle2_sprite_reset
    srl (hl)
    jr c, _draw_paddle2
    ld a, (pong_paddle2_sprite_y)
    ld h, a
    ld a, (pong_paddle2_sprite_x)
    ld l, a
    ld de, pong_paddle_sprite
    call pong_draw_sprite_aligned
_draw_paddle2:
    ld a, (pong_paddle2_position_y+1)
    ld (pong_paddle2_sprite_y), a
    ld h, a
    ld a, 256-24
    ld (pong_paddle2_sprite_x), a
    ld l, a
    ld de, pong_paddle_sprite
    call pong_draw_sprite_aligned

    ld a, (VRAM_BASE)

    ret

pong_update_ball:
    ; Loop that processes a set amount of movement ticks per frame.
    ld b, PONG_FRAME_TICKS
_loop:
    ; Determine how many ticks to advance the timers by.  The next movement
    ; happens after T = min(pong_ball_x_timer, pong_ball_y_timer) ticks, but
    ; we should only process up to 16 ticks per frame.  Therefore, advance
    ; the timers by C = min(T, 16) ticks.
    ld a, (pong_ball_x_timer)
    ld c, a
    ld a, (pong_ball_y_timer)
    cp c
    jr c, _min1
    ld a, c
_min1:
    cp b
    jr c, _min2
    ld a, b
_min2:
    ld c, a

    ; Decrement the X/Y timers and move the ball accordingly if either or
    ; both of the timers reach zero.  Also, set bit 0 of E if the ball moved
    ; in the X direction, and set bit 1 of E if the ball moved in the Y
    ; direction.  We need this information to avoid double collisions.
    ld e, 0
_move_x:
    ; Update timer.
    ld a, (pong_ball_x_timer)
    sub c
    ld (pong_ball_x_timer), a
    jr nz, _move_y
    ; Timer reached zero, reset timer.
    ld a, (pong_ball_x_delay)
    ld (pong_ball_x_timer), a
    ; Move ball.
    ld a, (pong_ball_x_delta)
    ld d, a
    ld a, (pong_ball_x)
    add a, d
    ld (pong_ball_x), a
    set 0, e
_move_y:
    ; Update timer.
    ld a, (pong_ball_y_timer)
    sub c
    ld (pong_ball_y_timer), a
    jr nz, _move_done
    ; Timer reached zero, reset timer.
    ld a, (pong_ball_y_delay)
    ld (pong_ball_y_timer), a
    ; Move ball.
    ld a, (pong_ball_y_delta)
    ld d, a
    ld a, (pong_ball_y)
    add a, d
    ld (pong_ball_y), a
    set 1, e
_move_done:

    ; Do collision checking in the X direction, but only if the ball moved
    ; in the X direction.
_test_x:
    bit 0, e
    jr z, _test_y
    ; Check for collision with the field edges.
    ld a, (pong_ball_x)
    ld hl, pong_paddle1_position_y+1
    cp PONG_PADDLE1_X
    jr z, _collide_paddle
    ld hl, pong_paddle2_position_y+1
    cp PONG_PADDLE2_X - 8
    jr z, _collide_paddle
    cp PONG_MIN_X
    jr z, _bounce_x
    cp PONG_MAX_X - 8
    jr z, _bounce_x
    jr _test_x_done
_collide_paddle:
    ld a, (pong_ball_y)
    add a, 4
    cp (hl)
    jr c, _test_x_done
    ld a, (pong_ball_y)
    ld d, a
    ld a, (hl)
    add a, 28
    cp d
    jr c, _test_x_done
_bounce_x:
    ; Flip direction.
    ld a, (pong_ball_x_delta)
    neg
    ld (pong_ball_x_delta), a
_test_x_done:

    ; Do collision checking in the Y direction, but only if the ball moved
    ; in the Y direction.
_test_y:
    bit 1, e
    jr z, _next
    ; Check for collision with the field edges.
    ld a, (pong_ball_y)
    cp PONG_MIN_Y
    jr z, _bounce_y
    cp PONG_MAX_Y - 8
    jr z, _bounce_y
    jr _next
_bounce_y:
    ; Flip direction.
    ld a, (pong_ball_y_delta)
    neg
    ld (pong_ball_y_delta), a

    ; Keep decrementing the timers as long as there are ticks left to process
    ; for this frame.
_next:
    ld a, b
    sub c
    ld b, a
    jp nz, _loop

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
    ld a, 16
    ld (pong_ball_x_delay), a
    ld a, 16
    ld (pong_ball_y_delay), a

    ret

pong_main:
    call pong_initialize

_loop:
    call pong_render
    call pong_update
    jr _loop
