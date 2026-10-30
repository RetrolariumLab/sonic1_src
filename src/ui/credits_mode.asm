GM_Credits:
; fading out from previous game mode (music gets already started before this)
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

                locVRAM ArtTile_Credits_Font*tile_size  ; set target VRAM location for credits font
                lea     (Nem_CreditText).l,a0           ; load credits font
                bsr.w   NemDec                          ; decompress Nemesis-compressed patterns directly to VRAM

                clearRAM v_palette_fading               ; set palette fade-in buffer to all-black
                moveq   #palid_Sonic,d0                 ; load Sonic's palette
                bsr.w   PalLoad_Fade                    ; ...into fade-in buffer

                move.b  #id_CreditsText,(v_credits).w   ; load credits text object
                jsr     (ExecuteObjects).l              ; execute objects to load credits text object
                jsr     (BuildSprites).l                ; build sprites for the credits text object

                bsr.w   EndingDemoLoad                  ; prepare loading the next ending demo

                moveq   #0,d0                           ; clear d0
                move.b  (v_zone).w,d0                   ; get zone ID for next credits demo
                lsl.w   #4,d0                           ; multiply by $10 (number of bytes per level header entry)
                lea     (LevelHeaders).l,a2             ; load level headers
                lea     (a2,d0.w),a2                    ; get relevant header for next credits demo
                moveq   #0,d0                           ; clear d0
                move.b  (a2),d0                         ; get first PLC entry
                beq.s   Cred_SkipObjGfx                 ; if it's null, branch (never the case)
                bsr.w   AddPLC                          ; load level patterns for next credits demo

Cred_SkipObjGfx:
                moveq   #plcid_Main2,d0                 ; load secondary standard patterns
                bsr.w   AddPLC                          ; (monitors, etc.)
; ---------------------------------------------------------------------------

; fade-in palette and enter wait loop
                move.w  #120,(v_generictimer).w         ; display a single credits page for 2 seconds
                bsr.w   PaletteFadeIn                   ; fade-in palette

; ---------------------------------------------------------------------------
; Credits page main loop (only shown for 2 seconds)
; ---------------------------------------------------------------------------

Cred_WaitLoop:                                       ; while a credits page is displayed and graphics are getting decompressed
                move.b  #id_VBlank_Title,(v_vblank_routine).w  ; set VBlank routine to $04 (uses the same one as the title screen)
                bsr.w   WaitForVBlank                   ; wait until VBlank has finished

                bsr.w   RunPLC                          ; decompress level graphics

                tst.w   (v_generictimer).w              ; have at least 2 seconds elapsed?
                bne.s   Cred_WaitLoop                   ; if not, loop
                tst.l   (v_plc_buffer).w                ; have 2 seconds elapsed but level gfx have not finished decompressing?
                bne.s   Cred_WaitLoop                   ; if yes, still loop until graphics are finished
; ---------------------------------------------------------------------------

; credits page has finished displaying, go to next game mode
                cmpi.w  #9,(v_creditsnum).w             ; are we past the final credits page?
                beq.w   TryAgainEnd                     ; if yes, go to Try Again/End screen instead
                rts                                     ; otherwise, return to MainGameLoop to enter Demo mode
; End of function GM_Credits

; ===========================================================================
; ---------------------------------------------------------------------------
; Ending sequence demo loading subroutine
; ---------------------------------------------------------------------------

EndingDemoLoad:
                move.w  (v_creditsnum).w,d0             ; get current credits page
                andi.w  #$F,d0                          ; limit to 16 possible entries (redundant)
                add.w   d0,d0                           ; double for word-based indexing
                move.w  EndDemo_Levels(pc,d0.w),d0      ; get relevant zone and act for the next credits demo
                move.w  d0,(v_zone_act).w               ; set level from level array

                addq.w  #1,(v_creditsnum).w             ; increase credits page number for next time
                cmpi.w  #9,(v_creditsnum).w             ; are we past the final credits page now?
                bhs.s   EndDemo_Exit                    ; if yes, don't load another demo

                move.w  #$8001,(f_demo).w               ; set demo mode to its credits/ending variant
                move.b  #id_Demo,(v_gamemode).w         ; set game mode to demo (activates once credits page has finished)

                move.b  #3,(v_lives).w                  ; set lives to 3
                moveq   #0,d0                           ; set d0 to 0
                move.w  d0,(v_rings).w                  ; clear rings
                move.l  d0,(v_time).w                   ; clear time
                move.l  d0,(v_score).w                  ; clear score
                move.b  d0,(v_lastlamp).w               ; clear lamppost counter

                cmpi.w  #4,(v_creditsnum).w             ; is specifically the 4th demo about to run? (SLZ demo)
                bne.s   EndDemo_Exit                    ; if not, branch
                lea     (EndDemo_LampVar).l,a1          ; load special lamppost variables for SLZ demo
                lea     (v_lastlamp).w,a2               ; write to lamppost buffer
                move.w  #(EndDemo_LampVar_End-EndDemo_LampVar)/4-1,d0  ; write for all entries
EndDemo_LampLoad:
                move.l  (a1)+,(a2)+                     ; copy lamppost variables for SLZ demo
                dbf     d0,EndDemo_LampLoad             ; loop until everything is loaded

EndDemo_Exit:
                rts                                     ; return
; End of function EndingDemoLoad

; ---------------------------------------------------------------------------
; Levels used in the end sequence demos
; ---------------------------------------------------------------------------

EndDemo_Levels:                                       ; previously in "misc/Demo Level Order - Ending.bin"
                dc.w    id_GHZ_act1
                dc.w    id_MZ_act2
                dc.w    id_SYZ_act3
                dc.w    id_LZ_act3
                dc.w    id_SLZ_act3
                dc.w    id_SBZ_act1
                dc.w    id_SBZ_act2
                dc.w    id_GHZ_act1
                even

; ---------------------------------------------------------------------------
; Lamppost variables in the Star Light Zone credits demo
; ---------------------------------------------------------------------------
EndDemo_LampVar:
                dc.b    1, 1                            ; number of the last lamppost
                dc.w    $A00, $62C                      ; x/y-axis position
                dc.w    13                              ; rings
                dc.l    0                               ; time
                dc.b    0, 0                            ; dynamic level event routine counter
                dc.w    $800                            ; level bottom boundary
                dc.w    $957, $5CC                      ; x/y axis screen position
                dc.w    $4AB, $3A6, 0, $28C, 0, 0       ; scroll info
                dc.w    $308                            ; water height
                dc.b    1, 1                            ; water routine and state
EndDemo_LampVar_End:
; ===========================================================================

; ===========================================================================
; ---------------------------------------------------------------------------
; "TRY AGAIN" screen (bad ending) and "END" screen (good ending). This is
; essentially a full game mode, although it's not called from the main
; game mode array, but rather directly from the credits
; ---------------------------------------------------------------------------

; TryAgainScreen:
