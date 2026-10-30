LevSelControls:
                move.b  (v_jpadpress1).w,d1             ; get current button presses
                andi.b  #btnUp+btnDn,d1                 ; is up/down pressed this frame?
                bne.s   LevSel_UpDown                   ; if yes, branch
                subq.w  #1,(v_levseldelay).w            ; if held, subtract 1 from delay until next move
                bpl.s   LevSel_SndTest                  ; if time remains, branch

LevSel_UpDown:
                move.w  #12-1,(v_levseldelay).w         ; reset time delay
                move.b  (v_jpadhold1).w,d1              ; get currently held buttons
                andi.b  #btnUp+btnDn,d1                 ; is up/down held?
                beq.s   LevSel_SndTest                  ; if not, branch
                move.w  (v_levselitem).w,d0             ; get currently selected line
                btst    #bitUp,d1                       ; is up held?
                beq.s   LevSel_Down                     ; if not, branch
                subq.w  #1,d0                           ; move up 1 selection
                bhs.s   LevSel_Down                     ; if entry is still valid, branch
                moveq   #levsel_line_count-1,d0         ; if selection moves below 0, jump to selection last row

LevSel_Down:
                btst    #bitDn,d1                       ; is down held?
                beq.s   LevSel_Refresh                  ; if not, branch
                addq.w  #1,d0                           ; move down 1 selection
                cmpi.w  #levsel_line_count,d0           ; is selection past the last one now?
                blo.s   LevSel_Refresh                  ; if not, branch
                moveq   #0,d0                           ; if selection moves past the last row, jump to selection 0

LevSel_Refresh:
                move.w  d0,(v_levselitem).w             ; set new selection
                bsr.w   LevSelTextLoad                  ; refresh text
                rts
; ===========================================================================

LevSel_SndTest:
                cmpi.w  #levsel_sndtest_row,(v_levselitem).w  ; is sound test row selected?
                bne.s   LevSel_NoMove                   ; if not, branch
                move.b  (v_jpadpress1).w,d1             ; get currently pressed buttons
                andi.b  #btnR+btnL,d1                   ; is left/right pressed?
                beq.s   LevSel_NoMove                   ; if not, branch

                move.w  (v_levselsound).w,d0            ; get currently selected sound test number
                btst    #bitL,d1                        ; is left pressed?
                beq.s   LevSel_Right                    ; if not, branch
                subq.w  #1,d0                           ; subtract 1 from sound test
                bhs.s   LevSel_Right                    ; is result still positive? if yes, branch
                moveq   #sfx__Last-$80,d0               ; if sound test moves below 0, set to last entry (non-$80 based)

LevSel_Right:
                btst    #bitR,d1                        ; is right pressed?
                beq.s   LevSel_Refresh2                 ; if not, branch
                addq.w  #1,d0                           ; add 1 to sound test
                cmpi.w  #sfx__Last-$80+1,d0             ; is result now past the last entry?
                blo.s   LevSel_Refresh2                 ; if not, branch
                moveq   #0,d0                           ; if sound test moves above last entry, set to 0

LevSel_Refresh2:
                move.w  d0,(v_levselsound).w            ; set sound test number
                bsr.w   LevSelTextLoad                  ; refresh text

LevSel_NoMove:
                rts
; End of function LevSelControls

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to load level select text
; ---------------------------------------------------------------------------

levsel_line_count:   equ     21                          ; total number of lines
levsel_line_length:   equ     24                          ; characters per line
levsel_sndtest_row:   equ     levsel_line_count-1         ; row index of the sound test
levsel_sndtest_col:   equ     levsel_line_length-8        ; column offset for the sound test number

levsel_start_row:   equ     4                           ; top tile offset for start position
levsel_start_col:   equ     8                           ; left tile offset for start position
levsel_vram_main:   equ     vram_bg+(levsel_start_row<<7)+(levsel_start_col<<1)  ; nametable address in VRAM
levsel_vram_sndtestnum:   equ     levsel_vram_main+(levsel_sndtest_row<<7)+(levsel_sndtest_col<<1)  ; nametable address for sound test numbers

levsel_white:   equ     ArtTile_Level_Select_Font|Tile_Pal4|Tile_Prio  ; VRAM setting for white text (non-selected lines)
levsel_yellow:   equ     ArtTile_Level_Select_Font|Tile_Pal3|Tile_Prio  ; VRAM setting for yellow text (selected line)

; ---------------------------------------------------------------------------

LevSelTextLoad:
; Write main text in white
                lea     (LevelMenuText).l,a1            ; load menu text offset
                lea     (vdp_data_port).l,a6            ; prepare VDP data write
                locVRAM levsel_vram_main,d4             ; prepare base VRAM nametable location in d4
                move.w  #levsel_white,d3                ; VRAM setting
                moveq   #levsel_line_count-1,d1         ; number of lines of text to write
.DrawAll:   move.l  d4,4(a6)                    ; write to VDP
                bsr.w   LevSel_ChgLine                  ; draw line of text
                addi.l  #$00800000,d4                   ; jump to next line
                dbf     d1,.DrawAll                     ; repeat until all lines are drawn

; Draw currently selected line in yellow
                moveq   #0,d0                           ; clear d0
                move.w  (v_levselitem).w,d0             ; get currently selected line
                move.w  d0,d1                           ; back up selected line
                locVRAM levsel_vram_main,d4             ; prepare base VRAM nametable location in d4
                lsl.w   #7,d0                           ; times $80
                swap    d0                              ; swap so that line now becomes VRAM nametable offset
                add.l   d0,d4                           ; add that to base VRAM location
                lea     (LevelMenuText).l,a1            ; load menu text offset
                if      levsel_line_length=24
                lsl.w   #3,d1                           ; times 8
                move.w  d1,d0                           ; copy result
                add.w   d1,d1                           ; times
                add.w   d0,d1                           ; ...3 (because default line length 8 x 3 = 24)
                else
; The above calculation assumes 24 as line length, we need a different approach if it changes
                mulu.w  #levsel_line_length,d1          ; multiply selected line index by line length
                endif
                adda.w  d1,a1                           ; add to menu text offset
                move.w  #levsel_yellow,d3               ; prepare selected-line VRAM setting
                move.l  d4,4(a6)                        ; write to VDP
                bsr.w   LevSel_ChgLine                  ; recolour selected line

; Write sound test numbers
                move.w  #levsel_white,d3                ; draw numbers in white by default
                cmpi.w  #levsel_sndtest_row,(v_levselitem).w  ; is currently selected line the sound test?
                bne.s   LevSel_DrawSnd                  ; if not, branch
                move.w  #levsel_yellow,d3               ; draw numbers in yellow
LevSel_DrawSnd:
                locVRAM levsel_vram_sndtestnum          ; write sound test number position to VRAM
                move.w  (v_levselsound).w,d0            ; get currently selected sound test number
                addi.w  #$80,d0                         ; make sound ID to be drawn $80-based
                move.b  d0,d2                           ; backup number
                lsr.b   #4,d0                           ; move first digit to lower nybble
                bsr.w   LevSel_ChgSnd                   ; draw 1st digit
                move.b  d2,d0                           ; restore backup
                bsr.w   LevSel_ChgSnd                   ; draw 2nd digit
                rts
; ===========================================================================

LevSel_ChgSnd:
                andi.w  #$F,d0                          ; mask out upper nybble
                cmpi.b  #$A,d0                          ; is digit $A-$F?
                blo.s   .DrawNum                        ; if not, branch
                addi.b  #7,d0                           ; use letter characters
.DrawNum:   add.w   d3,d0                       ; combine number with VRAM setting (white or yellow)
                move.w  d0,(a6)                         ; send to VRAM
                rts
; ===========================================================================

LevSel_ChgLine:
                moveq   #levsel_line_length-1,d2        ; number of characters per line

.LineLoop:   moveq   #0,d0                       ; clear d0
                move.b  (a1)+,d0                        ; get current character
                bpl.s   .CharOk                         ; is it a valid ASCII character? if yes, branch
                move.w  #0,(a6)                         ; draw a blank character
                dbf     d2,.LineLoop                    ; loop until all characters are drawn
                rts

.CharOk:   add.w   d3,d0                       ; combine char with VRAM setting (white or yellow)
                move.w  d0,(a6)                         ; send to VRAM
                dbf     d2,.LineLoop                    ; loop until all characters are drawn
                rts
; End of function LevSelTextLoad

; ===========================================================================
; ---------------------------------------------------------------------------
; Level select menu text
; ---------------------------------------------------------------------------
; This is just for the actual text. For the level pointers, see: LevSel_Ptrs
; ---------------------------------------------------------------------------

LevelMenuText:
                charset ' ', $FF
                charset '0','9',$00
                charset '$', $0A
                charset '-', $0B
                charset '=', $0C
                charset '>', $0D
; charset '>', $0E ; there are two identical right arrows in the font for some reason
                charset 'Y','Z',$0F                     ; Y and Z come before A-X
                charset 'A','X',$11

                dc.b    "GREEN HILL ZONE  STAGE 1"
                dc.b    "                 STAGE 2"
                dc.b    "                 STAGE 3"
                if      Revision=0
; old level order
                dc.b    "LABYRINTH ZONE   STAGE 1"
                dc.b    "                 STAGE 2"
                dc.b    "                 STAGE 3"
                dc.b    "MARBLE ZONE      STAGE 1"
                dc.b    "                 STAGE 2"
                dc.b    "                 STAGE 3"
                dc.b    "STAR LIGHT ZONE  STAGE 1"
                dc.b    "                 STAGE 2"
                dc.b    "                 STAGE 3"
                dc.b    "SPRING YARD ZONE STAGE 1"
                dc.b    "                 STAGE 2"
                dc.b    "                 STAGE 3"
                else
; correct level order
                dc.b    "MARBLE ZONE      STAGE 1"
                dc.b    "                 STAGE 2"
                dc.b    "                 STAGE 3"
                dc.b    "SPRING YARD ZONE STAGE 1"
                dc.b    "                 STAGE 2"
                dc.b    "                 STAGE 3"
                dc.b    "LABYRINTH ZONE   STAGE 1"
                dc.b    "                 STAGE 2"
                dc.b    "                 STAGE 3"
                dc.b    "STAR LIGHT ZONE  STAGE 1"
                dc.b    "                 STAGE 2"
                dc.b    "                 STAGE 3"
                endif
                dc.b    "SCRAP BRAIN ZONE STAGE 1"
                dc.b    "                 STAGE 2"
                dc.b    "                 STAGE 3"
                dc.b    "FINAL ZONE              "
                dc.b    "SPECIAL STAGE           "
                dc.b    "SOUND SELECT            "
                even

                if      MOMPASS=1
                if      *-(levsel_line_count*levsel_line_length)<>LevelMenuText
                warning "LevelMenuText does not match expected line count/length."
                endif
                if      (LevSel_PtrsEnd-LevSel_Ptrs)/2<>levsel_line_count
                warning "LevSel_Ptrs does not match expected line count."
                endif
                endif

                charset                                 ; reset charset to default
                even

; ===========================================================================
; ---------------------------------------------------------------------------
; Music playlist for the start of a level. Note that restarting the music
; after invincibility has worn off is controlled in MusicList2 (part of
; Sonic's object). Bosses have the post-defeat music hardcoded
; ---------------------------------------------------------------------------

MusicList:
                dc.b    bgm_GHZ                         ; GHZ
                dc.b    bgm_LZ                          ; LZ
                dc.b    bgm_MZ                          ; MZ
                dc.b    bgm_SLZ                         ; SLZ
                dc.b    bgm_SYZ                         ; SYZ
                dc.b    bgm_SBZ                         ; SBZ
                zonewarning MusicList,1
                dc.b    bgm_FZ                          ; Ending
                even

; ===========================================================================
; ---------------------------------------------------------------------------
; Level
; ---------------------------------------------------------------------------

; Level:
