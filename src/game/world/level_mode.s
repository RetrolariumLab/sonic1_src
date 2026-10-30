GM_Level:                                       ; fading out from previous game mode
                bset    #7,(v_gamemode).w               ; add $80 to screen mode (for pre level sequence)

                tst.w   (f_demo).w                      ; is an ending sequence demo running?
                bmi.s   Level_NoMusicFade               ; if yes, don't fade out music
                move.b  #bgm_Fade,d0                    ; queue music fade-out command
                bsr.w   QueueSound2                     ; fade out music

Level_NoMusicFade:
                bsr.w   ClearPLC                        ; clear any remaining PLC entries
                bsr.w   PaletteFadeOut                  ; fade out from the previous screen
; ---------------------------------------------------------------------------

; load title cards, queue PLCs, setup screen, play music
                tst.w   (f_demo).w                      ; is an ending sequence demo running?
                bmi.s   Level_ClrRam                    ; if yes, don't load title screen or main level patterns

                disable_ints                            ; disable interrupts
                locVRAM ArtTile_Title_Card*tile_size    ; set VRAM target location for title cards
                lea     (Nem_TitleCard).l,a0            ; load title card patterns
                bsr.w   NemDec                          ; decompress Nemesis-compressed patterns directly to VRAM
                enable_ints                             ; enable interrupts again

                moveq   #0,d0                           ; clear d0
                move.b  (v_zone).w,d0                   ; get current Zone ID
                lsl.w   #4,d0                           ; multiply by $10 (number of bytes per level header entry)
                lea     (LevelHeaders).l,a2             ; load level headers
                lea     (a2,d0.w),a2                    ; get relevant header for current level
                moveq   #0,d0                           ; clear d0
                move.b  (a2),d0                         ; get first PLC entry
                beq.s   Level_NoPLC                     ; if it's null, branch (never the case)
                bsr.w   AddPLC                          ; load level patterns for current Zone
; loc_37FC:
Level_NoPLC:
                moveq   #plcid_Main2,d0                 ; load secondary standard patterns (monitors, etc.)
                bsr.w   AddPLC                          ; (these can be overwritten by stuff like the sign post art)

Level_ClrRam:
                clearRAM v_objspace                     ; clear object RAM
                clearRAM v_misc_variables               ; clear various miscellaneous RAM
                clearRAM v_levelvariables               ; clear level variables RAM (camera position, etc.)
                clearRAM v_timingandscreenvariables     ; clear various timing and screen RAM (for animated tiles, etc.)

                disable_ints                            ; disable interrupts
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

                cmpi.b  #id_LZ,(v_zone).w               ; is level LZ?
                bne.s   Level_LoadPal                   ; if not, branch
                move.w  #vreg_mode1|%010100,(a6)        ; enable horizontal interrupts (HBlank)
                moveq   #0,d0                           ; clear d0
                move.b  (v_act).w,d0                    ; get current LZ act
                add.w   d0,d0                           ; double for word-based indexing
                lea     (WaterHeight).l,a1              ; load water height array
                move.w  (a1,d0.w),d0                    ; get water height entries for current LZ act
                move.w  d0,(v_waterpos1).w              ; set water height (actual)
                move.w  d0,(v_waterpos2).w              ; set water height (ignoring surface sway)
                move.w  d0,(v_waterpos3).w              ; set water height (target)
                clr.b   (v_wtr_routine).w               ; clear water routine counter
                clr.b   (f_wtr_state).w                 ; clear water state
                move.b  #1,(f_water).w                  ; enable water

Level_LoadPal:
                move.w  #30,(v_air).w                   ; set Sonic's air timer to 30 seconds
                enable_ints                             ; enable interrupts

                moveq   #palid_Sonic,d0                 ; load Sonic's palette
                bsr.w   PalLoad                         ; ...directly to active palette (for title cards)
                cmpi.b  #id_LZ,(v_zone).w               ; is level LZ?
                bne.s   Level_GetBgm                    ; if not, branch
                moveq   #palid_LZSonWater,d0            ; palette number $F (LZ)
                cmpi.b  #act4,(v_act).w                 ; check if on act 4 (for SBZ3/LZ4)?
                bne.s   Level_WaterPal                  ; if not, branch
                moveq   #palid_SBZ3SonWat,d0            ; palette number $10 (SBZ3)

Level_WaterPal:
                bsr.w   PalLoad_Fade_Water              ; load underwater palette
                tst.b   (v_lastlamp).w                  ; are we respawning from a checkpoint?
                beq.s   Level_GetBgm                    ; if not, branch
                move.b  (v_lamp_wtrstat).w,(f_wtr_state).w  ; restore water state from checkpoint

Level_GetBgm:
                tst.w   (f_demo).w                      ; is this a credits demo?
                bmi.s   Level_SkipTtlCard               ; if yes, don't load title cards or change music

                moveq   #0,d0                           ; clear d0
                move.b  (v_zone).w,d0                   ; get current Zone ID
                cmpi.w  #id_LZ_act4,(v_zone_act).w      ; is level SBZ3 (LZ4)?
                bne.s   Level_BgmNotLZ4                 ; if not, branch
                moveq   #5,d0                           ; use 5th music (SBZ)

Level_BgmNotLZ4:
                cmpi.w  #id_FZ,(v_zone_act).w           ; is level FZ?
                bne.s   Level_PlayBgm                   ; if not, branch
                moveq   #6,d0                           ; use 6th music (FZ)

Level_PlayBgm:
                lea     (MusicList).l,a1                ; load music playlist
                move.b  (a1,d0.w),d0                    ; get music ID for current level
                bsr.w   QueueSound1                     ; play music
                move.b  #id_TitleCard,(v_titlecard).w   ; load title card object
; ---------------------------------------------------------------------------

Level_TtlCardLoop:                                       ; move in title cards, stay on them until PLCs have finished
                move.b  #id_VBlank_TitleCards,(v_vblank_routine).w  ; set VBlank routine to $0C
                bsr.w   WaitForVBlank                   ; wait until VBlank has finished
                jsr     (ExecuteObjects).l              ; execute title cards object
                jsr     (BuildSprites).l                ; build sprites to show title cards
                bsr.w   RunPLC                          ; decompress level graphics
                move.w  (v_ttlcardact+obX).w,d0         ; get current position of the "ACT" element of the title cards
                cmp.w   (v_ttlcardact+card_mainX).w,d0  ; has "ACT" element reached its target position?
                bne.s   Level_TtlCardLoop               ; if not, loop until it has
                tst.l   (v_plc_buffer).w                ; have patterns been fully decompressed and loaded?
                bne.s   Level_TtlCardLoop               ; if not, loop until they have
; ---------------------------------------------------------------------------

; PLCs have finished, load/initialize remaining data

                jsr     (Hud_Base).l                    ; load basic HUD graphics (only in levels, not in the ending demos)

Level_SkipTtlCard:
                moveq   #palid_Sonic,d0                 ; load Sonic's palette to fade-in buffer
                bsr.w   PalLoad_Fade                    ; (doesn't actually do anything, the PalFadeIn_Alt call below skips the first palette line)
                bsr.w   LevelSizeLoad                   ; load level size and set default level boundaries
                bsr.w   DeformLayers                    ; initialize background deformation
                bset    #2,(v_fg_scroll_flags).w        ; draw an extra column at the left side of the screen during level start
                bsr.w   LevelDataLoad                   ; load block mappings and palettes
                bsr.w   LoadTilesFromStart              ; fully draw the foreground and background once before fade-in
                jsr     (ConvertCollisionArray).l       ; call a routine that immediately returns (this is a disabled development function)
                bsr.w   ColIndexLoad                    ; set collision index for current zone
                bsr.w   LZWaterFeatures                 ; initialize water features if zone is LZ

                move.b  #id_SonicPlayer,(v_player).w    ; load Sonic object

                tst.w   (f_demo).w                      ; is this a credits demo?
                bmi.s   Level_ChkDebug                  ; if yes, don't load HUD
                move.b  #id_HUD,(v_hud).w               ; load HUD object

Level_ChkDebug:
                tst.b   (f_debugcheat).w                ; has debug cheat been entered?
                beq.s   Level_ChkWater                  ; if not, branch
                btst    #bitA,(v_jpadhold1).w           ; is A button held?
                beq.s   Level_ChkWater                  ; if not, branch
                move.b  #1,(f_debugmode).w              ; enable debug mode

Level_ChkWater:
                move.w  #0,(v_jpadhold2).w              ; clear button input states for Sonic player object
                move.w  #0,(v_jpadhold1).w              ; clear actual button input states for controller 1

                cmpi.b  #id_LZ,(v_zone).w               ; is level LZ?
                bne.s   Level_LoadObj                   ; if not, branch
                move.b  #id_WaterSurface,(v_watersurface1).w  ; load water surface object A
                move.w  #$60,(v_watersurface1+obX).w    ; set base X-position for surface A
                move.b  #id_WaterSurface,(v_watersurface2).w  ; load water surface object B
                move.w  #$120,(v_watersurface2+obX).w   ; set base X-position for surface B

Level_LoadObj:
                jsr     (ObjPosLoad).l                  ; initialize object manager
                jsr     (ExecuteObjects).l              ; load objects that are already visible during fade-in
                jsr     (BuildSprites).l                ; build sprites for objects before fade-in

                moveq   #0,d0                           ; clear d0
                tst.b   (v_lastlamp).w                  ; are we starting from a lamppost?
                bne.s   Level_SkipClr                   ; if yes, branch
                move.w  d0,(v_rings).w                  ; clear rings
                move.l  d0,(v_time).w                   ; clear time
                move.b  d0,(v_lifecount).w              ; clear extra lives flags when getting 100/200 rings

Level_SkipClr:
                move.b  d0,(f_timeover).w               ; clear time over flag
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
                move.b  #1,(f_timecount).w              ; update time counter

                move.w  #0,(v_btnpushtime1).w           ; clear button push counters for demos
                lea     (DemoDataPtr).l,a1              ; load demo data
                moveq   #0,d0                           ; clear d0
                move.b  (v_zone).w,d0                   ; get current Zone ID
                lsl.w   #2,d0                           ; multiply by 4 for longword-based indexing
                movea.l (a1,d0.w),a1                    ; get demo pointer for current level
                tst.w   (f_demo).w                      ; are we in a regular (not-credits) demo?
                bpl.s   Level_Demo                      ; if yes, branch
                lea     (DemoEndDataPtr).l,a1           ; load ending demo data
                move.w  (v_creditsnum).w,d0             ; get current credits page
                subq.w  #1,d0                           ; subtract by 1
                lsl.w   #2,d0                           ; multiply by 4 for longword-based indexing
                movea.l (a1,d0.w),a1                    ; get demo pointer for current credits page

Level_Demo:
                move.b  1(a1),(v_btnpushtime2).w        ; load initial demo key press duration
                subq.b  #1,(v_btnpushtime2).w           ; subtract 1 from demo key pressduration
                move.w  #1800,(v_generictimer).w        ; run regular demos for 30 seconds
                tst.w   (f_demo).w                      ; is this a regular (not-credits) demo?
                bpl.s   Level_ChkWaterPal               ; if not, branch
                move.w  #540,(v_generictimer).w         ; run credits demos for 9 seconds each
                cmpi.w  #4,(v_creditsnum).w             ; is this credits demo 4? (Labyrinth)
                bne.s   Level_ChkWaterPal               ; if not, branch
                move.w  #510,(v_generictimer).w         ; run this specific demo for 0.5 seconds less

Level_ChkWaterPal:
                cmpi.b  #id_LZ,(v_zone).w               ; is level LZ/SBZ3?
                bne.s   Level_Delay                     ; if not, branch
                moveq   #palid_LZWater,d0               ; palette $B (LZ underwater)
                cmpi.b  #act4,(v_act).w                 ; check if on act 4 (for SBZ3/LZ4)
                bne.s   Level_WtrNotSbz                 ; if not, branch
                moveq   #palid_SBZ3Water,d0             ; palette $D (SBZ3 underwater)

Level_WtrNotSbz:
                bsr.w   PalLoad_Water                   ; load underwater palette to active palette

Level_Delay:
                move.w  #4-1,d1                         ; run 4 extra frames of VBlank to do palette transfers

Level_DelayLoop:
                move.b  #id_VBlank_Levels,(v_vblank_routine).w  ; set VBlank routine to $08
                bsr.w   WaitForVBlank                   ; wait until VBlank has finished
                dbf     d1,Level_DelayLoop              ; repeat for 4 frames in total

                move.w  #$202F,(v_pfade_start).w        ; set to fade in 2nd, 3rd & 4th palette lines
                bsr.w   PalFadeIn_Alt                   ; fade-in main palette
; ---------------------------------------------------------------------------

; level has faded in, make title cards move and enter main loop
                tst.w   (f_demo).w                      ; is an ending sequence demo running?
                bmi.s   Level_ClrCardArt                ; if yes, load explosion and animal graphics now
                addq.b  #2,(v_ttlcardname+obRoutine).w  ; make title card move (name)
                addq.b  #4,(v_ttlcardzone+obRoutine).w  ; make title card move ("ZONE")
                addq.b  #4,(v_ttlcardact+obRoutine).w   ; make title card move ("ACT")
                addq.b  #4,(v_ttlcardoval+obRoutine).w  ; make title card move (blue oval)
                bra.s   Level_StartGame
; ===========================================================================

Level_ClrCardArt:
; This portion is only for the credits demos to loads explosions
; and animal graphics right now, as normally they get loaded by
; the title cards (which aren't loaded for credits demos)
                moveq   #plcid_Explode,d0               ; load explosion graphics
                jsr     (AddPLC).l                      ; queue PLC
                moveq   #0,d0                           ; clear d0
                move.b  (v_zone).w,d0                   ; get current Zone ID
                addi.w  #plcid_GHZAnimals,d0            ; add offset to animal patterns (+$15)
                jsr     (AddPLC).l                      ; load animal patterns

Level_StartGame:
                bclr    #7,(v_gamemode).w               ; subtract $80 from mode to end pre-level stuff
; enter main loop

; ---------------------------------------------------------------------------
; Main level loop (when all title card and loading sequences are finished)
; ---------------------------------------------------------------------------

Level_MainLoop:
                bsr.w   PauseGame                       ; handle pausing the game when pressing start
                move.b  #id_VBlank_Levels,(v_vblank_routine).w  ; set VBlank routine to $08
                bsr.w   WaitForVBlank                   ; wait until VBlank has finished
                addq.w  #1,(v_framecount).w             ; add 1 to level timer

                bsr.w   MoveSonicInDemo                 ; simulate controls in demos (immediately returns outside demos)
                bsr.w   LZWaterFeatures                 ; apply water features if in Labyrinth Zone
                jsr     (ExecuteObjects).l              ; execute all objects in object RAM

                if      Revision<>0
; For REV01, this code has been relocated from below to avoid brief visual glitches
; as a result of the zone ID changing. This, however, had the side effect of demos
; restarting if Sonic dies, rather than immediately going to the next game mode
; In the case of the ending demos, it could result in the credits getting aborted
                tst.w   (f_restart).w                   ; is the level set to restart?
                bne.w   GM_Level                        ; if yes, restart level immediately
                endif

                tst.w   (v_debuguse).w                  ; is debug mode being used?
                bne.s   Level_DoScroll                  ; if yes, continue plane scrolling even when dying
                cmpi.b  #6,(v_player+obRoutine).w       ; has Sonic just died?
                bhs.s   Level_SkipScroll                ; if yes, don't do plane scrolling

Level_DoScroll:
                bsr.w   DeformLayers                    ; scroll planes and do background deformation

Level_SkipScroll:
                jsr     (BuildSprites).l                ; build sprite table
                jsr     (ObjPosLoad).l                  ; run the object manager to load level objects
                bsr.w   PaletteCycle                    ; run palette cycles
                bsr.w   RunPLC                          ; run PLC, if any
                bsr.w   OscillateNumDo                  ; advance oscillation values
                bsr.w   SynchroAnimate                  ; advance animation timers
                bsr.w   SignpostArtLoad                 ; check if sign post art needs to be loaded and lock left boundary

Level_CheckRestart:
                cmpi.b  #id_Demo,(v_gamemode).w         ; are we in a demo?
                beq.s   Level_ChkDemo                   ; if yes, branch
                if      Revision=0
                tst.w   (f_restart).w                   ; is the level set to restart?
                bne.w   GM_Level                        ; if yes, restart leve
                endif
                cmpi.b  #id_Level,(v_gamemode).w        ; is game mode still set to level?
                beq.w   Level_MainLoop                  ; if yes, loop level game mode
                rts                                     ; if game mode changed, return to MainGameLoop
; ===========================================================================

Level_ChkDemo:
                tst.w   (f_restart).w                   ; is level set to restart?
                bne.s   Level_EndDemo                   ; if yes, branch
                tst.w   (v_generictimer).w              ; is there time left on the demo?
                beq.s   Level_EndDemo                   ; if not, branch
                cmpi.b  #id_Demo,(v_gamemode).w         ; is game mode still demo?
                beq.w   Level_MainLoop                  ; if yes, loop level game mode
                move.b  #id_Sega,(v_gamemode).w         ; otherwise, return to Sega screen
                rts                                     ; return to MainGameLoop
; ===========================================================================

Level_EndDemo:
                cmpi.b  #id_Demo,(v_gamemode).w         ; is game mode still demo?
                bne.s   Level_FadeDemo                  ; if not, slowly fade-out demo
                move.b  #id_Sega,(v_gamemode).w         ; return to Sega screen
                tst.w   (f_demo).w                      ; is demo mode on & not ending sequence?
                bpl.s   Level_FadeDemo                  ; if yes, branch
                move.b  #id_Credits,(v_gamemode).w      ; return to credits game mode (next credits page)

Level_FadeDemo:
                move.w  #60,(v_generictimer).w          ; run fade-out for one second
                move.w  #$003F,(v_pfade_start).w        ; set palette fade-out position and size
                clr.w   (v_palchgspeed).w               ; do first palette dimming immediately

Level_FDLoop:
                move.b  #id_VBlank_Levels,(v_vblank_routine).w  ; set VBlank routine to $08
                bsr.w   WaitForVBlank                   ; wait until VBlank has finished
                bsr.w   MoveSonicInDemo                 ; continue updating demo controls during fade-out
                jsr     (ExecuteObjects).l              ; continue executing objects during fade-out
                jsr     (BuildSprites).l                ; continue building sprites during fade-out
                jsr     (ObjPosLoad).l                  ; continue running object manager during fade-out

                subq.w  #1,(v_palchgspeed).w            ; decrement palette fade-out delay
                bpl.s   Level_FDLoop_NoDim              ; if time remains, branch
                move.w  #2,(v_palchgspeed).w            ; reset palette fade-out delay
                bsr.w   FadeOut_ToBlack                 ; dim palette further

; loc_3BC8:
Level_FDLoop_NoDim:
                tst.w   (v_generictimer).w              ; has fade-out loop finished?
                bne.s   Level_FDLoop                    ; if not, loop
                rts                                     ; return to MainGameLoop
; End of function GM_Level

; ===========================================================================
; >>> Misc level logic for specific circumstances
                include "src/game/world/lz_water_features.s"
                include "src/game/player/move_sonic_in_demo.s"

; ===========================================================================
; ---------------------------------------------------------------------------
; Collision index pointer loading subroutine
; ---------------------------------------------------------------------------
