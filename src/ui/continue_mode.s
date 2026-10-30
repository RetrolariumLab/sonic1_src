GM_Continue:
                bsr.w   PaletteFadeOut                  ; fade-out palette from previous game mode

                disable_ints                            ; disable interrupts
                disable_display                         ; disable screen output
                lea     (vdp_control_port).l,a6         ; load VDP control port
                move.w  #vreg_mode1|%000100,(a6)        ; use 8-colour mode
                move.w  #vreg_bgcolor|0<<4|0,(a6)       ; background colour
                bsr.w   ClearScreen                     ; wipe screen

                clearRAM v_objspace                     ; clear object RAM

                locVRAM ArtTile_Title_Card*tile_size    ; set VRAM location for title card patterns
                lea     (Nem_TitleCard).l,a0            ; load title card patterns
                bsr.w   NemDec                          ; decompress Nemesis-compressed patterns directly to VRAM

                locVRAM ArtTile_Continue_Sonic*tile_size  ; set VRAM location for Sonic on the continue screen
                lea     (Nem_ContSonic).l,a0            ; load Sonic patterns
                bsr.w   NemDec                          ; decompress Nemesis-compressed patterns directly to VRAM

                locVRAM ArtTile_Mini_Sonic*tile_size    ; set VRAM location for the mini Sonic icons
                lea     (Nem_MiniSonic).l,a0            ; load mini Sonic icons
                bsr.w   NemDec                          ; decompress Nemesis-compressed patterns directly to VRAM

                moveq   #10,d1                          ; draw continue screen countdown to start with digits 10
                jsr     (ContScrCounter).l              ; initialize countdown

                moveq   #palid_Continue,d0              ; load continue screen palette
                bsr.w   PalLoad_Fade                    ; ...into fade-in buffer
                move.b  #bgm_Continue,d0                ; play continue screen music
                bsr.w   QueueSound1                     ; play it

                move.w  #(11*60)-1,(v_generictimer).w   ; show continue screen for 11 seconds in total

                clr.l   (v_screenposx).w                ; clear X-camera position
                move.l  #$1000000,(v_screenposy).w      ; set Y-camera position to $100

                move.b  #id_ContSonic,(v_player).w      ; load continue screen Sonic object
                move.b  #id_ContScrItem,(v_continuetext).w  ; load continue screen objects (text and misc elements)
                move.b  #id_ContScrItem,(v_continuelight).w  ; load floor light object Sonic is laying on
                move.b  #3,(v_continuelight+obPriority).w  ; set priority to be behind Sonic
                move.b  #4,(v_continuelight+obFrame).w  ; set correct frame for the light
                move.b  #id_ContScrItem,(v_continueicon).w  ; load continue icons object
                move.b  #4,(v_continueicon+obRoutine).w  ; set to continue icons routine

                jsr     (ExecuteObjects).l              ; initialize objects
                jsr     (BuildSprites).l                ; build sprites
; ---------------------------------------------------------------------------

; fade-in palette and enter main loop
                enable_display                          ; enable screen output
                bsr.w   PaletteFadeIn                   ; fade-in palette

; ---------------------------------------------------------------------------
; Continue screen main loop
; ---------------------------------------------------------------------------

Cont_MainLoop:
                move.b  #id_VBlank_Continue,(v_vblank_routine).w  ; set VBlank routine to $16
                bsr.w   WaitForVBlank                   ; wait until VBlank has finished
                cmpi.b  #6,(v_player+obRoutine).w       ; has continue screen Sonic object signaled that we want to continue?
                bhs.s   Cont_NoCountdown                ; if yes, stop updating countdown timer

                disable_ints                            ; disable interrupts
                move.w  (v_generictimer).w,d1           ; get remaining time for countdown (in frames)
                divu.w  #60,d1                          ; divide by 60 to get remaining time in seconds
                andi.l  #$F,d1                          ; mask off remainder and anything except the end digit
                jsr     (ContScrCounter).l              ; update countdown digits
                enable_ints                             ; enable interrupts again
; loc_4DF2:
Cont_NoCountdown:
                jsr     (ExecuteObjects).l              ; execute continue screen objects
                jsr     (BuildSprites).l                ; build sprites

                cmpi.w  #320+64,(v_player+obX).w        ; has Sonic run off screen after using a continue?
                bhs.s   Cont_GotoLevel                  ; if yes, return to level and continue game
                cmpi.b  #6,(v_player+obRoutine).w       ; has continue screen Sonic object signaled that we want to continue?
                bhs.s   Cont_MainLoop                   ; if yes, Sonic is still running off-screen, loop until he is gone
                tst.w   (v_generictimer).w              ; has countdown run out?
                bne.w   Cont_MainLoop                   ; if not, loop game mode

; Continue wasn't used. Game Over
                move.b  #id_Sega,(v_gamemode).w         ; go to Sega screen
                rts                                     ; return to MainGameLoop
; ===========================================================================

Cont_GotoLevel:
                move.b  #id_Level,(v_gamemode).w        ; set screen mode to $0C (level)
                move.b  #3,(v_lives).w                  ; set lives to 3
                moveq   #0,d0                           ; clear d0
                move.w  d0,(v_rings).w                  ; clear rings
                move.l  d0,(v_time).w                   ; clear time
                move.l  d0,(v_score).w                  ; clear score
                move.b  d0,(v_lastlamp).w               ; clear lamppost count
                subq.b  #1,(v_continues).w              ; subtract 1 from continues
                rts                                     ; return to MainGameLoop
; End of function GM_Continue

; ===========================================================================

; >>> Objects for the continue screen
                include "src/ui/objects/continue_screen_elements_and_sonic.s"

; ===========================================================================
; ---------------------------------------------------------------------------
; Ending sequence in Green Hill Zone. This is essentially a stripped-down
; copy-paste of regular levels with lots of hardcoding
; ---------------------------------------------------------------------------

; EndingSequence:
