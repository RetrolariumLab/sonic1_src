TryAgainEnd:                                       ; fading out from previous game mode
                bsr.w   ClearPLC                        ; stop any potential in-progress PLC
                bsr.w   PaletteFadeOut                  ; fade-out previous game mode
; ---------------------------------------------------------------------------

; screen setup and loading patterns
                lea     (vdp_control_port).l,a6         ; load VDP control port
                move.w  #vreg_mode1|%000100,(a6)        ; use 8-colour mode
                move.w  #vreg_fgvram|(vram_fg>>10),(a6)  ; set foreground nametable address
                move.w  #vreg_bgvram|(vram_bg>>13),(a6)  ; set background nametable address
                move.w  #vreg_planesize|%000001,(a6)    ; 64-cell hscroll size
                move.w  #vreg_winypos|0,(a6)            ; window vertical position
                move.w  #vreg_mode3|%0011,(a6)          ; line scroll mode (per-row horizontally, full-screen vertically)
                move.w  #vreg_bgcolor|2<<4|0,(a6)       ; set background colour (line 3; colour 0)
                clr.b   (f_wtr_state).w                 ; clear water state
                bsr.w   ClearScreen                     ; wipe the screen

                clearRAM v_objspace                     ; clear object RAM

                moveq   #plcid_TryAgain,d0              ; load "TRY AGAIN" and "END" patterns
                bsr.w   QuickPLC                        ; execute PLCs immediately (no queue)

                clearRAM v_palette_fading               ; set palette fade-in buffer to all-black
                moveq   #palid_Ending,d0                ; load ending palette
                bsr.w   PalLoad_Fade                    ; ...to fade-in buffer
                clr.w   (v_palette_fading_line_3).w     ; ensure the backdrop color is black

                move.b  #id_EndEggman,(v_endeggman).w   ; load end Eggman object
                jsr     (ExecuteObjects).l              ; execute objects to load end objects
                jsr     (BuildSprites).l                ; build sprites for end objects
; ---------------------------------------------------------------------------

; fade-in palette and enter main loop
                move.w  #1800,(v_generictimer).w        ; automatically return to Sega screen after 30 seconds
                bsr.w   PaletteFadeIn                   ; fade-in palette

; ---------------------------------------------------------------------------
; "TRY AGAIN" and "END" screen main loop
; ---------------------------------------------------------------------------

TryAg_MainLoop:
                bsr.w   PauseGame                       ; allow to pause game (redundant, start exits the screen)
                move.b  #id_VBlank_Title,(v_vblank_routine).w  ; set VBlank routine to $04 (uses the same one as the title screen)
                bsr.w   WaitForVBlank                   ; wait until VBlank has finished

                jsr     (ExecuteObjects).l              ; update end objects
                jsr     (BuildSprites).l                ; build sprites for end objects

                andi.b  #btnStart,(v_jpadpress1).w      ; has Start button been pressed?
                bne.s   TryAg_Exit                      ; if yes, exit end screen
                tst.w   (v_generictimer).w              ; have 30 seconds elapsed?
                beq.s   TryAg_Exit                      ; if yes, exit end screen
                cmpi.b  #id_Credits,(v_gamemode).w      ; is game mode still set to show the end screen?
                beq.s   TryAg_MainLoop                  ; if yes, loop
; ---------------------------------------------------------------------------

TryAg_Exit:                                       ; exit end screen and restart the gam
                move.b  #id_Sega,(v_gamemode).w         ; set game mode to Sega screen
                rts                                     ; return to MainGameLoop
; End of function TryAgainEnd
; ===========================================================================

; >>> Objects on final screen
                include "src/ui/objects/try_again_end_eggman_end_emeralds.s"

; ===========================================================================
; ---------------------------------------------------------------------------
; Ending sequence demos
; ---------------------------------------------------------------------------

Demo_EndGHZ1:   include "src/game/demos/ending_ghz1.s"
Demo_EndMZ:   include "src/game/demos/ending_mz.s"
Demo_EndSYZ:   include "src/game/demos/ending_syz.s"
Demo_EndLZ:   include "src/game/demos/ending_lz.s"
Demo_EndSLZ:   include "src/game/demos/ending_slz.s"
Demo_EndSBZ1:   include "src/game/demos/ending_sbz1.s"
Demo_EndSBZ2:   include "src/game/demos/ending_sbz2.s"
Demo_EndGHZ2:   include "src/game/demos/ending_ghz2.s"

; ===========================================================================
; ---------------------------------------------------------------------------
; >> END OF MAIN GAME LOGIC - Everything below this point is file includes <<
; ---------------------------------------------------------------------------
; ===========================================================================

; Where possible, includes to _maps and _anim were appended to the _incObj
; file includes themselves. However, in some cases this wasn't possible,
; as the developers weren't very consistent with the placement, especially
; during the early stages of production. Those includes are still here

; ===========================================================================
; >>> Level rendering, loading, and updating
