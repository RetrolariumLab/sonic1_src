GM_Sega:
; fading out from previous game mode
                move.b  #bgm_Stop,d0                    ; set stop music command
                bsr.w   QueueSound2                     ; stop music
                bsr.w   ClearPLC                        ; stop any potential in-progress PLC
                bsr.w   PaletteFadeOut                  ; fade-out previous game mode
; ---------------------------------------------------------------------------

; screen setup and loading patterns
                lea     (vdp_control_port).l,a6         ; load VDP control port
                move.w  #vreg_mode1|%000100,(a6)        ; use 8-colour mode
                move.w  #vreg_fgvram|(vram_fg>>10),(a6)  ; set foreground nametable address
                move.w  #vreg_bgvram|(vram_bg>>13),(a6)  ; set background nametable address
                move.w  #vreg_bgcolor|0<<4|0,(a6)       ; set background colour (palette entry 0)
                move.w  #vreg_mode3|%0000,(a6)          ; full-screen vertical scrolling
                clr.b   (f_wtr_state).w                 ; clear water state

                disable_ints                            ; disable interrupts
                disable_display                         ; disable screen output
                bsr.w   ClearScreen                     ; wipe the screen

                locVRAM ArtTile_Sega_Tiles*tile_size    ; set target VRAM location for Sega logo patterns
                lea     (Nem_SegaLogo).l,a0             ; load Sega logo patterns
                bsr.w   NemDec                          ; decompress Nemesis-compressed patterns directly to VRAM

                lea     (v_ram_start).l,a1              ; set start of RAM to be used as decompression buffer
                lea     (Eni_SegaLogo).l,a0             ; load Sega logo mappings
                move.w  #ArtTile_Sega_Tiles,d0          ; set art tile for Sega screen mappings
                bsr.w   EniDec                          ; decompress Enigma-compressed mappings to RAM buffer
                copyTilemap v_ram_start,vram_bg+$510,24,8  ; transfer decompressed patterns to VRAM (BG plane, light scanning effect)
                copyTilemap v_ram_start+24*8*2,vram_fg,40,28  ; transfer decompressed patterns to VRAM (FG plane, Sega logo cutout)

                if      Revision<>0
                tst.b   (v_megadrive).w                 ; is console Japanese?
                bmi.s   .loadpal                        ; if not, branch
                copyTilemap v_ram_start+$A40,vram_fg+$53A,3,2  ; hide "TM" with a white rectangle
.loadpal:
                endif

                moveq   #palid_SegaBG,d0                ; load Sega screen palette
                bsr.w   PalLoad                         ; ...directly to active palette (not fade-in buffer)
                move.w  #-$A,(v_pcyc_num).w             ; light scanning palette cycle effect start offset
                move.w  #0,(v_pcyc_time).w              ; clear palette fade-in counter
                move.w  #0,(v_pal_buffer+$12).w         ; clear some palcycle buffer (unused?)
                move.w  #0,(v_pal_buffer+$10).w         ; clear some palcycle buffer (unused?)
                enable_display                          ; enable screen output
; ---------------------------------------------------------------------------

Sega_WaitPal:                                       ; while light scanning effect is active
                move.b  #id_VBlank_Sega,(v_vblank_routine).w  ; set VBlank routine to $02
                bsr.w   WaitForVBlank                   ; wait for VBlank to finish
                bsr.w   PalCycle_Sega                   ; advance light scanning palette cycle effect
                bne.s   Sega_WaitPal                    ; loop until it's finished
; ---------------------------------------------------------------------------

; while "SEGA" sound is playing
                move.b  #sfx_Sega,d0                    ; set "SEGA" sound
                bsr.w   QueueSound2                     ; queue it
                move.b  #id_VBlank_SegaPCM,(v_vblank_routine).w  ; set VBlank routine to $14
                bsr.w   WaitForVBlank                   ; wait for VBlank to play the sound (CPU is frozen here until sound finished playing)
; ---------------------------------------------------------------------------

; after sound has finished playing
                move.w  #30,(v_generictimer).w          ; wait 30 frames before automatic fade-out

Sega_WaitEnd:
                move.b  #id_VBlank_Sega,(v_vblank_routine).w  ; set VBlank routine to $02
                bsr.w   WaitForVBlank                   ; wait for VBlank to finish
                tst.w   (v_generictimer).w              ; has post-chant timer expired?
                beq.s   Sega_GotoTitle                  ; if yes, go to title screen
                andi.b  #btnStart,(v_jpadpress1).w      ; is Start button pressed?
                beq.s   Sega_WaitEnd                    ; if not, loop post-chant routine
; ---------------------------------------------------------------------------

Sega_GotoTitle:                                       ; transition to title screen
                move.b  #id_Title,(v_gamemode).w        ; go to title screen
                rts                                     ; return to MainGameLoop
; End of function GM_Sega

; ===========================================================================
; ---------------------------------------------------------------------------
; Title screen
; ---------------------------------------------------------------------------

; TitleScreen:
