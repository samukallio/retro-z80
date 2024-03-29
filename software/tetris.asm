TETRIS_ROM_BASE:                equ $
TETRIS_RAM_BASE:                equ GAME_RAM_BASE

; --- RAM ---------------------------------------------------------------------

org TETRIS_RAM_BASE

; Playfield.
tetris_field_array:             ds 230  ; 22 rows of 10 columns each.
tetris_field_line_state:        ds 23   ;
tetris_field_full_count:        ds 1    ;

; Miscellaneous.
tetris_level:                   ds 1    ; Current level number.
tetris_level_bcd:               ds 2    ; Current level in BCD for display.
tetris_score_bcd:               ds 3    ; Player score (6 BCD).
tetris_lines_bcd:               ds 3    ; Cleared line count (6 BCD).
tetris_count_bcds:              ds 7*2  ; Piece counts (7 pieces, 4 BCD each).
tetris_count_flags:             ds 7    ; Piece count was modified since last frame?
tetris_lines_to_next_level:     ds 1    ; Number of lines to go until next level.
tetris_restart_choice:          ds 1

; Active piece.
tetris_active_position:         ds 2    ; Current frame position.
tetris_active_position_old:     ds 2    ; Previous frame position.
tetris_active_piece:            ds 1    ; Current frame piece code.
tetris_active_piece_old:        ds 1    ; Previous frame piece code.
tetris_active_piece_reset:      ds 1    ; Piece was just placed?
tetris_active_fall_timer:       ds 1    ; Number of frames until piece moves down.

; Upcoming piece.
tetris_next_piece_old:          ds 1    ; Previous frame piece code.
tetris_queue:                   ds 7    ; Next 7 piece codes.
tetris_queue_index:             ds 1    ; Current index into queue.

;
tetris_zero_data:               ds 256  ; Useful for LDIR memory clears.

TETRIS_RAM_SIZE:                equ $ - TETRIS_RAM_BASE

if TETRIS_RAM_SIZE > GAME_RAM_SIZE
    .error "out of game ram space"
endif

; --- ROM ---------------------------------------------------------------------

org TETRIS_ROM_BASE

tetris_text_level:              defb "LEVEL", 0
tetris_text_lines:              defb "LINES", 0
tetris_text_score:              defb "SCORE", 0
tetris_text_next:               defb "NEXT", 0
tetris_text_statistics:         defb "STATISTICS", 0

tetris_text_game_over:          defb "Game Over!", 0
tetris_text_empty_line:         defb "          ", 0
tetris_text_restart:            defb "Restart?", 0
tetris_text_yes:                defb "Yes", 0
tetris_text_no:                 defb "No", 0

tetris_piece_table:
    ; Rotation 1
    dw $0100, $0101, $0102, $0103 ; I
    dw $0000, $0100, $0101, $0102 ; J
    dw $0002, $0100, $0101, $0102 ; L
    dw $0001, $0002, $0101, $0102 ; O
    dw $0001, $0002, $0100, $0101 ; S
    dw $0001, $0100, $0101, $0102 ; T
    dw $0000, $0001, $0101, $0102 ; Z
    dw $0000, $0000, $0000, $0000 ; -
    ; Rotation 2
    dw $0002, $0102, $0202, $0302 ; I
    dw $0001, $0002, $0101, $0201 ; J
    dw $0001, $0101, $0201, $0202 ; L
    dw $0001, $0002, $0101, $0102 ; O
    dw $0001, $0101, $0102, $0202 ; S
    dw $0001, $0101, $0102, $0201 ; T
    dw $0002, $0101, $0102, $0201 ; Z
    dw $0000, $0000, $0000, $0000 ; -
    ; Rotation 3
    dw $0200, $0201, $0202, $0203 ; I
    dw $0100, $0101, $0102, $0202 ; J
    dw $0100, $0101, $0102, $0200 ; L
    dw $0001, $0002, $0101, $0102 ; O
    dw $0101, $0102, $0200, $0201 ; S
    dw $0100, $0101, $0102, $0201 ; T
    dw $0100, $0101, $0201, $0202 ; Z
    dw $0000, $0000, $0000, $0000 ; -
    ; Rotation 4
    dw $0001, $0101, $0201, $0301 ; I
    dw $0001, $0101, $0200, $0201 ; J
    dw $0000, $0001, $0101, $0201 ; L
    dw $0001, $0002, $0101, $0102 ; O
    dw $0000, $0100, $0101, $0201 ; S
    dw $0001, $0100, $0101, $0201 ; T
    dw $0001, $0100, $0101, $0200 ; Z
    dw $0000, $0000, $0000, $0000 ; -

tetris_wall_kick_table:
    ; Rotation 1 -> 2
    dw $00FE, $0001, $FFFE, $0201 ; I
    dw $00FF, $01FF, $FE00, $FEFF ; J
    dw $00FF, $01FF, $FE00, $FEFF ; L
    dw $0000, $0000, $0000, $0000 ; O
    dw $00FF, $01FF, $FE00, $FEFF ; S
    dw $00FF, $01FF, $FE00, $FEFF ; T
    dw $00FF, $01FF, $FE00, $FEFF ; Z
    dw $0000, $0000, $0000, $0000 ; -
    ; Rotation 2 -> 3
    dw $00FF, $0002, $02FF, $FF02 ; I
    dw $0001, $FF01, $0200, $0201 ; J
    dw $0001, $FF01, $0200, $0201 ; L
    dw $0000, $0000, $0000, $0000 ; O
    dw $0001, $FF01, $0200, $0201 ; S
    dw $0001, $FF01, $0200, $0201 ; T
    dw $0001, $FF01, $0200, $0201 ; Z
    dw $0000, $0000, $0000, $0000 ; -
    ; Rotation 3 -> 4
    dw $0002, $00FF, $0102, $FEFF ; I
    dw $0001, $0101, $FE00, $FE01 ; J
    dw $0001, $0101, $FE00, $FE01 ; L
    dw $0000, $0000, $0000, $0000 ; O
    dw $0001, $0101, $FE00, $FE01 ; S
    dw $0001, $0101, $FE00, $FE01 ; T
    dw $0001, $0101, $FE00, $FE01 ; Z
    dw $0000, $0000, $0000, $0000 ; -
    ; Rotation 4 -> 1
    dw $0001, $00FE, $FE01, $01FE ; I
    dw $00FF, $FFFF, $0200, $02FF ; J
    dw $00FF, $FFFF, $0200, $02FF ; L
    dw $0000, $0000, $0000, $0000 ; O
    dw $00FF, $FFFF, $0200, $02FF ; S
    dw $00FF, $FFFF, $0200, $02FF ; T
    dw $00FF, $FFFF, $0200, $02FF ; Z
    dw $0000, $0000, $0000, $0000 ; -

tetris_block_table:
    dw $81BD, $A5A5, $BD81, $0000 ; I
    dw $9981, $DBDB, $8199, $0000 ; J
    dw $C3A5, $9999, $A5C3, $0000 ; L
    dw $A5C3, $9999, $C3A5, $0000 ; O
    dw $81B1, $B99D, $8D81, $0000 ; S
    dw $A593, $C9A5, $93C9, $0000 ; T
    dw $89B5, $C5A3, $AD91, $0000 ; Z
    dw $0000, $0000, $0000, $0000 ; -

tetris_score_bcd_table:
    dw $0040, $0100, $0300, $1200

tetris_timer_table:
    db 48, 43, 38, 33, 28, 23, 18, 13
    db  8,  6,  5,  5,  5,  4,  4,  4
    db  3,  3,  3,  2,  2,  2,  2,  2
    db  2,  2,  2,  2,  2,  1,  1,  1

; --- Program -----------------------------------------------------------------

;
;   Draw a tetris piece.
;
;   Inputs:
;       A   Piece code.
;       H   Piece Y (bounding box top row).
;       L   Piece X bounding box left column.
;
;   Destroys:
;       A, BC, DE, HL, IX
;
tetris_piece_draw:
    ld (sp_stash), sp

    ; DE = piece bounding box top left VRAM address
    ld bc, VRAM_BASE + $80
    add hl, bc
    ex de, hl

    ; HL = pointer to piece offset data
    ld b, 0
    ld c, a
    ld hl, tetris_piece_table
    add hl, bc

    ; BC'/DE'/HL' = block pattern data
    and $3F
    exx
    ld b, 0
    ld c, a
    ld hl, tetris_block_table
    add hl, bc
    ld sp, hl
    pop bc
    pop de
    pop hl
    exx

    ; SP = pointer to piece offset data
    ld sp, hl

    ; Draw blocks
    ld b, 4
_loop:
    pop ix
    add ix, de

    ; If the block is in the hidden vanish zone, skip it.
    ld a, ixh
    cp $40 + 6
    jr c, _next

    exx
    ld (ix-$80), $FF
    ld (ix-$60), b
    ld (ix-$40), c
    ld (ix-$20), d
    ld (ix+$00), e
    ld (ix+$20), h
    ld (ix+$40), l
    ld (ix+$60), $FF
    exx

_next:
    djnz _loop

    ld sp, (sp_stash)
    ret

;
;   Erase a tetris piece.
;
;   Inputs:
;       A   Piece code.
;       H   Piece Y (bounding box top row).
;       L   Piece X bounding box left column.
;
;   Destroys:
;       BC, DE, HL, IX
;
tetris_piece_erase:
    ld (sp_stash), sp

    ; DE = piece bounding box top left VRAM address
    ld bc, VRAM_BASE + $80
    add hl, bc
    ex de, hl

    ; HL = pointer to piece offset data
    ld b, 0
    ld c, a
    ld hl, tetris_piece_table
    add hl, bc
    ld sp, hl

    ld b, 4
_loop:
    pop ix
    add ix, de

    ; If the block is in the hidden vanish zone, skip it.
    ld a, ixh
    cp $40 + 6
    jr c, _next

    ; Place the
    ld (ix-$80), $00
    ld (ix-$60), $00
    ld (ix-$40), $00
    ld (ix-$20), $00
    ld (ix+$00), $00
    ld (ix+$20), $00
    ld (ix+$40), $00
    ld (ix+$60), $00

_next:
    djnz _loop

    ld sp, (sp_stash)
    ret

;
;   Test a piece for collision against the playing field.
;
;   Inputs:
;       A   Piece code.
;       D   Field row of bounding box top left corner.
;       E   Field column of bounding box top left corner.
;
;   Outputs:
;       Carry flag set iff collision.
;
;   Destroys:
;       BC, HL, AF', DE', HL'
;
tetris_field_collide:
    ; Compute HL as the pointer to the end of the piece table data for the
    ; chosen piece.  We start from the end and loop backwards, because it
    ; makes the iteration easier.
    ld b, 0
    ld c, a
    ld hl, tetris_piece_table+8
    add hl, bc

    ; Avoid clobbering A.
    ex af, af'

    ; Loop over the 4 blocks that make up the piece.
    ld b, 4
_loop:
    ; Compute A as the playfield row of the current block.  If A < 0, then
    ; the block is past the bottom wall, meaning we have a wall collision.
    ld a, d
    dec hl
    sub (hl)
    jp m, _collision

    ; Multiply A by 10 to get the offset of the row in the playfield array.
    ; Stash the result in C for later use.
    ld c, a
    add a, a
    add a, a
    add a, c
    add a, a
    ld c, a

    ; Compute A as the playfield column of the current block.  If A < 0, then
    ; the block is past the left wall, and if A >= 10, then the block is past
    ; the right wall.  In either case, we have a wall collision.
    ld a, e
    dec hl
    add a, (hl)
    jp m, _collision
    cp 10
    jp p, _collision

    ; Add the previously calculated playfield row offset into A, giving the
    ; offset of the block into the playfield array.  Then, load playfield
    ; state for the current block position into A and check if the cell is
    ; occupied.  We need DE/HL for address calculation, so use the shadow
    ; register set.
    add a, c
    exx
    ld d, 0
    ld e, a
    ld hl, tetris_field_array
    add hl, de
    ld a, (hl)
    exx
    and a
    jr nz, _collision

    ; Next block in the piece.
    djnz _loop

_no_collision:
    ; No collision, clear carry flag.
    ex af, af'
    or a
    ret

_collision:
    ; Collision, set carry flag.
    ex af, af'
    scf
    ret

;
;   Place a piece on the playfield.
;
;   Inputs:
;       A   Piece code.
;       D   Field row of bounding box top left corner.
;       E   Field column of bounding box top left corner.
;
;   Destroys:
;       BC, HL, AF', DE', HL'
;
tetris_field_place:
    ; Compute HL as the pointer to the end of the piece table data for the
    ; chosen piece.  We start from the end and loop backwards, because it
    ; makes the iteration easier.
    ld b, 0
    ld c, a
    ld hl, tetris_piece_table+8
    add hl, bc

    ; Avoid clobbering A.
    ex af, af'

    ; Loop over the 4 blocks that make up the piece.
    ld b, 4
_loop:
    ; Compute A as the playfield row of the current block.
    ld a, d
    dec hl
    sub (hl)

    ; Multiply A by 10 to get the offset of the row in the playfield array.
    ld c, a
    add a, a
    add a, a
    add a, c
    add a, a

    ; Compute A as the playfield column of the current block.
    add a, e
    dec hl
    add a, (hl)

    ; Mark the playfield cell as occupied.
    exx
    ld d, 0
    ld e, a
    ld hl, tetris_field_array
    add hl, de
    ld (hl), 1
    exx

    ; Next block in the piece.
    djnz _loop

    ex af, af'
    ret

;
;   Generate a new bag of 7 pieces.
;
tetris_queue_shuffle:
    ; Inject some non-determinism to the first random number
    ; generation by using the refresh register.
    ld a, r
    and $07
    inc a

    ld hl, tetris_queue
    ld b, 7
_shuffle_loop:
    ; Generate a random number modulo B.
    call random_generate
    call modulo

    ; Swap the element at (HL) with the element at (HL+A).
    ld d, (hl)
    push hl
    add a, l
    ld l, a
    ld a, 0
    adc a, h
    ld h, a
    ld e, (hl)
    ld (hl), d
    pop hl
    ld (hl), e

    ; For the next call to random_generate.
    ld a, 1

    inc hl
    djnz _shuffle_loop

    ; Reset the queue index.
    ld a, 0
    ld (tetris_queue_index), a

    ret

;
;   Pull the next piece from the queue and activate it.
;
tetris_queue_activate_next:
    ; 
    ld a, 1
    ld (tetris_active_piece_reset), a

    ; Update active piece.
    ld hl, tetris_queue_index
    ld d, 0
    ld e, (hl)
    inc (hl)
    ld hl, tetris_queue
    add hl, de
    ld a, (hl)
    ld (tetris_active_piece), a
    ld de, $1503
    ld (tetris_active_position), de

    ; Increment piece counter.
    and $38
    rrca
    rrca
    rrca
    ld d, 0
    ld e, a
    ld hl, tetris_count_flags
    add hl, de
    ld (hl), 1
    ld hl, tetris_count_bcds
    add hl, de
    add hl, de
    ex de, hl
    ld hl, 1
    call bcd_add

    ; Shuffle the bag.
    ld a, (tetris_queue_index)
    cp 7
    call z, tetris_queue_shuffle
    ret

;
;   Try to shift the current piece.
;
;   Inputs:
;       B   Row shift.
;       C   Column shift.
;
tetris_active_shift:
    ; Load current position and add the shift to it.
    ld de, (tetris_active_position)
    ld a, d
    add a, b
    ld d, a
    ld a, e
    add a, c
    ld e, a

    ; Test against the playing field.
    ld a, (tetris_active_piece)
    call tetris_field_collide
    ret c

    ; No collision, update piece.
    ld (tetris_active_piece), a
    ld (tetris_active_position), de
    ret

;
;   Try to rotate the current piece clockwise.
;
tetris_active_rotate_cw:
    ; First, try to rotate the piece without any wall kick.
    ld de, (tetris_active_position)
    ld a, (tetris_active_piece)
    add a, $40
    call tetris_field_collide
    jr nc, _success

    ; Save the rotated piece code.
    ld c, a

    ; Compute address of wall kick data into HL.  For clockwise rotations,
    ; the wall kick data is indexed by the original rotation of the piece.
    sub $40
    ld d, 0
    ld e, a
    ld hl, tetris_wall_kick_table
    add hl, de

    ; Try each of the 4 wall kick offsets.
    ld b, 4

_loop:
    ; Shift current piece column by wall kick offset.
    ld a, (tetris_active_position)
    add a, (hl)
    ld e, a
    inc hl

    ; Shift current piece row by wall kick offset.
    ld a, (tetris_active_position+1)
    add a, (hl)
    ld d, a
    inc hl

    ; Restore rotated piece code.
    ld a, c

    ; Check for collision.
    push hl
    push bc
    call tetris_field_collide
    pop bc
    pop hl
    jr nc, _success

    ; Next test.
    djnz _loop

    ; Every test failed.
    ret

_success:
    ld (tetris_active_piece), a
    ld (tetris_active_position), de
    ret

;
;   Try to rotate the current piece counterclockwise.
;
tetris_active_rotate_ccw:
    ; First, try to rotate the piece without any wall kick.
    ld de, (tetris_active_position)
    ld a, (tetris_active_piece)
    sub $40
    call tetris_field_collide
    jr nc, _success

    ; Save the rotated piece code.
    ld c, a

    ; Compute address of wall kick data into HL.  For counterclockwise
    ; rotations, the wall kick data is indexed by the target rotation of
    ; the piece, and with the sign of the row/column offsets inverted.
    ld d, 0
    ld e, a
    ld hl, tetris_wall_kick_table
    add hl, de

    ; Try each of the 4 wall kick offsets.
    ld b, 4

_loop:
    ; Shift current piece column by wall kick offset.
    ld a, (tetris_active_position+0)
    sub (hl)
    ld e, a
    inc hl

    ; Shift current piece row by wall kick offset.
    ld a, (tetris_active_position+1)
    sub (hl)
    ld d, a
    inc hl

    ; Restore rotated piece code.
    ld a, c

    ; Check for collision.
    push hl
    push bc
    call tetris_field_collide
    pop bc
    pop hl
    jr nc, _success

    ; Next test.
    djnz _loop

    ; Every test failed.
    ret

_success:
    ld (tetris_active_piece), a
    ld (tetris_active_position), de
    ret

;
;   Scan the playfield for full rows and clear them.
;   Also increments the line counter, score, and possibly level.
;
tetris_field_clear:
    ; Scan the playfield.
    ld c, 0
    ld de, tetris_field_line_state
    ld hl, tetris_field_array
_scan_loop:
    ld a, $00
    ex af, af'
    ld a, $01
rept 10
    and (hl)
    ex af, af'
    or (hl)
    ex af, af'
    inc hl
endm
    rlca
    ld b, a
    ex af, af'
    or b
    ld (de), a
    inc de
    rrca
    jr nc, _scan_done
    rrca
    jr nc, _scan_loop
    inc c
    jr _scan_loop
_scan_done:
    ld a, c
    ld (tetris_field_full_count), a
    ; If no full rows, exit.
    or a
    ret z

    ; Clear the playfield.
    ld ix, tetris_field_line_state
    ld de, tetris_field_array
    ld hl, tetris_field_array
_field_shift_loop:
    ld a, (ix)
    inc ix
    ; Empty row?
    rrca
    jr nc, _field_shift_done
    ; Non-full row?
    rrca
    jr nc, _field_shift_line
    ; Full row.
    ld bc, 10
    add hl, bc
    jr _field_shift_loop
_field_shift_line:
    ld bc, 10
    ldir
    jr _field_shift_loop
_field_shift_done:
    ld a, (tetris_field_full_count)
    ld b, a
    add a, a
    add a, a
    add a, b
    add a, a
    ld b, 0
    ld c, a
    ld hl, tetris_zero_data
    ldir

    ; Add number of cleared lines to the clear counter.
    ld a, (tetris_field_full_count)
    ld h, 0
    ld l, a
    ld de, tetris_lines_bcd
    call bcd_add

    ; Add score according to the number of lines cleared.
    ld a, (tetris_field_full_count)
    dec a
    add a, a
    ld d, 0
    ld e, a
    ld hl, tetris_score_bcd_table
    add hl, de
    ld e, (hl)
    inc hl
    ld d, (hl)
    ex de, hl
    ld a, (tetris_level)
    inc a
_score_loop:
    push hl
    ld de, tetris_score_bcd
    call bcd_add
    pop hl
    dec a
    jr nz, _score_loop

    ; Update the number of lines until next level, and increment
    ; the level if it becomes zero or less.
    ld de, tetris_lines_to_next_level
    ld a, (de)
    sub b
    jr c, _level_increment
    jr z, _level_increment
    jr _level_done
_level_increment:
    add a, 10
    ld hl, tetris_level
    inc (hl)
    push de
    ld de, tetris_level_bcd
    ld hl, 1
    call bcd_add
    pop de
_level_done:
    ld (de), a

    ; Animate full lines being wiped out.
    ld a, (VRAM_BASE)
    call video_vsync
    ld c, 5
_wipe_frame:
    ld h, 26
    ld de, tetris_field_line_state
_wipe_line:
    dec h
    ld a, (de)
    inc de
    rrca
    jr nc, _wipe_frame_done
    rrca
    jr nc, _wipe_line
    ld a, 12
    add a, c
    ld l, a
    ld a, ' '
    call video_draw_character
    ld a, 23
    sub c
    ld l, a
    ld a, ' '
    call video_draw_character
    jr _wipe_line
_wipe_frame_done:
    ld a, (VRAM_BASE)
    call video_vsync
    call video_vsync
    call video_vsync
    dec c
    jr nz, _wipe_frame

    ; Add some delay.
    call video_vsync
    call video_vsync
    call video_vsync
    call video_vsync
    call video_vsync
    call video_vsync

    ; Move the blocks down.
    ld ix, tetris_field_line_state
    ld de, VRAM_BASE + $19ED
    ld hl, VRAM_BASE + $19ED
_vram_shift_loop:
    ld a, (ix)
    inc ix
    rrca
    jr nc, _vram_shift_clear
    rrca
    jr nc, _vram_shift_line
    dec h
    jr _vram_shift_loop
_vram_shift_line:
rept 8
    ld bc, 10
    ldir
    ld bc, $FFD6
    add hl, bc
    ex de, hl
    add hl, bc
    ex de, hl
endm
    ld a, (VRAM_BASE)
    call video_vsync
    jr _vram_shift_loop
_vram_shift_clear:
    ld a, h
    cp d
    jr z, _vram_shift_done
rept 8
    ld bc, 10
    ldir
    ld bc, $FFF6
    add hl, bc
    ex de, hl
    ld bc, $FFD6
    add hl, bc
    ex de, hl
endm
    jr _vram_shift_clear
_vram_shift_done:

    ld a, (VRAM_BASE)
    ret

;
;   Initialize all state.
;
tetris_initialize:
    call video_clear

    ; Clear RAM.
    ld bc, TETRIS_RAM_SIZE - 1
    ld de, TETRIS_RAM_BASE + 1
    ld hl, TETRIS_RAM_BASE
    ld (hl), 0
    ldir

    ;
    ld a, 10
    ld (tetris_lines_to_next_level), a

    ;
    call random_initialize

    ;
    ld ix, tetris_queue
    ld (ix+0), $00
    ld (ix+1), $08
    ld (ix+2), $10
    ld (ix+3), $18
    ld (ix+4), $20
    ld (ix+5), $28
    ld (ix+6), $30
    call tetris_queue_shuffle

    ; Activate piece.
    call tetris_queue_activate_next

    ; Initialize movement timer.
    ld hl, tetris_timer_table
    ld a, (hl)
    ld hl, tetris_active_fall_timer
    ld (hl), a

    ; Mark all piece counts as dirty.
    ld b, 7
    ld hl, tetris_count_flags
_piece_count_dirty_loop:
    inc (hl)
    inc hl
    djnz _piece_count_dirty_loop

    ; Wait for vertical blank to begin drawing.
    call video_vsync

    ; Draw some static elements.
    ld hl, $050C
    ld de, $140A
    call video_draw_frame
    ld a, (VRAM_BASE)
    call video_vsync
    ld hl, $0619
    ld de, tetris_text_level
    call video_draw_text
    ld hl, $0919
    ld de, tetris_text_lines
    call video_draw_text
    ld hl, $0C19
    ld de, tetris_text_score
    call video_draw_text
    ld hl, $0F19
    ld de, tetris_text_next
    call video_draw_text
    ld hl, $0601
    ld de, tetris_text_statistics
    call video_draw_text
    ld a, (VRAM_BASE)
    call video_vsync

    ; Draw the pieces shown in the statistics panel.
    ld a, 0
    ld hl, $0706
_piece_count_loop:
    push hl
    push af
    call tetris_piece_draw
    pop af
    pop hl
    inc h
    inc h
    inc h
    add a, $08
    cp $38
    jr nz, _piece_count_loop

    ld a, (VRAM_BASE)
    ret

;
;   Render the next frame.
;
tetris_render:
    ; Wait for vertical blank to begin drawing.
    call video_vsync

    ; Draw piece statistics.
    ld a, 0
    ld c, 7
_piece_count_loop:
    ; Store piece type index into DE.
    ld d, 0
    ld e, a
    ex af, af'
    ; Check (and clear) the dirty flag for this piece counter.
    ld hl, tetris_count_flags
    add hl, de
    rr (hl)
    jr nc, _piece_count_skip
    ; Compute address of the piece count BCD counter into DE.
    ld hl, tetris_count_bcds
    add hl, de
    add hl, de
    ex de, hl
    ; Compute character row and column of the number into HL.
    ld a, l
    add a, a
    add a, l
    add a, $08
    ld h, a
    ld l, $01
    ; Draw the number, up to 4 digits, no leading zeroes.
    ld b, $02
    call video_draw_bcd_right
_piece_count_skip:
    ex af, af'
    inc a
    cp c
    jr nz, _piece_count_loop

    ; Draw current level.
    ld hl, $0719
    ld de, tetris_level_bcd
    ld b, $02
    call video_draw_bcd_left

    ; Draw line count.
    ld hl, $0A19
    ld de, tetris_lines_bcd
    ld b, $03
    call video_draw_bcd_left

    ; Draw score.
    ld hl, $0D19
    ld de, tetris_score_bcd
    ld b, $03
    call video_draw_bcd

_erase_active_piece:
    ; Erase the previous "next piece".
    ld hl, $111A
    ld a, (tetris_next_piece_old)
    call tetris_piece_erase
    ; Load the current "next piece" from the queue, and remember it.
    ld a, (tetris_queue_index)
    ld d, 0
    ld e, a
    ld hl, tetris_queue
    add hl, de
    ld a, (hl)
    ld (tetris_next_piece_old), a
    ; Draw the current "next piece".
    ld hl, $111A
    call tetris_piece_draw

    ; Erase previous active piece (if needed).
    ld hl, tetris_active_piece_reset
    rr (hl)
    jr c, _draw_active_piece

    ; Compute the screen row and column of the previous active piece
    ; position (that is expressed in playfield coordinates).
    ld de, (tetris_active_position_old)
    ld a, d
    neg
    add a, 25
    ld h, a
    ld a, e
    add a, $0D
    ld l, a

    ; Erase the previous active piece.
    ld a, (tetris_active_piece_old)
    call tetris_piece_erase

_draw_active_piece:
    ; Save the current active piece position for the next frame.
    ld de, (tetris_active_position)
    ld (tetris_active_position_old), de

    ; Compute the screen row and column of the current active piece
    ; position (that is expressed in playfield coordinates).
    ld a, d
    neg
    add a, 25
    ld h, a
    ld a, e
    add a, $0D
    ld l, a

    ; Save the current active piece code for the next frame.
    ld a, (tetris_active_piece)
    ld (tetris_active_piece_old), a

    ; Draw the current active piece.
    call tetris_piece_draw

    ; Reset VRAM address.
    ld a, (VRAM_BASE)
    ret

;
;   Update game logic.
;
tetris_update:
    ; Decrement the fall timer, and if it has not reached zero yet, then
    ; let the user perform an input action.
    ld hl, tetris_active_fall_timer
    dec (hl)
    jr nz, _input

    ; Compute the reset value for the fall timer based on the level.
    ; If the level is 31 or less, use the timer table.  Otherwise,
    ; reset the timer to 1 frame.
    ld b, 1
    ld hl, tetris_level
    ld a, (hl)
    cp 32
    jr nc, _reset_timer
    ld h, 0
    ld l, a
    ld de, tetris_timer_table
    add hl, de
    ld b, (hl)
_reset_timer:
    ; Reset the fall timer and force a downward shift.
    ld hl, tetris_active_fall_timer
    ld (hl), b
    ld bc, $FF00
    call tetris_active_shift
    jr c, _freeze
    jr _done

_input:
    ; Read controller input.
    call input_update

    ; Edge triggered inputs.
    ld a, (input_pressed)
    bit 0, a
    jp nz, _shift_left
    bit 1, a
    jp nz, _shift_right
    bit 2, a
    jr nz, _rotate_cw
    bit 3, a
    jr nz, _rotate_ccw

    ; Level triggered inputs.
    ld a, (input_state)
    bit 4, a
    jr nz, _shift_down

    jp _done

_shift_left:
    ld bc, $00FF
    call tetris_active_shift
    jr _done

_shift_right:
    ld bc, $0001
    call tetris_active_shift
    jr _done

_shift_down:
    ld hl, $0001
    ld de, tetris_score_bcd
    call bcd_add
    ld bc, $FF00
    call tetris_active_shift
    jr c, _freeze
    jr _done

_rotate_cw:
    call tetris_active_rotate_cw
    jr _done

_rotate_ccw:
    call tetris_active_rotate_ccw
    jr _done

_freeze:
    ; Check for lock out (trying to freeze a piece at the spawn position).
    ld de, (tetris_active_position)
    ld a, d
    sub 21
    jr z, _lock_out

    ; Place the piece.
    ld a, (tetris_active_piece)
    call tetris_field_place

    ; Clear full rows.
    call tetris_field_clear
    call tetris_queue_activate_next

_done:
    xor a
    ret

_lock_out:
    xor a
    inc a
    ret

;
;   Game over screen.
;
tetris_game_over:
    ; Clear the playfield.
    ld b, 20
    ld hl, $060D
_clear_loop:
    call video_vsync
    call video_vsync
    push hl
    push bc
    ld de, tetris_text_empty_line
    call video_draw_text
    pop bc
    pop hl
    inc h
    ld a, (VRAM_BASE)
    djnz _clear_loop

    ; Display game over menu.
    ld hl, $0D0D
    ld de, tetris_text_game_over
    call video_draw_text
    ld hl, $0F0E
    ld de, tetris_text_restart
    call video_draw_text
    ld hl, $1110
    ld de, tetris_text_yes
    call video_draw_text
    ld hl, $1210
    ld de, tetris_text_no
    call video_draw_text

_select_loop:
    ld a, (VRAM_BASE)
    call video_vsync
    ld a, (tetris_restart_choice)
    add a, $11
    ld h, a
    ld l, $0E
    ld a, ' '
    call video_draw_character
    call input_update
    ld a, (input_pressed)
    bit 2, a
    jr nz, _select_yes
    bit 3, a
    jr nz, _select_no
    bit 5, a
    jr nz, _exit
    jr _select_keep
_select_yes:
    ld a, 0
    ld (tetris_restart_choice), a
    jr _select_keep
_select_no:
    ld a, 1
    ld (tetris_restart_choice), a
    jr _select_keep
_select_keep:
    ld a, (tetris_restart_choice)
    add a, $11
    ld h, a
    ld l, $0E
    ld a, '>'
    call video_draw_character
    jr _select_loop

_exit:
    ld a, (VRAM_BASE)
    ret

;
;   Main program.
;
tetris_main:
_main_loop:
    call tetris_initialize

_game_loop:
    call tetris_render
    call tetris_update
    jr z, _game_loop

    ; Return A=1 from tetris_update means game over.
    cp 1
    call z, tetris_game_over

    jp _main_loop

