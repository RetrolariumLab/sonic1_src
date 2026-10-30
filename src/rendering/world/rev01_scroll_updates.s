; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to draw the level's "background" graphics in strips as the screen moves
; Background only - used by title screen
; ---------------------------------------------------------------------------

; sub_6886: DrawLevel_Strips_BG: DrawTilesWhenMoving_BGOnly:
LoadTilesAsYouMove_BGOnly:
                lea     (vdp_control_port).l,a5         ; load VDP control port
                lea     (vdp_data_port).l,a6            ; load VDP data port

                lea     (v_bg1_scroll_flags).w,a2       ; load background draw flags
                lea     (v_bgscreenposx).w,a3           ; load background position data
                lea     (v_lvllayout_bg).w,a4           ; load background layout
                move.w  #$6000,d2                       ; prepare VDP $E000 (BG plane) VRAM setting
                bsr.w   DrawBG_Top                      ; draw the top section of the BG

                lea     (v_bg2_scroll_flags).w,a2       ; load background draw flags
                lea     (v_bg2screenposx).w,a3          ; load background position data
                bra.w   DrawBG_Bottom                   ; draw the bottom section of the BG
; End of function LoadTilesAsYouMove_BGOnly

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to draw the level's graphics in strips as the screen moves
; Foreground and background - used by levels
; ---------------------------------------------------------------------------

; DrawLevel_Strips: DrawTilesWhenMoving:
LoadTilesAsYouMove:
                lea     (vdp_control_port).l,a5         ; load VDP control port
                lea     (vdp_data_port).l,a6            ; load VDP data port

; First, update the background
                lea     (v_bg1_scroll_flags_dup).w,a2   ; load background draw flags
                lea     (v_bgscreenposx_dup).w,a3       ; load background position data
                lea     (v_lvllayout_bg).w,a4           ; load background layout
                move.w  #$6000,d2                       ; prepare VDP $E000 (BG plane) VRAM setting
                bsr.w   DrawBG_Top                      ; draw the top section of the BG

                lea     (v_bg2_scroll_flags_dup).w,a2   ; load background draw flags
                lea     (v_bg2screenposx_dup).w,a3      ; load background position data
                bsr.w   DrawBG_Bottom                   ; draw the bottom section of the BG

; REV01 added a third scroll block, though, technically,
; the RAM for it was already there in REV00
                lea     (v_bg3_scroll_flags_dup).w,a2   ; load background block 3 draw flags
                lea     (v_bg3screenposx_dup).w,a3      ; load background block 3 position data
                bsr.w   DrawBG_Block3                   ; draw the third block of the BG

; Then, update the foreground
                lea     (v_fg_scroll_flags_dup).w,a2    ; load foreground draw flags
                lea     (v_screenposx_dup).w,a3         ; load foreground position data
                lea     (v_lvllayout_fg).w,a4           ; load foreground layout
                move.w  #$4000,d2                       ; prepare VDP $C000 (FG plane) VRAM setting

; ---------------------------------------------------------------------------
; Drawing FG block strips
; (Note that 16 is the size of a block in pixels, this goes for all cases)
; ---------------------------------------------------------------------------

                tst.b   (a2)                            ; have any of the FG draw flags been set?
                beq.s   .return                         ; if not, branch (no drawing is required)

; --- FG Top ---

                bclr    #0,(a2)                         ; clear up draw flag
                beq.s   .checkDown                      ; if it wasn't set, branch

; Draw new tiles at the top
                moveq   #-16,d4                         ; set X and Y positions to top left of screen
                moveq   #-16,d5                         ; ''
                bsr.w   Calc_VRAM_Pos                   ; get the plane position
                moveq   #-16,d4                         ; set X and Y positions to top left of screen
                moveq   #-16,d5                         ; ''
                bsr.w   DrawBlocks_LR                   ; draw a horizontal line of blocks above the screen

; --- FG Bottom ---

; loc_6908:
.checkDown:
                bclr    #1,(a2)                         ; clear down draw flag
                beq.s   .checkLeft                      ; if it wasn't set, branch

; Draw new tiles at the bottom
                move.w  #224,d4                         ; set X and Y positions to bottom left of screen
                moveq   #-16,d5                         ; ''
                bsr.w   Calc_VRAM_Pos                   ; get the plane position
                move.w  #224,d4                         ; set X and Y positions to bottom left of screen
                moveq   #-16,d5                         ; ''
                bsr.w   DrawBlocks_LR                   ; draw a horizontal line of blocks below the screen

; --- FG Left ---

; loc_6922:
.checkLeft:
                bclr    #2,(a2)                         ; clear left draw flag
                beq.s   .checkRight                     ; if it wasn't set, branch

; Draw new tiles on the left
                moveq   #-16,d4                         ; set X and Y positions to top left of screen
                moveq   #-16,d5                         ; ''
                bsr.w   Calc_VRAM_Pos                   ; get the plane position
                moveq   #-16,d4                         ; set X and Y positions to top left of screen
                moveq   #-16,d5                         ; ''
                bsr.w   DrawBlocks_TB                   ; draw a vertical line of blocks to the left of the screen

; --- FG Right ---

; loc_6938:
.checkRight:
                bclr    #3,(a2)                         ; clear right draw flag
                beq.s   .return                         ; if it wasn't set, branch

; Draw new tiles on the right
                moveq   #-16,d4                         ; set X and Y positions to top right of screen
                move.w  #320,d5                         ; ''
                bsr.w   Calc_VRAM_Pos                   ; get the plane position
                moveq   #-16,d4                         ; set X and Y positions to top right of screen
                move.w  #320,d5                         ; ''
                bsr.w   DrawBlocks_TB                   ; draw a vertical line of blocks to the right of the screen

; locret_6952:
.return:
                rts                                     ; return
; End of function LoadTilesAsYouMove

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to draw BG block strips - Top scroll section (scroll block A)
; ---------------------------------------------------------------------------

; sub_6954: DrawBGScrollBlock1:
DrawBG_Top:
                tst.b   (a2)                            ; have any of the BG top section draw flags been set?
                beq.w   .return                         ; if not, branch (no drawing is required)

; --- BG Top ---

                bclr    #0,(a2)                         ; clear up draw flag
                beq.s   .checkDown                      ; if it wasn't set, branch

; Draw new tiles at the top
                moveq   #-16,d4                         ; set X and Y positions to top left of screen
                moveq   #-16,d5                         ; ''
                bsr.w   Calc_VRAM_Pos                   ; get the plane position
                moveq   #-16,d4                         ; set X and Y positions to top left of screen
                moveq   #-16,d5                         ; ''
                bsr.w   DrawBlocks_LR                   ; draw a horizontal line of blocks above the screen

; --- BG Bottom ---

; loc_6972:
.checkDown:
                bclr    #1,(a2)                         ; clear down draw flag
                beq.s   .checkLeft                      ; if it wasn't set, branch

; Draw new tiles at the bottom
                move.w  #224,d4                         ; set X and Y positions to bottom left of screen
                moveq   #-16,d5                         ; ''
                bsr.w   Calc_VRAM_Pos                   ; get the plane position
                move.w  #224,d4                         ; set X and Y positions to bottom left of screen
                moveq   #-16,d5                         ; ''
                bsr.w   DrawBlocks_LR                   ; draw a horizontal line of blocks below the screen

; --- BG Left (Top Section) ---

; loc_698E:
.checkLeft:
                bclr    #2,(a2)                         ; clear left draw flag
                beq.s   .checkRight                     ; if it wasn't set, branch

; Draw new tiles on the left
                moveq   #-16,d4                         ; set X and Y positions to top left of screen
                moveq   #-16,d5                         ; ''
                bsr.w   Calc_VRAM_Pos                   ; get the plane position
                moveq   #-16,d4                         ; set X and Y positions to top left of screen
                moveq   #-16,d5                         ; ''
                bsr.w   DrawBlocks_TB                   ; draw a vertical line of blocks to the left of the screen

; --- BG Right (Top Section) ---

; loc_69BE:
.checkRight:
                bclr    #3,(a2)                         ; clear right draw flag
                beq.s   .checkTopAll                    ; if it wasn't set, branch

; Draw new tiles on the right
                moveq   #-16,d4                         ; set X and Y positions to top right of screen
                move.w  #320,d5                         ; ''
                bsr.w   Calc_VRAM_Pos                   ; get the plane position
                moveq   #-16,d4                         ; set X and Y positions to top right of screen
                move.w  #320,d5                         ; ''
                bsr.w   DrawBlocks_TB                   ; draw a vertical line of blocks to the right of the screen

; locj_6D70:
                .checkTopAll:
                bclr    #4,(a2)                         ; clear top-all draw flag
                beq.s   .checkBottomAll                 ; if it wasn't set, branch

; Draw entire row at the top
                moveq   #-16,d4                         ; Y coordinate = 16px (size of block) above top
                moveq   #0,d5                           ; clear X position (start at very left of screen)
                bsr.w   Calc_VRAM_Pos_2                 ; get the plane position (ignore d5 = X width)
                moveq   #-16,d4                         ; set Y position to top of screen
                moveq   #0,d5                           ; clear X position (start at very left of screen)
                moveq   #(512/16)-1,d6                  ; set number of blocks to draw horizontally (entire plane's width)
                bsr.w   DrawBlocks_LR_3                 ; draw a horizontal line of blocks above the screen

; locj_6D88:
                .checkBottomAll:
                bclr    #5,(a2)                         ; clear bottom-all draw flag
                beq.s   .return                         ; if it wasn't set, branch

; Draw entire row at the bottom
                move.w  #224,d4                         ; y coordinate - bottom of screen
                moveq   #0,d5                           ; clear X position (start at very left of screen)
                bsr.w   Calc_VRAM_Pos_2                 ; get the plane position (ignore d5 = X width)
                move.w  #224,d4                         ; set Y position to bottom of screen
                moveq   #0,d5                           ; clear X position (start at very left of screen)
                moveq   #(512/16)-1,d6                  ; set number of blocks to draw horizontally (entire plane's width)
                bsr.w   DrawBlocks_LR_3                 ; draw a horizontal line of blocks below the screen

; locret_69F2:
.return:
                rts                                     ; return
; End of function DrawBG_Top

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to draw BG block strips - Bottom scroll section (below scroll block A)
; ---------------------------------------------------------------------------

; sub_69F4: DrawBGScrollBlock2:
DrawBG_Bottom:
                tst.b   (a2)                            ; have any of the BG bottom section draw flags been set?
                beq.w   .return                         ; if not, branch (no drawing is required)

                cmpi.b  #id_SBZ,(v_zone).w              ; is current Zone SBZ?
                beq.w   Draw_SBZ                        ; if yes, branch

                bclr    #0,(a2)                         ; clear flag for redraw left (REV01 uses bit 0 for redraw left flag)
                beq.s   .checkRight                     ; branch if already clear

; Draw new tiles on the left
                move.w  #224/2,d4                       ; draw the bottom half of the screen
                moveq   #-16,d5                         ; x coordinate - left of screen
                bsr.w   Calc_VRAM_Pos                   ; get the plane position
                move.w  #224/2,d4                       ; draw the bottom half of the screen
                moveq   #-16,d5                         ; x coordinate - left of screen
                moveq   #3-1,d6                         ; draw three rows... could this be a repurposed version of the above unused code?
                bsr.w   DrawBlocks_TB_2                 ; draw three blocks vertically to the left of the screen

; locj_6DD2:
.checkRight:
                bclr    #1,(a2)                         ; clear flag for redraw right (REV01 uses bit 0 for redraw right flag)
                beq.s   .return                         ; branch if already clear

; Draw new tiles on the right
                move.w  #224/2,d4                       ; draw the bottom half of the screen
                move.w  #320,d5                         ; x coordinate - right of screen
                bsr.w   Calc_VRAM_Pos                   ; get the plane position
                move.w  #224/2,d4                       ; draw the bottom half of the screen
                move.w  #320,d5                         ; x coordinate - right of screen
                moveq   #3-1,d6                         ; draw three Blocks
                bsr.w   DrawBlocks_TB_2                 ; draw three blocks vertically to the right of the screen

; locj_6DF2:
.return:
                rts                                     ; return
; End of function DrawBG_Bottom

; ===========================================================================
; ---------------------------------------------------------------------------
; Special drawing logic for SBZ background (REV01)
; ---------------------------------------------------------------------------

; locj_6DF4:
BG_ScrollBlockMap_SBZ:
; Offsets to retrieve BG X-positions in DrawBG_XPos_Ptrs and DrawBG_XPosCopy_Ptrs (0/2/4/6)
                dc.b    0,0,0,0,0,6,6,6,6,6,6,6,6,6,6,4  ; $00-$F
                dc.b    4,4,4,4,4,4,2,2,2,2,2,2,2,2,2,2  ; $10-$1F
                dc.b    2,0                             ; $20-21
; ===========================================================================

Draw_SBZ:
                moveq   #-16,d4                         ; draw 16px above top of screen
                bclr    #0,(a2)                         ; clear flag for redraw top
                bne.s   .drawTopOrBottom                ; branch if it was set
                bclr    #1,(a2)                         ; clear flag for redraw bottom
                beq.s   .checkMore                      ; branch if already clear
                move.w  #224,d4                         ; draw at bottom of screen

; locj_6E28:
.drawTopOrBottom:
                lea     (BG_ScrollBlockMap_SBZ+1).l,a0  ; +1 to offset -16
                move.w  (v_bgscreenposy).w,d0           ; get current BG Y position
                add.w   d4,d0                           ; d0 = v_bgscreenposy + (-16 or +224)
                andi.w  #$1F0,d0                        ; round down to nearest 16
                lsr.w   #4,d0                           ; divide by 16
                move.b  (a0,d0.w),d0                    ; retrieve offset value from input BG_ScrollBlockMap (0/2/4/6)
                lea     (DrawBG_XPosCopy_Ptrs).l,a3     ; dc.w v_bg1_x_pos_copy, v_bg1_x_pos_copy, v_bg2_x_pos_copy, v_bg3_x_pos_copy
                movea.w (a3,d0.w),a3                    ; get pointer to bg block 1/2/3 x pos
                beq.s   .bgXPos0                        ; branch if 0
                moveq   #-16,d5                         ; x coordinate - left of screen
                movem.l d4-d5,-(sp)                     ; store X and Y positions
                bsr.w   Calc_VRAM_Pos                   ; d0 = VDP command for bg nametable
                movem.l (sp)+,d4-d5                     ; restore X and Y positions
                bsr.w   DrawBlocks_LR                   ; draw full row on top or bottom of screen
                bra.s   .checkMore                      ; check for more work to do

; locj_6E5E:
                .bgXPos0:
                moveq   #0,d5                           ; clear X position (start at very left of screen)
                movem.l d4-d5,-(sp)                     ; store X and Y positions
                bsr.w   Calc_VRAM_Pos_2                 ; get the plane position (ignore d5 = X width)
                movem.l (sp)+,d4-d5                     ; restore X and Y positions
                moveq   #(512/16)-1,d6                  ; draw entire row
                bsr.w   DrawBlocks_LR_3                 ; draw a horizontal line of blocks above or below the screen
; ---------------------------------------------------------------------------

; locj_6E72:
.checkMore:
                tst.b   (a2)                            ; are any other redraw flags set?
                bne.s   .more                           ; if yes, branch
                rts                                     ; return

; locj_6E78:
.more:
                moveq   #-16,d4                         ; y coordinate - top of screen
                moveq   #-16,d5                         ; x coordinate - left of screen
                move.b  (a2),d0                         ; get remaining redraw flag bits
                andi.b  #%10101000,d0                   ; read bits 7, 5 and 3 only ($A8)
                beq.s   .doMore                         ; if none are set, branch
                lsr.b   #1,d0                           ; shift into bits 6, 4 and 2 respectively
                move.b  d0,(a2)                         ; set as new draw flag bits
                move.w  #320,d5                         ; x coordinate - right of screen

; locj_6E8C:
                .doMore:
                lea     (BG_ScrollBlockMap_SBZ).l,a0    ; load BG scroll map data for SBZ
                move.w  (v_bgscreenposy).w,d0           ; get current BG Y position
                andi.w  #$1F0,d0                        ; round down to nearest 16
                lsr.w   #4,d0                           ; divide by 16
                lea     (a0,d0.w),a0                    ; advance pointer inside scroll map data for current BG Y position
                bra.w   DrawBG_ColumnForBGIndex         ; draw column
; ===========================================================================

; locj_6EA4: DrawBGScrollBlock3:
DrawBG_Block3:
                tst.b   (a2)                            ; are any redraw flags set?
                beq.w   .return                         ; if not, branch

                cmpi.b  #id_MZ,(v_zone).w               ; is current zone MZ?
                beq.w   Draw_MZ                         ; if yes, branch

                bclr    #0,(a2)                         ; clear flag for redraw left
                beq.s   .checkRight                     ; branch if already clear

; Draw new tiles on the left
                move.w  #64,d4                          ; y coordinate - fourth line from top of screen
                moveq   #-16,d5                         ; x coordinate - left of screen
                bsr.w   Calc_VRAM_Pos                   ; get the plane position
                move.w  #64,d4                          ; y coordinate - fourth line from top of screen
                moveq   #-16,d5                         ; x coordinate - left of screen
                moveq   #3-1,d6                         ; draw three blocks
                bsr.w   DrawBlocks_TB_2                 ; draw three blocks vertically to the left of the screen

; locj_6ED0:
.checkRight:
                bclr    #1,(a2)                         ; clear flag for redraw right
                beq.s   .return                         ; branch if already clear

; Draw new tiles on the right
                move.w  #64,d4                          ; y coordinate - fourth line from top of screen
                move.w  #320,d5                         ; x coordinate - right of screen
                bsr.w   Calc_VRAM_Pos                   ; get the plane position
                move.w  #64,d4                          ; y coordinate - fourth line from top of screen
                move.w  #320,d5                         ; x coordinate - right of screen
                moveq   #3-1,d6                         ; draw three blocks
                bsr.w   DrawBlocks_TB_2                 ; draw three blocks vertically to the right of the screen

; locj_6EF0:
.return:
                rts                                     ; return
; End of function Draw_SBZ

; ===========================================================================
; ---------------------------------------------------------------------------
; Special drawing logic for MZ background (REV01)
; ---------------------------------------------------------------------------

; locj_6EF2:
BG_ScrollBlockMap_MZ:
; Offsets to retrieve BG X-positions in DrawBG_XPos_Ptrs and DrawBG_XPosCopy_Ptrs (0/2/4/6)
                dc.b    0,0,0,0,0,0,6,6,4,4,4,4,4,4,4,4  ; $00-$0F
                dc.b    4,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2  ; $10-$1F
                dc.b    2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2  ; $20-$2F
                dc.b    2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2  ; $30-$3F
                dc.b    2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2  ; $40-$4F
                dc.b    2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2  ; $50-$5F
                dc.b    2,0                             ; $60-$61

; ===========================================================================

Draw_MZ:
                moveq   #-16,d4                         ; draw 16px above top of screen
                bclr    #0,(a2)                         ; clear flag for redraw top
                bne.s   .drawTopOrBottom                ; branch if it was set
                bclr    #1,(a2)                         ; clear flag for redraw bottom
                beq.s   .checkMore                      ; branch if already clear
                move.w  #224,d4                         ; draw at bottom of screen

; locj_6F66:
.drawTopOrBottom:
                lea     (BG_ScrollBlockMap_MZ+1).l,a0   ; +1 to offset -16
                move.w  (v_bgscreenposy).w,d0           ; get current BG Y position
                subi.w  #$200,d0                        ; minus 512
                add.w   d4,d0                           ; d0 = v_bgscreenposy - 512 + (-16 or +224)
                andi.w  #$7F0,d0                        ; limit to multiples of $10
                lsr.w   #4,d0                           ; divide by 16
                move.b  (a0,d0.w),d0                    ; retrieve offset value from input BG_ScrollBlockMap (0/2/4/6)
                movea.w DrawBG_XPosCopy_Ptrs(pc,d0.w),a3  ; use that value to retrieve relevant BG screen position data
                beq.s   .bgXPos0                        ; branch if 0
                moveq   #-16,d5                         ; x coordinate - left of screen
                movem.l d4-d5,-(sp)                     ; store X and Y positions
                bsr.w   Calc_VRAM_Pos                   ; get the plane position
                movem.l (sp)+,d4-d5                     ; restore X and Y positions
                bsr.w   DrawBlocks_LR                   ; draw full row on top or bottom of screen
                bra.s   .checkMore                      ; check for more work to do

; locj_6F9A:
                .bgXPos0:
                moveq   #0,d5                           ; clear X position (start at very left of screen)
                movem.l d4-d5,-(sp)                     ; store X and Y positions
                bsr.w   Calc_VRAM_Pos_2                 ; get the plane position (ignore d5 = X width)
                movem.l (sp)+,d4-d5                     ; restore X and Y positions
                moveq   #(512/16)-1,d6                  ; set number of blocks to draw horizontally (entire plane's width)
                bsr.w   DrawBlocks_LR_3                 ; draw a horizontal line of blocks above or below the screen
; ---------------------------------------------------------------------------

; locj_6FAE:
.checkMore:
                tst.b   (a2)                            ; are any other redraw flags set?
                bne.s   .more                           ; if yes, branch
                rts                                     ; return

; locj_6FB4:
.more:
                moveq   #-16,d4                         ; y coordinate - top of screen
                moveq   #-16,d5                         ; x coordinate - left of screen
                move.b  (a2),d0                         ; get remaining redraw flag bits
                andi.b  #%10101000,d0                   ; read bits 7, 5 and 3 only ($A8)
                beq.s   .doMore                         ; if none are set, branch
                lsr.b   #1,d0                           ; shift into bits 6, 4 and 2 respectively
                move.b  d0,(a2)                         ; set as new draw flag bits
                move.w  #320,d5                         ; x coordinate - right of screen

; locj_6FC8:
                .doMore:
                lea     (BG_ScrollBlockMap_MZ).l,a0     ; load BG scroll map data for MZ
                move.w  (v_bgscreenposy).w,d0           ; get current BG Y position
                subi.w  #$200,d0                        ; minus 512
                andi.w  #$7F0,d0                        ; limit to multiples of $10
                lsr.w   #4,d0                           ; divide by 16
                lea     (a0,d0.w),a0                    ; advance pointer inside scroll map data for current BG Y position
                bra.w   DrawBG_ColumnForBGIndex         ; draw column
; End of function Draw_MZ

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to draw a full column for given BG camera positions (REV01)
;
; input:
; d4.w = Screen Y draw position
; d5.w = Screen X draw position
; a0.l = pointer inside given BG_ScrollBlockMap to retrieve DrawBG_XPosCopy_Ptrs values
; a2.l = v_bg2_scroll_flags
; ---------------------------------------------------------------------------

; locj_6FE4:
DrawBG_XPosCopy_Ptrs:
                dc.w    v_bgscreenposx_dup              ; 0
                dc.w    v_bgscreenposx_dup              ; 2
                dc.w    v_bg2screenposx_dup             ; 4
                dc.w    v_bg3screenposx_dup             ; 6
; ===========================================================================

; locj_6FEC:
DrawBG_ColumnForBGIndex:
                moveq   #((224+16+16)/16)-1,d6          ; prepare number of blocks (entire height of the screen + two extra rows)
                move.l  #$800000,d7                     ; prepare plane row advance rate ($80 bytes per row for *512 plane width)

; locj_6FF4:
.nextBlock:
                moveq   #0,d0                           ; clear d0
                move.b  (a0)+,d0                        ; retrieve next offset value from input BG_ScrollBlockMap (0/2/4/6)
                btst    d0,(a2)                         ; is matching redraw flag set?
                beq.s   .skipDraw                       ; if not, branch
                movea.w DrawBG_XPosCopy_Ptrs(pc,d0.w),a3  ; use that value to retrieve relevant BG screen position data
                movem.l d4-d5/a0,-(sp)                  ; store X and Y positions, and BG_ScrollBlockMap pointer
                movem.l d4-d5,-(sp)                     ; store X and Y positions
                bsr.w   GetBlockData                    ; load block
                movem.l (sp)+,d4-d5                     ; restore X and Y positions
                bsr.w   Calc_VRAM_Pos                   ; get the plane position
                bsr.w   DrawBlock                       ; draw the tiles from the block correctly
                movem.l (sp)+,d4-d5/a0                  ; restore X and Y positions, and BG_ScrollBlockMap pointer

; locj_701C:
                .skipDraw:
                addi.w  #16,d4                          ; advance Y position down by 1 block
                dbf     d6,.nextBlock                   ; repeat for number of blocks in the strip
                clr.b   (a2)                            ; clear all redraw flags
                rts                                     ; return
; End of function DrawBG_ColumnForBGIndex

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to draw a horizontal row of blocks
;
; input:
; d0.l = VDP control port address of plane position (words swapped for convenience)
; d2.w = VRAM address of plane to use (usually $C000 or $E000)
; d4.w = Screen Y draw position
; d5.w = Screen X draw position
; d6.w = Blocks to draw (DrawBlocks_LR_2 only)
; a3.l = Screen position data
; a4.l = Layout address
; a5.l = VDP control port
; a6.l = VDP data port
; ---------------------------------------------------------------------------

; Don't be fooled by the name: this function's for drawing from left to right
; when the camera's moving up or down!

; DrawBlocks_X: DrawRow:
