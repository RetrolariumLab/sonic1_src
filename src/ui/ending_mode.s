GM_Ending:
; fading out from previous game mode
                move.b  #bgm_Stop,d0                    ; set stop music command
                bsr.w   QueueSound2                     ; stop music
                bsr.w   PaletteFadeOut                  ; fade-out previous game mode
; ---------------------------------------------------------------------------

; screen setup and loading patterns
                clearRAM v_objspace                     ; clear object RAM
                clearRAM v_misc_variables               ; clear various miscellaneous RAM
                clearRAM v_levelvariables               ; clear level variables RAM (camera position, etc.)
                clearRAM v_timingandscreenvariables     ; clear various timing and screen RAM (for animated tiles, etc.)

                disable_ints                            ; disable interrupts
                disable_display                         ; disable screen output
                bsr.w   ClearScreen                     ; wipe the screen
                lea     (vdp_control_port).l,a6         ; load VDP control port
                move.w  #vreg_mode3|%0011,(a6)          ; line scroll mode (per-row horizontally, full-screen vertically)
                move.w  #vreg_fgvram|(vram_fg>>10),(a6)  ; set foreground nametable address
                move.w  #vreg_bgvram|(vram_bg>>13),(a6)  ; set background nametable address
                move.w  #vreg_spritevram|(vram_sprites>>9),(a6)  ; set sprite table address
                move.w  #vreg_planesize|%000001,(a6)    ; 64-cell hscroll size
                move.w  #vreg_mode1|%000100,(a6)        ; use 8-colour mode
                move.w  #vreg_bgcolor|2<<4|0,(a6)       ; set background colour (line 3; colour 0)
                move.w  #vreg_hintrate|223,(v_hblank_hreg).w  ; set palette change position (for water)
                move.w  (v_hblank_hreg).w,(a6)          ; write to VDP
                move.w  #30,(v_air).w                   ; replenish air

                move.w  #id_EndZ_good,(v_zone_act).w    ; set to good ending by default (level number 600, extra flowers)
                cmpi.b  #ss_emeralds_num,(v_emeralds).w  ; do you have all 6 emeralds?
                beq.s   End_LoadData                    ; if yes, use good ending
                move.w  #id_EndZ_bad,(v_zone_act).w     ; otherwise, set to bad ending (level number 601, no extra flowers)

End_LoadData:
                moveq   #plcid_Ending,d0                ; load ending sequence patterns (GHZ art, animals, etc.)
                bsr.w   QuickPLC                        ; execute PLCs immediately (no queue)
                jsr     (Hud_Base).l                    ; load basic HUD graphics (only in levels, not in the ending demos)
                bsr.w   LevelSizeLoad                   ; load level size and set default level boundaries
                bsr.w   DeformLayers                    ; initialize background deformation
                bset    #2,(v_fg_scroll_flags).w        ; draw an extra column at the left side of the screen during level start
                bsr.w   LevelDataLoad                   ; load block mappings and palettes
                bsr.w   LoadTilesFromStart              ; fully draw the foreground and background once before fade-in
                move.l  #Col_GHZ,(v_collindex).w        ; load collision index (hardcoded to GHZ instead of using ColIndexLoad)
                enable_ints                             ; enable interrupts

                lea     (Kos_EndFlowers).l,a0           ; load extra flower patterns
                lea     (v_256x256_def+$4A*chunk_size).w,a1  ; set RAM address to be used as decompression buffer (this overwrites unused chunk RAM)
                bsr.w   KosDec                          ; decompress Kosinski-compressed chunks mappings to buffer

                moveq   #palid_Sonic,d0                 ; load Sonic's palette
                bsr.w   PalLoad_Fade                    ; ...to fade-in buffer
                move.w  #bgm_Ending,d0                  ; play ending sequence music
                bsr.w   QueueSound1                     ; play it

                btst    #bitA,(v_jpadhold1).w           ; was button A held while entering ending sequence?
                beq.s   End_LoadSonic                   ; if not, branch
                move.b  #1,(f_debugmode).w              ; enable debug mode

End_LoadSonic:
                move.b  #id_SonicPlayer,(v_player).w    ; load Sonic object
                bset    #0,(v_player+obStatus).w        ; make Sonic face left
                move.b  #1,(f_lockctrl).w               ; lock controls to keep simulating D-Pad
                move.w  #(btnL<<8),(v_jpadhold2).w      ; simulate holding down the left D-Pad button to move Sonic (and clear v_jpadpress2)
                move.w  #-$800,(v_player+obInertia).w   ; set Sonic's initial speed (speed cap immediately limits this to -$600)

                move.b  #id_HUD,(v_hud).w               ; load HUD object
                jsr     (ObjPosLoad).l                  ; run the object manager to load level objects
                jsr     (ExecuteObjects).l              ; execute all objects in object RAM
                jsr     (BuildSprites).l                ; build sprite table

                moveq   #0,d0                           ; set d0 to 0
                move.w  d0,(v_rings).w                  ; clear rings
                move.l  d0,(v_time).w                   ; clear time
                move.b  d0,(v_lifecount).w              ; clear extra lives flags when getting 100/200 rings
                move.b  d0,(v_shield).w                 ; clear shield
                move.b  d0,(v_invinc).w                 ; clear invincibility
                move.b  d0,(v_shoes).w                  ; clear speed shoes
                move.b  d0,(v_unused1).w                ; clear unused flag (goggles?)
                move.w  d0,(v_debuguse).w               ; exit debug mode if necessary
                move.w  d0,(f_restart).w                ; clear level restart flag
                move.w  d0,(v_framecount).w             ; reset frames since level start to 0
                bsr.w   OscillateNumInit                ; initialize oscillation values
                move.b  #1,(f_scorecount).w             ; update score counter
                move.b  #1,(f_ringcount).w              ; update rings counter
                move.b  #0,(f_timecount).w              ; stop time counter for the ending sequence

                move.w  #1800,(v_generictimer).w        ; set generic timer to 30 seconds (unused in ending sequence)
                move.b  #id_VBlank_Ending,(v_vblank_routine).w  ; set VBlank routine to $18
                bsr.w   WaitForVBlank                   ; wait until VBlank has finished
; ---------------------------------------------------------------------------

; fade-in palette and enter main loop
                enable_display                          ; enable screen output
                move.w  #$003F,(v_pfade_start).w        ; set palette fade-in position and size (redundant)
                bsr.w   PaletteFadeIn                   ; fade-in palette

; ---------------------------------------------------------------------------
; Ending sequence main loop
; ---------------------------------------------------------------------------

End_MainLoop:
                bsr.w   PauseGame                       ; allow pausing during the ending sequence
                move.b  #id_VBlank_Ending,(v_vblank_routine).w  ; set VBlank routine to $18
                bsr.w   WaitForVBlank                   ; wait until VBlank has finished
                addq.w  #1,(v_framecount).w             ; add 1 to level timer

                bsr.w   End_MoveSonic                   ; control simulated button inputs for Sonic during the cutscene

                jsr     (ExecuteObjects).l              ; execute all objects in object RAM
                bsr.w   DeformLayers                    ; scroll planes and do background deformation
                jsr     (BuildSprites).l                ; build sprite table
                jsr     (ObjPosLoad).l                  ; run the object manager to load level objects
                bsr.w   PaletteCycle                    ; run palette cycles
                bsr.w   OscillateNumDo                  ; advance oscillation values
                bsr.w   SynchroAnimate                  ; advance animation timers

                cmpi.b  #id_Ending,(v_gamemode).w       ; is game mode still set to ending sequence?
                beq.s   End_ChkEmerald                  ; if yes, branch

End_GoToCredits:
                move.b  #id_Credits,(v_gamemode).w      ; change game mode to credits
                move.b  #bgm_Credits,d0                 ; play credits music
                bsr.w   QueueSound2                     ; play it
                move.w  #0,(v_creditsnum).w             ; set credits page number to 0 ("Sonic Team Staff")
                rts                                     ; return to MainGameLoop
; ===========================================================================

End_ChkEmerald:
                tst.w   (f_restart).w                   ; is level restart flag set? (set while emeralds are spinning in the good ending)
                beq.w   End_MainLoop                    ; if not, loop ending sequence game mode normally
; ---------------------------------------------------------------------------

; prepare slow white-in as the emeralds keep spinning in good ending
                clr.w   (f_restart).w                   ; clear level restart flag
                move.w  #$003F,(v_pfade_start).w        ; prepare fade position and size
                clr.w   (v_palchgspeed).w               ; trigger the first brightening immediately
; ---------------------------------------------------------------------------

End_AllEmlds:                                       ; during the slow white-in
                bsr.w   PauseGame                       ; still allow pausing the game
                move.b  #id_VBlank_Ending,(v_vblank_routine).w  ; set VBlank routine to $18
                bsr.w   WaitForVBlank                   ; wait until VBlank has finished
                addq.w  #1,(v_framecount).w             ; add 1 to level timer

                bsr.w   End_MoveSonic                   ; control simulated button inputs for Sonic (redundant at this point)

                jsr     (ExecuteObjects).l              ; continue executing objects during white-in
                bsr.w   DeformLayers                    ; continue upgrading background deformation during white-in
                jsr     (BuildSprites).l                ; continue building sprites during white-in
                jsr     (ObjPosLoad).l                  ; continue running object manager during white-in
                bsr.w   OscillateNumDo                  ; continue advancing oscillation values during white-in
                bsr.w   SynchroAnimate                  ; continue advancing animation timers during white-in

                subq.w  #1,(v_palchgspeed).w            ; decrement palette white-in delay
                bpl.s   End_SlowFade                    ; if time remains, branch
                move.w  #2,(v_palchgspeed).w            ; reset palette white-in delay
                bsr.w   WhiteOut_ToWhite                ; brighten palette further

End_SlowFade:
                tst.w   (f_restart).w                   ; has flag been set signaling that the emeralds have disappeared?
                beq.w   End_AllEmlds                    ; if not, loop
; ---------------------------------------------------------------------------

; screen is fully white and emeralds are gone, update level layout with extra flowers and fade back in
                clr.w   (f_restart).w                   ; clear level restart flag
                move.w  #$2E2F,(v_lvllayout_fg+layout_row).w  ; swap chunks in level layout to the variants with flowers (chunks $2E / $2F) (row 1 / column 0)

                lea     (vdp_control_port).l,a5         ; set VDP control port
                lea     (vdp_data_port).l,a6            ; set VDP data port
                lea     (v_screenposx).w,a3             ; get current foreground X position
                lea     (v_lvllayout_fg).w,a4           ; get location in level layout RAM where foreground is stored
                move.w  #$4000,d2                       ; set VRAM write command to vram_fg nametable start address
                bsr.w   DrawChunks                      ; update drawn chunks to show the new flowers

                moveq   #palid_Ending,d0                ; reload ending palette
                bsr.w   PalLoad_Fade                    ; ...to fade-in buffer
                bsr.w   PaletteWhiteIn                  ; fade-in from white

                bra.w   End_MainLoop                    ; return to main ending sequence loop for the rest of the scene
; End of function GM_Ending

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine controlling Sonic on the ending sequence
;
; Many aspects of the game use the concept of a state machine
; If you are interested and want to learn more, these are Mealy and Moore machines
; which have plenty of resources to teach you! This subroutine is a Moore machine
; Once you understand these concepts, Sonic 1's game logic will make a lot more sense to you!
; ---------------------------------------------------------------------------

End_MoveSonic:
                move.b  (v_sonicend).w,d0               ; get ending cutscene routine number
                bne.s   End_MoveSon2                    ; if it's non-zero, branch to second script

                cmpi.w  #(320/2)-16,(v_player+obX).w    ; has Sonic passed $90 on the X-axis (from the right)?
                bhs.s   End_MoveSonExit                 ; if not, branch

                addq.b  #2,(v_sonicend).w               ; advance ending cutscene routine number
                move.b  #1,(f_lockctrl).w               ; lock player's controls (redundant, already locked)
                move.w  #(btnR<<8),(v_jpadhold2).w      ; simulate holding down the right D-Pad button to trigger skidding animation
                rts                                     ; return
; ===========================================================================

End_MoveSon2:
                subq.b  #2,d0                           ; subtract 2 from cutscene routine number
                bne.s   End_MoveSon3                    ; if it's still non-zero, branch to third script

                cmpi.w  #320/2,(v_player+obX).w         ; has Sonic passed $A0 on the X-axis (from the left)?
                blo.s   End_MoveSonExit                 ; if not, branch

                addq.b  #2,(v_sonicend).w               ; advance ending cutscene routine number
                moveq   #0,d0                           ; clear d0
                move.b  d0,(f_lockctrl).w               ; unlock controls (no effect, see below)
                move.w  d0,(v_jpadhold2).w              ; clear simulated button inputs to stop Sonic moving
                move.w  d0,(v_player+obInertia).w       ; clear ground speed to make Sonic stop immediately
                move.b  #$81,(f_playerctrl).w           ; set control ignore and disabled object interaction flags

                move.b  #fr_Wait2,(v_player+obFrame).w  ; force Sonic to a specific waiting frame
                move.w  #(id_Wait<<8)+id_Wait,(v_player+obAnim).w  ; use "standing" animation and prevent it from getting immediately restarted
                move.b  #3,(v_player+obTimeFrame).w     ; set a bit of an animation interval so Sonic keeps looking when he gets replaced on the next frame
                rts                                     ; return
; ===========================================================================

End_MoveSon3:
                subq.b  #2,d0                           ; subtract 2 from cutscene routine number
                bne.s   End_MoveSonExit                 ; if it's still non-zero, the below code has already run, branch to do nothing anymore

                addq.b  #2,(v_sonicend).w               ; advance ending cutscene routine number
                move.w  #320/2,(v_player+obX).w         ; force Sonic to the middle of the screen
                move.b  #id_EndSonic,(v_player).w       ; replace real Sonic object with a fake ending sequence Sonic object
                clr.w   (v_player+obRoutine).w          ; reset routine counter to initialize fake ending Sonic

End_MoveSonExit:
                rts                                     ; return
; End of function End_MoveSonic

; ===========================================================================

; >>> Objects on the ending sequence
                include "src/ui/objects/ending_sequence_sonic_emeralds_logo.s"

; ===========================================================================
; ---------------------------------------------------------------------------
; Credits ending sequence. This game mode works in tandem with the regular
; demo game mode, with both redirecting to here after their respective timer
; has expired. The variable v_creditsnum for the current page is deliberately
; located near the end of RAM so it doesn't get cleared during mode change
; ---------------------------------------------------------------------------

; CreditsScreen:
