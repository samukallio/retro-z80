TETRIS_ROM_BASE:                equ $
TETRIS_RAM_BASE:                equ GAME_RAM_BASE

; --- RAM ---------------------------------------------------------------------

org TETRIS_RAM_BASE

; Playfield.
tetris_field_array:             ds 220  ; 22 rows of 10 columns each.
tetris_field_clear_map:         ds 22

; Miscellaneous.
tetris_level:                   ds 2    ; Current level (4 BCD).
tetris_score:                   ds 3    ; Player score (6 BCD).
tetris_clear_count:             ds 3    ; Cleared line count (6 BCD).
tetris_piece_count_array:       ds 7*2  ; Piece counts (7 pieces, 4 BCD each).
tetris_piece_count_dirty:       ds 7    ; Piece count was modified since last frame?

; Active piece.
tetris_active_position:         ds 2    ; Current frame position.
tetris_active_position_old:     ds 2    ; Previous frame position.
tetris_active_piece:            ds 1    ; Current frame piece code.
tetris_active_piece_old:        ds 1    ; Previous frame piece code.
tetris_active_piece_reset:      ds 1    ; Piece was just placed?
tetris_active_fall_timer:       ds 1    ; Number of frames until piece moves down.

; Upcoming piece.
tetris_next_piece:              ds 1    ; Current frame piece code.
tetris_next_piece_old:          ds 1    ; Previous frame piece code.
tetris_next_random:             ds 1    ; Randomizer state.

TETRIS_RAM_SIZE:                equ $ - TETRIS_RAM_BASE

if TETRIS_RAM_SIZE > GAME_RAM_SIZE
    .error "out of game ram space"
endif

; --- ROM ---------------------------------------------------------------------

org TETRIS_ROM_BASE

tetris_level_label:             defb "LEVEL", 0
tetris_clear_count_label:       defb "LINES", 0
tetris_score_label:             defb "SCORE", 0
tetris_next_label:              defb "NEXT", 0
tetris_piece_count_label:       defb "STATISTICS", 0

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
    ld (ix-$80), $00
    ld (ix-$60), $00
    ld (ix-$40), $00
    ld (ix-$20), $00
    ld (ix+$00), $00
    ld (ix+$20), $00
    ld (ix+$40), $00
    ld (ix+$60), $00
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

    ; Next block.
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

    ;
    exx
    ld d, 0
    ld e, a
    ld hl, tetris_field_array
    add hl, de
    ld (hl), 1
    exx

    ; Next block.
    djnz _loop

    ex af, af'
    ret

;
;   Randomize the next piece.
;
tetris_active_next:
    ; 
    ld a, 1
    ld (tetris_active_piece_reset), a

    ; Update active piece.
    ld a, (tetris_next_piece)
    ld (tetris_active_piece), a
    ld de, $1303
    ld (tetris_active_position), de

    ; If the next piece code was -1, then we are initializing, so skip
    ; incrementing the piece counter.
    inc a
    jr z, _randomize

    ; Increment piece counter.
    and $38
    rrca
    rrca
    rrca
    ld d, 0
    ld e, a
    ld hl, tetris_piece_count_dirty
    add hl, de
    ld (hl), 1
    ld hl, tetris_piece_count_array+2
    add hl, de
    add hl, de
    ld bc, 1
    call bcd_add

_randomize:
    ; Generate a random number.  Advance the generator state by 1-8 rounds
    ; depending on the current refresh address to inject some nondeterminism
    ; into the process.
    ld a, r
    and $07
    inc a
    call random_generate
    ld hl, tetris_next_random
    add a, (hl)
_randomize_loop:
    sub $07
    jr nc, _randomize_loop
    cpl
    ld (hl), a

    ; Set next piece code.
    ld a, (tetris_next_random)
    rlca
    rlca
    rlca
    ld (tetris_next_piece), a
    ret

;
;   Try to shift the current piece.
;
;   Inputs    : B   Row shift
;             : C   Column shift
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
;   Clear completed rows.
;
tetris_field_clear:
    ; Scan for full rows.
    ld de, tetris_field_clear_map
    ld hl, tetris_field_array
    ld b, 20
    ld c, 0
_scan_loop:
    ld a, $FF
rept 10
    and (hl)
    inc hl
endm
    jr nz, _scan_next
    ld a, b
    neg
    add a, 20
    ld (de), a
    inc de
    inc c
_scan_next:
    djnz _scan_loop

    ; ----

    ; If no full rows, exit.
    ld a, c
    cp 20
    jp z, _exit

    ld a, (VRAM_BASE)
    call video_vsync

    ; Clear rows in the playfield.
    ld ix, tetris_field_clear_map
    ld de, tetris_field_array
    ld b, c
_field_loop:
    ld a, (ix)
    inc ix
    push bc
    ld b, 0
    ld c, a
    add a, a
    add a, a
    add a, c
    add a, a
    ld c, a
    ld hl, tetris_field_array
    add hl, bc
    ld c, 10
    ldir
    pop bc
    djnz _field_loop

    ; Clear rows in VRAM.
    ld ix, tetris_field_clear_map
    ld de, VRAM_BASE + $19ED
    ld b, c
_vram_loop:
    ld a, (ix)
    inc ix

    push bc

    neg
    add a, 25
    ld h, a
    ld l, $ED
    ld bc, VRAM_BASE
    add hl, bc

rept 8
    ld bc, 10
    ldir
    ld bc, $FFD6
    add hl, bc
    ex de, hl
    add hl, bc
    ex de, hl
endm


    pop bc

    ; Wait    
    ld a, (VRAM_BASE)
    call video_vsync

    djnz _vram_loop


_exit:
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
    call random_initialize

    ; Randomize active and next pieces.
    ld a, -1
    ld (tetris_next_piece), a
    call tetris_active_next
    call tetris_active_next

    ; Initialize movement timer.
    ld hl, tetris_active_fall_timer
    ld (hl), 50

    ; Mark all piece counts as dirty.
    ld b, 7
    ld hl, tetris_piece_count_dirty
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
    ld hl, $0619
    ld de, tetris_level_label
    call video_draw_text
    ld hl, $0919
    ld de, tetris_clear_count_label
    call video_draw_text
    ld hl, $0C19
    ld de, tetris_score_label
    call video_draw_text
    ld hl, $0F19
    ld de, tetris_next_label
    call video_draw_text
    ld hl, $0601
    ld de, tetris_piece_count_label
    call video_draw_text

    ; Draw the pieces shown in the statistics panel.
    ld a, 0
    ld hl, $0702
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
    ld hl, tetris_piece_count_dirty
    add hl, de
    rr (hl)
    jr nc, _piece_count_skip
    ; Compute address of the piece count BCD counter into DE.
    ld hl, tetris_piece_count_array
    add hl, de
    add hl, de
    ex de, hl
    ; Compute character row and column of the number into HL.
    ld a, l
    add a, a
    add a, l
    add a, $08
    ld h, a
    ld l, $07
    ; Draw the number, up to 4 digits, no leading zeroes.
    ld b, $82
    call video_draw_number
_piece_count_skip:
    ex af, af'
    inc a
    cp c
    jr nz, _piece_count_loop

    ; Draw current level.
    ld hl, $0719
    ld de, tetris_level
    ld b, $82
    call video_draw_number

    ; Draw line count.
    ld hl, $0A19
    ld de, tetris_clear_count
    ld b, $03
    call video_draw_number

    ; Draw score.
    ld hl, $0D19
    ld de, tetris_score
    ld b, $03
    call video_draw_number

    ; Draw next piece.
    ld hl, $111A
    ld a, (tetris_next_piece_old)
    call tetris_piece_erase
    ld hl, $111A
    ld a, (tetris_next_piece)
    call tetris_piece_draw

    ; Erase previous active piece (if needed).
    ld hl, tetris_active_piece_reset
    rr (hl)
    jr c, _erase_piece_skip
    ld de, (tetris_active_position_old)
    ld a, d
    neg
    add a, 25
    ld h, a
    ld a, e
    add a, $0D
    ld l, a
    ld a, (tetris_active_piece_old)
    call tetris_piece_erase

_erase_piece_skip:
    ; Draw the active piece.
    ld de, (tetris_active_position)
    ld a, d
    neg
    add a, 25
    ld h, a
    ld a, e
    add a, $0D
    ld l, a
    ld a, (tetris_active_piece)
    call tetris_piece_draw

    ;
    ld a, (tetris_active_piece)
    ld (tetris_active_piece_old), a
    ld de, (tetris_active_position)
    ld (tetris_active_position_old), de
    ld a, (tetris_next_piece)
    ld (tetris_next_piece_old), a

    ; Reset VRAM address.
    ld a, (VRAM_BASE)
    ret

;
;   Update game logic.
;
tetris_update:
    ; Read controller input.
    call input_update

    ; Decrement the fall timer, and if it has not reached zero yet, then
    ; let the user perform an input action.
    ld hl, tetris_active_fall_timer
    dec (hl)
    jr nz, _input

    ; Reset the fall timer and force a downward shift.
    ld (hl), 1
    jr _shift_down

_input:
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

    ; Freeze the piece in place.
_freeze:
    ld a, (tetris_active_piece)
    ld de, (tetris_active_position)
    call tetris_field_place
    call tetris_field_clear
    call tetris_active_next

_done:
    ret

;
;   Main program.
;
tetris_main:
    call tetris_initialize

_loop:
    call tetris_render
    call tetris_update
    jp _loop
