GM_Special:                                       ; white fade-out from previous game mode
                move.w  #sfx_EnterSS,d0                 ; set special stage entry sound
                bsr.w   QueueSound2                     ; play it
                bsr.w   PaletteWhiteOut                 ; fade-out to white
; ---------------------------------------------------------------------------

; load special stage patterns
                disable_ints                            ; disable interrupts
                lea     (vdp_control_port).l,a6         ; load VDP control port
                move.w  #vreg_mode3|%0011,(a6)          ; line scroll mode (per-row horizontally, full-screen vertically)
                move.w  #vreg_mode1|%000100,(a6)        ; use 8-colour mode
                move.w  #vreg_hintrate|175,(v_hblank_hreg).w  ; set HBlank counter to scanline 175 (even though horizontal interrupts aren't used here...)
                move.w  #$9011,(a6)                     ; 128-cell hscroll size
                disable_display                         ; disable screen output
                bsr.w   ClearScreen                     ; wipe screen
                enable_ints                             ; enable interrupts

                fillVRAM 0, ArtTile_SS_Plane_1*tile_size+plane_size_64x32, ArtTile_SS_Plane_5*tile_size  ; clear nametables
                bsr.w   SS_BGLoad                       ; load background clouds/bubbles/birds/fish mappings
                moveq   #plcid_SpecialStage,d0          ; load special stage patterns
                bsr.w   QuickPLC                        ; execute PLCs immediately (no queue)

                clearRAM v_objspace                     ; clear object RAM space
                clearRAM v_levelvariables               ; clear various level variables
                clearRAM v_timingvariables              ; clear various timing variables
                clearRAM v_ngfx_buffer                  ; clear Nemesis decompression buffer

                clr.b   (f_wtr_state).w                 ; clear water state
                clr.w   (f_restart).w                   ; clear level restart flag
                moveq   #palid_Special,d0               ; load special stage palette
                bsr.w   PalLoad_Fade                    ; ...into the palette fade-in buffer
                jsr     (SS_Load).l                     ; load SS layout data (based on last stage entered and collected emeralds)

                move.l  #0,(v_screenposx).w             ; reset X-camera position
                move.l  #0,(v_screenposy).w             ; reset Y-camera position
                move.b  #id_SonicSpecial,(v_player).w   ; load special stage Sonic object
                bsr.w   PalCycle_SS                     ; initialize palette cycle and background for fade-in
                clr.w   (v_ssangle).w                   ; set stage angle to "upright"
                move.w  #ss_rotatespeed,(v_ssrotate).w  ; set initial stage rotation speed ($40, see object 09)
                move.w  #bgm_SS,d0                      ; play special stage BG music
                bsr.w   QueueSound1                     ; play it

                move.w  #0,(v_btnpushtime1).w           ; clear button push counters for demos
                lea     (DemoDataPtr).l,a1              ; load demo data
                moveq   #6,d0                           ; hardcoded to load the entry for the Special Stage demo
                lsl.w   #2,d0                           ; multiply by 4 for longword-based indexing
                movea.l (a1,d0.w),a1                    ; get demo pointer for current level
                move.b  1(a1),(v_btnpushtime2).w        ; load initial demo key press duration
                subq.b  #1,(v_btnpushtime2).w           ; subtract 1 from demo key pressduration

                clr.w   (v_rings).w                     ; clear rings
                clr.b   (v_lifecount).w                 ; clear extra lives flags when getting 100/200 rings

                move.w  #0,(v_debuguse).w               ; exit debug mode if necessary
                move.w  #1800,(v_generictimer).w        ; run regular demos for 30 seconds
                tst.b   (f_debugcheat).w                ; has debug cheat been entered?
                beq.s   SS_NoDebug                      ; if not, branch
                btst    #bitA,(v_jpadhold1).w           ; is A button held?
                beq.s   SS_NoDebug                      ; if not, branch
                move.b  #1,(f_debugmode).w              ; enable debug mode

SS_NoDebug:
                enable_display                          ; enable screen out-put
                bsr.w   PaletteWhiteIn                  ; fade-in from white

; ---------------------------------------------------------------------------
; Special Stage main loop
; ---------------------------------------------------------------------------

SS_MainLoop:
                bsr.w   PauseGame                       ; handle pausing the game when pressing start
                move.b  #id_VBlank_SpecialStage,(v_vblank_routine).w  ; set VBlank routine to $0A
                bsr.w   WaitForVBlank                   ; wait until VBlank has finished
                bsr.w   MoveSonicInDemo                 ; simulate controls in demos (immediately returns outside demos)
                move.w  (v_jpadhold1).w,(v_jpadhold2).w  ; copy controller 1 inputs to Sonic player object inputs

                jsr     (ExecuteObjects).l              ; execute Special Stage object
                jsr     (BuildSprites).l                ; build sprites
                jsr     (SS_ShowLayout).l               ; render Special Stage layout
                bsr.w   SS_BGAnimate                    ; animate Special Stage background

                tst.w   (f_demo).w                      ; is demo mode on?
                beq.s   SS_ChkEnd                       ; if not, branch
                tst.w   (v_generictimer).w              ; is there time left on the demo?
                beq.w   SS_ToSegaScreen                 ; if not, return to Sega screen

SS_ChkEnd:
                cmpi.b  #id_Special,(v_gamemode).w      ; is game mode still the Special Stage?
                beq.w   SS_MainLoop                     ; if yes, loop game mode
; ---------------------------------------------------------------------------

; Exiting Special Stage
                tst.w   (f_demo).w                      ; are we exiting from a demo?
                if      Revision=0
                bne.w   SS_ToSegaScreen                 ; if yes, return to Sega Screen
                else
; REV01 added a small convenience improvement by returning straight
; to the title screen when pressing start during the Special Stage demo,
; rather than always being forced back to the Sega screen
                bne.w   SS_ToNextScreen                 ; if yes, return to next game mode
                endif

                move.b  #id_Level,(v_gamemode).w        ; set screen mode to $0C (level)
                cmpi.w  #id_FZ+1,(v_zone_act).w         ; is level number higher than FZ (0502)?
                blo.s   SS_Finish                       ; if not, branch
                clr.w   (v_zone_act).w                  ; set to GHZ1 (possibly as a failsafe)

SS_Finish:
                move.w  #60,(v_generictimer).w          ; run fade-out for one second
                move.w  #$003F,(v_pfade_start).w        ; set palette fade-out position and size
                clr.w   (v_palchgspeed).w               ; do first palette brightening immediately

SS_FinLoop:
                move.b  #id_VBlank_Continue,(v_vblank_routine).w  ; set VBlank routine to $16 (uses the same one as the continue screen)
                bsr.w   WaitForVBlank                   ; wait until VBlank has finished
                bsr.w   MoveSonicInDemo                 ; continue updating demo controls during fade-out
                move.w  (v_jpadhold1).w,(v_jpadhold2).w  ; continue copying 1P inputs to Sonic object (even though controls are locked...)
                jsr     (ExecuteObjects).l              ; continue executing objects during fade-out
                jsr     (BuildSprites).l                ; continue building sprites during fade-out
                jsr     (SS_ShowLayout).l               ; continue rendering Special Stage layout
                bsr.w   SS_BGAnimate                    ; continue to animate background

                subq.w  #1,(v_palchgspeed).w            ; decrement palette fade-out delay
                bpl.s   SS_FinLoop_NoBrighten           ; if time remains, branch
                move.w  #2,(v_palchgspeed).w            ; reset palette fade-out delay
                bsr.w   WhiteOut_ToWhite                ; brighten palette further

; loc_47D4:
SS_FinLoop_NoBrighten:
                tst.w   (v_generictimer).w              ; has fade-out loop finished?
                bne.s   SS_FinLoop                      ; if not, loop
; ---------------------------------------------------------------------------

; Fade-out done, load Special Stage Results screen
                disable_ints                            ; disable interrupts
                lea     (vdp_control_port).l,a6         ; load VDP control port
                move.w  #vreg_fgvram|(vram_fg>>10),(a6)  ; set foreground nametable address
                move.w  #vreg_bgvram|(vram_bg>>13),(a6)  ; set background nametable address
                move.w  #vreg_planesize|%000001,(a6)    ; 64-cell hscroll size
                bsr.w   ClearScreen                     ; wipe screen

                locVRAM ArtTile_Title_Card*tile_size    ; set VRAM location for title card font
                lea     (Nem_TitleCard).l,a0            ; load title card patterns
                bsr.w   NemDec                          ; decompress Nemesis-compressed graphics directly to VRAM

                jsr     (Hud_Base).l                    ; load basic HUD graphics
                enable_ints                             ; enable interrupts

                moveq   #palid_SSResult,d0              ; load Special Stage results screen palette
                bsr.w   PalLoad                         ; ...directly to active palette
                moveq   #plcid_Main,d0                  ; load main patterns (rings, etc.)
                bsr.w   NewPLC                          ; add to new PLC queue
                moveq   #plcid_SSResult,d0              ; load Special Stage results screen patterns
                bsr.w   AddPLC                          ; add to PLC queue

                move.b  #1,(f_scorecount).w             ; update score counter
                move.b  #1,(f_endactbonus).w            ; update ring bonus counter
                move.w  (v_rings).w,d0                  ; get rings collected in Special Stage
                mulu.w  #10,d0                          ; award 100 bonus points per collected ring
                move.w  d0,(v_ringbonus).w              ; set rings bonus

                move.w  #bgm_GotThrough,d0              ; play end-of-level music
                jsr     (QueueSound2).l                 ; play it

                clearRAM v_objspace                     ; clear object RAM

                move.b  #id_SSResult,(v_ssrescard).w    ; load Special Stage Results screen object
; ---------------------------------------------------------------------------

SS_NormalExit:                                       ; Special Stage results screen loop
                bsr.w   PauseGame                       ; allow pausing during the results screen
                move.b  #id_VBlank_TitleCards,(v_vblank_routine).w  ; set VBlank routine to $0C
                bsr.w   WaitForVBlank                   ; wait until VBlank has finished
                jsr     (ExecuteObjects).l              ; execute SSR objects
                jsr     (BuildSprites).l                ; build sprites
                bsr.w   RunPLC                          ; load SSR patterns
                tst.w   (f_restart).w                   ; has the SSR object signaled that we can exit?
                beq.s   SS_NormalExit                   ; if not, loop results screen
                tst.l   (v_plc_buffer).w                ; is PLC buffer empty?
                bne.s   SS_NormalExit                   ; if not, loop (pointless here, SSR object has its own check)
; ---------------------------------------------------------------------------

; Exit Special Stage normally
                move.w  #sfx_EnterSS,d0                 ; play special stage exit sound
                bsr.w   QueueSound2                     ; play it
                bsr.w   PaletteWhiteOut                 ; fade-out to white
                rts                                     ; return to MainGameLoop
; ===========================================================================

SS_ToSegaScreen:
                move.b  #id_Sega,(v_gamemode).w         ; set game mode to Sega screen
                rts                                     ; return to MainGameLoop
; ===========================================================================

                if      Revision<>0
; SS_ToLevel: <-- old misnomer
SS_ToNextScreen:
                cmpi.b  #id_Level,(v_gamemode).w        ; was demo exited with the instruction to go to a level next?
                beq.s   SS_ToSegaScreen                 ; if yes, return to the Sega screen instead (if demo finished)
                rts                                     ; otherwise, go to new game mode (which is the title screen, if demo was aborted)
                endif
; ENd of function GM_Special

; ===========================================================================

; >>> Special Stage background drawing and palette cycle logic
                include "src/game/special_stage/special_stage_background_and_palette_cycle.s"

; ===========================================================================
; ---------------------------------------------------------------------------
; Continue screen
; ---------------------------------------------------------------------------

; ContinueScreen:
