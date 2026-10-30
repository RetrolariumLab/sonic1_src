DrawBlocks_LR:
                moveq   #((320+16+16)/16)-1,d6          ; prepare number of blocks (entire width of the screen + two extra columns)

; DrawBlocks_X_Alt: DrawRow_Partial:
DrawBlocks_LR_2:
                move.l  #$800000,d7                     ; prepare plane row advance rate ($80 bytes per row for *512 plane width)
                move.l  d0,d1                           ; store VDP plane address

                .nextBlock:
                movem.l d4-d5,-(sp)                     ; store X and Y positions
                bsr.w   GetBlockData                    ; load block
                move.l  d1,d0                           ; load VDP plane address
                bsr.w   DrawBlock                       ; draw the tiles from the block correctly
                addq.b  #4,d1                           ; increase VDP plane address to the right by 2 tiles (1 block)
                andi.b  #$7F,d1                         ; wrap if necessary
                movem.l (sp)+,d4-d5                     ; restore X and Y positions
                addi.w  #16,d5                          ; advance X position right by 1 block
                dbf     d6,.nextBlock                   ; repeat for number of blocks in the strip
                rts                                     ; return
; End of function DrawBlocks_LR

; ---------------------------------------------------------------------------
; Alternate version of DrawBlocks_LR_2 introduced in REV01,
; calling GetBlockData_2 instead (ignore d5 = screen X draw offset)
; ---------------------------------------------------------------------------

; DrawTiles_LR_3: DrawRow_IgnoreX:
DrawBlocks_LR_3:
                move.l  #$800000,d7                     ; prepare plane row advance rate ($80 bytes per row for *512 plane width)
                move.l  d0,d1                           ; store VDP plane address

                .nextBlock:
                movem.l d4-d5,-(sp)                     ; store X and Y positions
                bsr.w   GetBlockData_2                  ; load block (skip d5 = X draw offset)
                move.l  d1,d0                           ; load VDP plane address
                bsr.w   DrawBlock                       ; draw the tiles from the block correctly
                addq.b  #4,d1                           ; increase VDP plane address to the right by 2 tiles (1 block)
                andi.b  #$7F,d1                         ; wrap if necessary
                movem.l (sp)+,d4-d5                     ; restore X and Y positions
                addi.w  #16,d5                          ; advance X position right by 1 block
                dbf     d6,.nextBlock                   ; repeat for number of blocks in the strip
                rts                                     ; return
; End of function DrawBlocks_LR_3

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to draw a vertical column of blocks
;
; input:
; d0.l = VDP control port address of plane position (words swapped for convenience)
; d2.w = VRAM address of plane to use (usually $C000 or $E000)
; d4.w = Screen Y draw position
; d5.w = Screen X draw position
; d6.w = Blocks to draw (DrawBlocks_TB_2 only)
; a3.l = Screen position data
; a4.l = Layout address
; a5.l = VDP control port
; a6.l = VDP data port
; ---------------------------------------------------------------------------

; Don't be fooled by the name: this function's for drawing from top to bottom
; when the camera's moving left or right!

; DrawBlocks_Y: DrawColumn:
DrawBlocks_TB:
                moveq   #((224+16+16)/16)-1,d6          ; prepare number of blocks (entire height of the screen + two extra rows)

; DrawBlocks_Y_Alt: DrawColumn_Partial:
DrawBlocks_TB_2:
                move.l  #$800000,d7                     ; prepare plane row advance rate ($80 bytes per row for * 512 plane width)
                move.l  d0,d1                           ; store VDP plane address

                .nextBlock:
                movem.l d4-d5,-(sp)                     ; store X and Y positions
                bsr.w   GetBlockData                    ; load block
                move.l  d1,d0                           ; load VDP plane address
                bsr.w   DrawBlock                       ; draw the tiles from the block correctly
                addi.w  #$100,d1                        ; increase VDP plane address down by 2 rows (1 block)
                andi.w  #$FFF,d1                        ; wrap if necessary
                movem.l (sp)+,d4-d5                     ; restore X and Y positions
                addi.w  #16,d4                          ; advance Y position down by 1 block
                dbf     d6,.nextBlock                   ; repeat for number of blocks in the strip
                rts                                     ; return
; End of function DrawBlocks_TB

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to draw tiles from a block correctly
;
; input:
; d0.l = VDP control port address of plane position (words swapped for convenience)
; d2.w = VRAM address of plane to use (usually $C000 or $E000)
; a0.l = Address of block to draw
; a5.l = VDP control port
; a6.l = VDP data port
; d7.l = plane row advance rate (usually $800000 ($80 per row))
; ---------------------------------------------------------------------------

; DrawTiles:
DrawBlock:
                or.w    d2,d0                           ; save VRAM plane address to VDP control port plane position
                swap    d0                              ; align correctly for VDP
                btst    #4,(a0)                         ; is the block flipped vertically (+$1000)?
                bne.s   .drawFlipY                      ; if so, branch
                btst    #3,(a0)                         ; is the block mirrored horizontally (+$800)?
                bne.s   .drawFlipX                      ; if so, branch
; ---------------------------------------------------------------------------

.drawNoFlip:

; --- Normal block ---

                move.l  d0,(a5)                         ; set VDP to VRAM write mode with plane address
                move.l  (a1)+,(a6)                      ; dump top two tiles
                add.l   d7,d0                           ; advance to next row
                move.l  d0,(a5)                         ; set VDP to VRAM write mode with plane address
                move.l  (a1)+,(a6)                      ; dump bottom two tiles
                rts                                     ; return
; ---------------------------------------------------------------------------

.drawFlipX:

; --- Mirrored block ---

                move.l  d0,(a5)                         ; set VDP to VRAM write mode with plane address
                move.l  (a1)+,d4                        ; load top two tiles
                eori.l  #$8000800,d4                    ; mirror the tiles
                swap    d4                              ; swap them over
                move.l  d4,(a6)                         ; dump top two tiles (reversed)
                add.l   d7,d0                           ; advance to next row
                move.l  d0,(a5)                         ; set VDP to VRAM write mode with plane address
                move.l  (a1)+,d4                        ; load bottom two tiles
                eori.l  #$8000800,d4                    ; mirror the tiles
                swap    d4                              ; swap them over
                move.l  d4,(a6)                         ; dump bottom two tiles (reversed)
                rts                                     ; return
; ---------------------------------------------------------------------------

.drawFlipY:
                btst    #3,(a0)                         ; is the block also mirrored horizontally (with flip vertical +$1800)?
                bne.s   .drawFlipXY                     ; if so, branch

; --- Flipped block ---

                move.l  d0,(a5)                         ; set VDP to VRAM write mode with plane address
                move.l  (a1)+,d5                        ; load top two tiles
                move.l  (a1)+,d4                        ; load bottom two tiles
                eori.l  #$10001000,d4                   ; flip bottom two tiles
                move.l  d4,(a6)                         ; dump bottom two tiles first so they draw at top
                add.l   d7,d0                           ; advance to next row
                move.l  d0,(a5)                         ; set VDP to VRAM write mode with plane address
                eori.l  #$10001000,d5                   ; flip top two tiles
                move.l  d5,(a6)                         ; dump top two tiles last so they draw at bottom
                rts                                     ; return
; ---------------------------------------------------------------------------

.drawFlipXY:

; --- Flipped & Mirrored block ---

                move.l  d0,(a5)                         ; set VDP to VRAM write mode with plane address
                move.l  (a1)+,d5                        ; load top two tiles
                move.l  (a1)+,d4                        ; load bottom two tiles
                eori.l  #$18001800,d4                   ; flip and mirror the bottom two tiles
                swap    d4                              ; swap them over
                move.l  d4,(a6)                         ; dump bottom two tiles first so they draw at top
                add.l   d7,d0                           ; advance to next row
                move.l  d0,(a5)                         ; set VDP to VRAM write mode with plane address
                eori.l  #$18001800,d5                   ; flip and mirror the top two tiles
                swap    d5                              ; swap them over
                move.l  d5,(a6)                         ; dump top two tiles last so they draw at bottom
                rts                                     ; return
; End of function DrawBlocks

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to obtain the block data and address
;
; input:
; d4.w = Screen Y draw position
; d5.w = Screen X draw position (skipped for GetBlockData_2)
; a3.l = Screen position data
; a4.l = Layout address
;
; output:
; a0.l = Address of block ID in chunk RAM
; a1.l = Address of block
; ---------------------------------------------------------------------------

; DrawBlocks:
GetBlockData:
                add.w   (a3),d5                         ; add Screen X position

GetBlockData_2:
                add.w   4(a3),d4                        ; add Screen Y position
                lea     (v_16x16).w,a1                  ; load block RAM

; Turn Y coordinate into index into level layout
                move.w  d4,d3                           ; copy X position to d3
                lsr.w   #1,d3                           ; divide by 2
                andi.w  #$380,d3                        ; keep in range of layout's Y size ($400 per plane) in multiples of 1 row ($80 per row, $40 per plane)

; Turn X coordinate into index into level layout
                lsr.w   #3,d5                           ; divide X by 8
                move.w  d5,d0                           ; copy to d0
                lsr.w   #5,d0                           ; divide by $20 (/$100)
                andi.w  #$7F,d0                         ; keep in range of layout's X size ($80 per row, $40 per plane)

; Get chunk from level layout
                add.w   d3,d0                           ; fuse Y and X together (d0 = layout position of chunk)
                moveq   #$FFFFFFFF,d3                   ; prepare RAM address ($FFFF???? for layout)
                move.b  (a4,d0.w),d3                    ; load correct chunk ID from layout
                beq.s   .return                         ; if the chunk is 0, branch (chunk 0 is empty, no drawing necessary)

; Turn chunk ID into index into chunk table
                subq.b  #1,d3                           ; minus 1 (01 = 00 | 02 = 01 | 03 = 02, etc)
                andi.w  #$7F,d3                         ; clear upper byte and keep within $80 chunks ($FFFF0000 to $FFFF007F)
                ror.w   #7,d3                           ; multiply by 512 (d3 = correct chunk's RAM address)

; Turn Y coordinate into index into chunk
                add.w   d4,d4                           ; multiply Y position by 2
                andi.w  #$1E0,d4                        ; keep in range of chunk's Y size (512 per chunk) in multiples of $20 (16 blocks, 2 bytes each)

; Turn X coordinate into index into chunk
                andi.w  #$1E,d5                         ; keep in range of chunk's X size (16 blocks, 2 bytes each) in multiples of 2 (2 bytes per block)

; Get block metadata from chunk
                add.w   d4,d3                           ; add block's Y position to the chunk address in d3
                add.w   d5,d3                           ; add block's X position to the chunk address in d3
                movea.l d3,a0                           ; copy chunk/block address to a0
                move.w  (a0),d3                         ; load block ID from chunk

; Turn block ID into address
                andi.w  #$3FF,d3                        ; get only block ID
                lsl.w   #3,d3                           ; multiply by 8 (8 bytes per block)
                adda.w  d3,a1                           ; advance block RAM to correct block location

; locret_6C1E:
                .return:
                rts                                     ; return
; End of function GetBlockData

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to calculate the plane position for VRAM $C000 - $FFFF
;
; input:
; d4.w = Screen Y draw position
; d5.w = Screen X draw position (skipped for Calc_VRAM_Pos_2)
; a3.l = Screen position data
;
; output:
; d0.l = VDP control port address of plane position (words swapped for convenience)
; ---------------------------------------------------------------------------

; CalcPlaneC000:
Calc_VRAM_Pos:
                add.w   (a3),d5                         ; add Screen X position

Calc_VRAM_Pos_2:
                add.w   4(a3),d4                        ; add Screen Y position

; Floor the coordinates to the nearest pair of tiles (the size of a block)
; Also note that this wraps the value to the size of the plane:
; The plane is 64*8 wide, so wrap at $100, and it's 32*8 tall, so wrap at $200
                andi.w  #$F0,d4                         ; keep in range of plane Y size ($100) in multiples of 16 pixels (block size)
                andi.w  #$1F0,d5                        ; keep in range of plane X size ($200) in multiples of 16 pixels (block size)

; Transform the adjusted coordinates into a VDP command
                lsl.w   #4,d4                           ; multiply Y by 16 (multiples of $100)
                lsr.w   #2,d5                           ; divide X by 4 (multiples of 4)
                add.w   d5,d4                           ; fuse X to Y
                moveq   #3,d0                           ; prepare VDP setting $C000+ address
                swap    d0                              ; send to upper word
                move.w  d4,d0                           ; load calculated plane position
                rts                                     ; return (d0 contains VDP control port address)
; End of function Calc_VRAM_Pos

; ===========================================================================
; ---------------------------------------------------------------------------
; Abandoned, unused rroutine to calculate the plane position for VRAM $8000 - $BFFF
;
; input:
; d4.w = Screen Y draw position
; d5.w = Screen X draw position
; a3.l = Screen position data
;
; output:
; d0.l = VDP control port address of plane position (words swapped for convenience)
; ---------------------------------------------------------------------------
; What this does is swap the background nametable with the window layer in order
; to create a third scrolling layer that appears above the foreground. However,
; this comes at the cost of the background becoming garbled at the bottom of the
; screen, which was likely what contributed in its removal. Internally, it was
; known as "Plane Z", and was also the intended use of the third layout entry
; Presumably, this (alongside bit 3 of obRender) was what was used to achieve the
; foreground effect seen in the Tokyo Toy Show '90. Ultimately, Sonic 2 repurposed
; this code to draw player 2's foreground in multiplayer
; ---------------------------------------------------------------------------

; sub_6C3C: Calc_VRAM_Pos_Unknown: CalcPlane8000:
Calc_VRAM_Pos_PlaneZ:
                add.w   4(a3),d4                        ; add Screen Y position
                add.w   (a3),d5                         ; add Screen X position
                andi.w  #$F0,d4                         ; keep in range of plane Y size ($100) in multiples of 16 pixels (block size)
                andi.w  #$1F0,d5                        ; keep in range of plane X size ($200) in multiples of 16 pixels (block size)
                lsl.w   #4,d4                           ; multiply Y by 16 (multiples of $100)
                lsr.w   #2,d5                           ; divide X by 4 (multiples of 4)
                add.w   d5,d4                           ; fuse X to Y
                moveq   #2,d0                           ; prepare VDP setting $8000+ address
                swap    d0                              ; send to upper word
                move.w  d4,d0                           ; load calculated plane position
                rts                                     ; return (d0 contains VDP control port address)
; End of function Calc_VRAM_Pos_PlaneZ

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to draw the current level graphics to the entire screen,
; used to load tiles as soon as the level appears
; ---------------------------------------------------------------------------

; DrawLevel_Full: DrawTilesAtStart:
