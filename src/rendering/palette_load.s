PalCycle_Sega:
                tst.b   (v_pcyc_time+1).w               ; is light scanning effect done?
                bne.s   PCycSega_FadeIn                 ; if yes, branch

; ---------------------------------------------------------------------------
; First part of the Sega screen palette cycle (the "light scan effect")
; ---------------------------------------------------------------------------

                lea     (v_palette_line_2).w,a1         ; set target start palette line (affects line 2-4 overall)
                lea     (Pal_Sega1).l,a0                ; get palette cycle colors for the light scanning effect
                moveq   #(Pal_Sega1_end-Pal_Sega1)/2-1,d1  ; set size of colors to write (6 in total)
                move.w  (v_pcyc_num).w,d0               ; load current palcycle position (initialized to -$A)

; loc_2020:
.findScanStart:
                bpl.s   .doLightScan                    ; has start position been found? if yes, branch (d0 >= 0)
                addq.w  #2,a0                           ; get next color in Pal_Sega1
                subq.w  #1,d1                           ; set to load one less color
                addq.w  #2,d0                           ; go to next starting color for light effect
                bra.s   .findScanStart                  ; loop until current position has been found
; ===========================================================================

; loc_202A:
.doLightScan:
                move.w  d0,d2                           ; get current target position
                andi.w  #$1E,d2                         ; limit to one palette line ($20 bytes)
                bne.s   .notTransparent1                ; is it the first (transparent) color? if not, branch
                addq.w  #2,d0                           ; skip over transparent color

; loc_2034:
.notTransparent1:
                cmpi.w  #v_palette_line_4-v_palette_line_1,d0  ; (=$60) would we write past the last palette entry?
                bhs.s   .writeNoMore                    ; if yes, do not write new color
                move.w  (a0)+,(a1,d0.w)                 ; write current light scan color to palette buffer

; loc_203E:
.writeNoMore:
                addq.w  #2,d0                           ; go to next starting color for light effect
                dbf     d1,.doLightScan                 ; loop until all colors have been written

; Palette dumping is done, update next offset or set to next part
                move.w  (v_pcyc_num).w,d0               ; load current palcycle position
                addq.w  #2,d0                           ; go to next starting color
                move.w  d0,d2                           ; get current target position
                andi.w  #$1E,d2                         ; limit to one palette line ($20 bytes)
                bne.s   .notTransparent2                ; is it the first (transparent) color? if not, branch
                addq.w  #2,d0                           ; skip over transparent color

; loc_2054:
.notTransparent2:
                cmpi.w  #v_palette_line_4-v_palette_line_1+4,d0  ; (=$64) has light scan effect finished?
                blt.s   .scanNotDone                    ; if not, branch
                move.w  #(4<<8)+1,(v_pcyc_time).w       ; set delay between fade-in increments (high byte) and "light scan done" flag (low byte)
                moveq   #-6*2,d0                        ; set starting offset for fade-in palette (gets set to 0 for first fade-in step)

; loc_2062:
.scanNotDone:
                move.w  d0,(v_pcyc_num).w
                moveq   #1,d0                           ; clear Z-flag (possibly for a return signal, but now unsued)
                rts                                     ; return
; ===========================================================================

; ---------------------------------------------------------------------------
; Second part of the Sega screen palette cycle (the fade-in)
; ---------------------------------------------------------------------------

; loc_206A:
PCycSega_FadeIn:
                subq.b  #1,(v_pcyc_time).w              ; decrement delay until next brightness increase
                bpl.s   .delayFadeIn                    ; does delay time remain? if yes, branch

                move.b  #4,(v_pcyc_time).w              ; reset delay between fade-in increments
                move.w  (v_pcyc_num).w,d0               ; get current fade-in position
                addi.w  #6*2,d0                         ; go to next set of colors
                cmpi.w  #(6*2)*4,d0                     ; have four color sets been done?
                blo.s   .doFadeIn                       ; if not, do next fade-in step

                moveq   #0,d0                           ; set Z-flag (possibly for a return signal, but now unsued)
                rts                                     ; return
; ===========================================================================

; loc_2088:
.doFadeIn:
                move.w  d0,(v_pcyc_num).w               ; remember position for next fade-in increment
                lea     (Pal_Sega2).l,a0                ; get palette cycle colors for the fade-in effect
                lea     (a0,d0.w),a0                    ; go to relevant color data
                lea     (v_palette_line_1+$04).w,a1     ; set to write past transparent and pure-white color
                move.l  (a0)+,(a1)+                     ; write colors 1 and 2 to buffer
                move.l  (a0)+,(a1)+                     ; write colors 3 and 4 to buffer
                move.w  (a0)+,(a1)                      ; write color 5 to buffer

; Main palette dumping is done, fill remaining palette buffer with 6th color
                lea     (v_palette_line_2).w,a1         ; start from second palette line (up to fourth one)
                moveq   #0,d0                           ; clear d0
                moveq   #((v_palette_line_4-v_palette_line_1)/2)-3-1,d1  ; (=$2C) write 3 lines, minus skipped transparent colors, minus 1

; loc_20A8:
.fillRest:
                move.w  d0,d2                           ; get current target position
                andi.w  #$1E,d2                         ; limit to one palette line ($20 bytes)
                bne.s   .notTransparent3                ; is it the first (transparent) color? if not, branch
                addq.w  #2,d0                           ; skip over transparent color

; loc_20B2:
.notTransparent3:
                move.w  (a0),(a1,d0.w)                  ; write fill color to current palette slot (and don't advance index)
                addq.w  #2,d0                           ; go to next palette target
                dbf     d1,.fillRest                    ; loop until remaining palette has been filled completely

; loc_20BC:
.delayFadeIn:
                moveq   #1,d0                           ; clear Z-flag (possibly for a return signal, but now unsued)
                rts                                     ; return
; End of function PalCycle_Sega

; ===========================================================================
; >>> Palette cycle data used for Sega screen
Pal_Sega1:   bincludeEndMarker "palette/Sega1.bin"  ; used during the light scanning effect
Pal_Sega2:   bincludeEndMarker "palette/Sega2.bin"  ; used during the fade-in (three color sets, 5+1 colors each)

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to load main palettes into the fading buffer
; These get displayed once PaletteFadeIn/PaletteWhiteIn is called

; input:
; d0 = index number for palette
; ---------------------------------------------------------------------------

PalLoad_Fade:
                lea     (Pal_Index).l,a1                ; get palette pointers
                lsl.w   #3,d0                           ; multiply input ID by 8 (size of one palette index entry)
                adda.w  d0,a1                           ; add to palette index pointer to get relevant palette entry
                movea.l (a1)+,a2                        ; get palette data address
                movea.w (a1)+,a3                        ; get target RAM address
                adda.w  #v_palette_fading-v_palette,a3  ; load to palette fade-in buffer instead of active palette buffer (+$80)
                move.w  (a1)+,d7                        ; get length of palette data

.loop:
                move.l  (a2)+,(a3)+                     ; move two colors from palette data to palette buffer RAM
                dbf     d7,.loop                        ; loop until all colors are loaded
                rts                                     ; return
; End of function PalLoad_Fade

; ---------------------------------------------------------------------------
; Subroutine to directly load main palettes to the active palette
; Same as PalLoad_Fade, but without adding $80
; ---------------------------------------------------------------------------

PalLoad:
                lea     (Pal_Index).l,a1                ; get palette pointers
                lsl.w   #3,d0                           ; multiply input ID by 8 (size of one palette index entry)
                adda.w  d0,a1                           ; add to palette index pointer to get relevant palette entry
                movea.l (a1)+,a2                        ; get palette data address
                movea.w (a1)+,a3                        ; get target RAM address
                move.w  (a1)+,d7                        ; get length of palette data

.loop:
                move.l  (a2)+,(a3)+                     ; move two colors from palette data to palette buffer RAM
                dbf     d7,.loop                        ; loop until all colors are loaded
                rts                                     ; return
; End of function PalLoad

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to load underwater palettes into the water fading buffer
; These get displayed once PaletteFadeIn/PaletteWhiteIn is called
; ---------------------------------------------------------------------------

PalLoad_Fade_Water:
                lea     (Pal_Index).l,a1                ; get palette pointers
                lsl.w   #3,d0                           ; multiply input ID by 8 (size of one palette index entry)
                adda.w  d0,a1                           ; add to palette index pointer to get relevant palette entry
                movea.l (a1)+,a2                        ; get palette data address
                movea.w (a1)+,a3                        ; get target RAM address
                suba.w  #v_palette-v_palette_water,a3   ; load to (water) palette fade-in buffer instead of active palette buffer
                move.w  (a1)+,d7                        ; get length of palette data

.loop:
                move.l  (a2)+,(a3)+                     ; move two colors from palette data to palette buffer RAM
                dbf     d7,.loop                        ; loop until all colors are loaded
                rts                                     ; return
; End of function PalLoad_Fade_Water

; ---------------------------------------------------------------------------
; Subroutine to directly load underwater palettes to the active palette
; Same as PalLoad_Fade_Water, but writing $80 before it
; ---------------------------------------------------------------------------

PalLoad_Water:
                lea     (Pal_Index).l,a1                ; get palette pointers
                lsl.w   #3,d0                           ; multiply input ID by 8 (size of one palette index entry)
                adda.w  d0,a1                           ; add to palette index pointer to get relevant palette entry
                movea.l (a1)+,a2                        ; get palette data address
                movea.w (a1)+,a3                        ; get target RAM address
                suba.w  #v_palette-v_palette_water_fading,a3  ; load to active (water) palette buffer instead of main active palette buffer
                move.w  (a1)+,d7                        ; get length of palette data

.loop:
                move.l  (a2)+,(a3)+                     ; move two colors from palette data to palette buffer RAM
                dbf     d7,.loop                        ; loop until all colors are loaded
                rts                                     ; return
; End of function PalLoad_Water

; ===========================================================================
; >>> Palette pointers and palette binary includes
                include "src/rendering/world/palette_index.s"

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to wait for VBlank routines to complete
; ---------------------------------------------------------------------------

; DelayProgram: <-- old misnomer
; WaitForVBla: <-- old name
