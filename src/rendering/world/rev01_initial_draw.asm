LoadTilesFromStart:
                lea     (vdp_control_port).l,a5         ; load VDP control port address
                lea     (vdp_data_port).l,a6            ; load VDP data port address

; --- Foreground ---

                lea     (v_screenposx).w,a3             ; load foreground position data
                lea     (v_lvllayout_fg).w,a4           ; load foreground layout
                move.w  #$4000,d2                       ; prepare VDP $C000 (FG plane) VRAM setting
                bsr.s   DrawChunks                      ; draw level data to FG plane ($C000)

; --- Background ---

                lea     (v_bgscreenposx).w,a3           ; load background position data
                lea     (v_lvllayout_bg).w,a4           ; load background layout
                move.w  #$6000,d2                       ; prepare VDP $E000 (BG plane) VRAM setting

                tst.b   (v_zone).w                      ; is current zone GHZ? (zone ID = 0)
                beq.w   Draw_GHZ_BG                     ; if yes, branch
                cmpi.b  #id_MZ,(v_zone).w               ; is current zone MZ?
                beq.w   Draw_MZ_BG                      ; if yes, branch
                cmpi.w  #id_SBZ_act1,(v_zone_act).w     ; is current level SBZ act 1?
                beq.w   Draw_SBZ_act1_BG                ; if yes, branch
                cmpi.b  #id_EndZ,(v_zone).w             ; is current zone the ending sequenc?
                beq.w   Draw_GHZ_BG                     ; if yes, branch (use GHZ)

; fall-through to DrawChunks to draw level data to BG plane ($E000)

; End of function LoadTilesFromStart

; ---------------------------------------------------------------------------
; Drawing an entire plane's worth of level graphics
; ---------------------------------------------------------------------------

; DrawLevel_FullPlane:
DrawChunks:
                moveq   #-16,d4                         ; start Y position at -16 (outside of screen)
                moveq   #((224+16+16)/16)-1,d6          ; prepare number of blocks (entire height of the screen + two extra rows)

                .nextRow:
                movem.l d4-d6,-(sp)                     ; store X position and "strip counter" data
                moveq   #0,d5                           ; clear X position (start at very left of screen)
                move.w  d4,d1                           ; store Y position in d1
                bsr.w   Calc_VRAM_Pos                   ; get plane/VRAM address
                move.w  d1,d4                           ; reload Y position back to d4
                moveq   #0,d5                           ; reclear X position (start at very left of screen)
                moveq   #(512/16)-1,d6                  ; set number of blocks to draw horizontally (entire plane's width)
                bsr.w   DrawBlocks_LR_2                 ; draw the horizontal strip
                movem.l (sp)+,d4-d6                     ; restore X position and "strip counter" data
                addi.w  #16,d4                          ; advance down to next row
                dbf     d6,.nextRow                     ; repeat for all horizontal row strips
                rts                                     ; return
; End of function DrawChunks

; ===========================================================================
; ---------------------------------------------------------------------------
; Initialize GHZ background on level start (REV01)
; ---------------------------------------------------------------------------

Draw_GHZ_BG:
                moveq   #0,d4                           ; start Y position at 0 (top of screen)
                moveq   #((224+16+16)/16)-1,d6          ; prepare number of blocks (entire height of the screen + two extra rows)

; locj_7224:
                .nextRow:
                movem.l d4-d6,-(sp)                     ; store X position and "strip counter" data
                lea     (BG_ScrollBlockMap_GHZ).l,a0    ; load BG scroll map data for GHZ
                move.w  (v_bgscreenposy).w,d0           ; get current BG Y position
                add.w   d4,d0                           ; d0 = v_bgscreenposy + (-16 or +224)
                andi.w  #$F0,d0                         ; limit to multiples of $10, up to one chunk
                bsr.w   DrawBG_RowForBGIndex            ; draw row for BG index from scroll block data
                movem.l (sp)+,d4-d6                     ; restore X position and "strip counter" data
                addi.w  #16,d4                          ; advance down to next row
                dbf     d6,.nextRow                     ; repeat for all horizontal row strips
                rts                                     ; return
; ===========================================================================

; locj_724a:
BG_ScrollBlockMap_GHZ:
; Offsets to retrieve BG X-positions in DrawBG_XPos_Ptrs and DrawBG_XPosCopy_Ptrs (0/2/4/6)
                dc.b    0,0,0,0,6,6,6,4,4,4,0,0,0,0,0,0  ; $00-$0F
; End of function Draw_GHZ_BG

; ===========================================================================
; ---------------------------------------------------------------------------
; Initialize MZ background on level start (REV01)
; ---------------------------------------------------------------------------

; locj_725a:
Draw_MZ_BG:
                moveq   #-16,d4                         ; start Y position at -16 (outside of screen)
                moveq   #((224+16+16)/16)-1,d6          ; prepare number of blocks (entire height of the screen + two extra rows)

; locj_725E:
                .nextRow:
                movem.l d4-d6,-(sp)                     ; store X position and "strip counter" data
                lea     (BG_ScrollBlockMap_MZ+1).l,a0   ; +1 to offset -16
                move.w  (v_bgscreenposy).w,d0           ; get current BG Y position
                subi.w  #$200,d0                        ; minus 512
                add.w   d4,d0                           ; d0 = v_bgscreenposy - 512 + (-16 or +224)
                andi.w  #$7F0,d0                        ; limit to multiples of $10
                bsr.w   DrawBG_RowForBGIndex            ; draw row for BG index from scroll block data
                movem.l (sp)+,d4-d6                     ; restore X position and "strip counter" data
                addi.w  #16,d4                          ; advance down to next row
                dbf     d6,.nextRow                     ; repeat for all horizontal row strips
                rts                                     ; return
; End of function Draw_MZ_BG

; ---------------------------------------------------------------------------
; Initialize SBZ act 1 background on level start (REV01)
; ---------------------------------------------------------------------------

; locj_7288: Draw_SBZ_BG:
Draw_SBZ_act1_BG:
                moveq   #-16,d4                         ; start Y position at -16 (outside of screen)
                moveq   #((224+16+16)/16)-1,d6          ; prepare number of blocks (entire height of the screen + two extra rows)

; locj_728C:
                .nextRow:
                movem.l d4-d6,-(sp)                     ; store X position and "strip counter" data
                lea     (BG_ScrollBlockMap_SBZ+1).l,a0  ; +1 to offset -16
                move.w  (v_bgscreenposy).w,d0           ; get current BG Y position
                add.w   d4,d0                           ; d0 = v_bgscreenposy + (-16 or +224)
                andi.w  #$1F0,d0                        ; round down to nearest 16
                bsr.w   DrawBG_RowForBGIndex            ; draw row for BG index from scroll block data
                movem.l (sp)+,d4-d6                     ; restore X position and "strip counter" data
                addi.w  #16,d4                          ; advance down to next row
                dbf     d6,.nextRow                     ; repeat for all horizontal row strips
                rts                                     ; return
; End of function Draw_SBZ_act1_BG

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to draw a full row for given BG camera positions (REV01)
;
; input:
; d0.w = v_bgscreenposy rounded down to multiples of $10 (may be limited)
; d4.w = Screen Y draw position
; d5.w = Screen X draw position
; a0.l = base pointer to BG_ScrollBlockMap for zone (may be +1)
; ---------------------------------------------------------------------------

; locj_72B2:
DrawBG_XPos_Ptrs:
                dc.w    v_bgscreenposx                  ; 0
                dc.w    v_bgscreenposx                  ; 2
                dc.w    v_bg2screenposx                 ; 4
                dc.w    v_bg3screenposx                 ; 6
; ---------------------------------------------------------------------------

; locj_72Ba:
DrawBG_RowForBGIndex:
                lsr.w   #4,d0                           ; divide input camera Y position by 16
                move.b  (a0,d0.w),d0                    ; retrieve offset value from input BG_ScrollBlockMap (0/2/4/6)
                movea.w DrawBG_XPos_Ptrs(pc,d0.w),a3    ; use that value to retrieve relevant BG screen position data
                beq.s   .bgXPos0                        ; branch if 0
                moveq   #-16,d5                         ; x coordinate - left of screen
                movem.l d4-d5,-(sp)                     ; store X and Y positions
                bsr.w   Calc_VRAM_Pos                   ; get the plane position
                movem.l (sp)+,d4-d5                     ; restore X and Y positions
                bsr.w   DrawBlocks_LR                   ; draw full row on top or bottom of screen
                bra.s   .return                         ; return

; locj_72da:
                .bgXPos0:
                moveq   #0,d5                           ; clear X position (start at very left of screen)
                movem.l d4-d5,-(sp)                     ; store X and Y positions
                bsr.w   Calc_VRAM_Pos_2                 ; get the plane position (ignore d5 = X width)
                movem.l (sp)+,d4-d5                     ; restore X and Y positions
                moveq   #(512/16)-1,d6                  ; set number of blocks to draw horizontally (entire plane's width)
                bsr.w   DrawBlocks_LR_3                 ; draw a horizontal line of blocks above or below the screen

; locj_72EE:
.return:
                rts                                     ; return
; End of function DrawBG_RowForBGIndex
