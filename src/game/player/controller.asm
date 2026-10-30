; ===========================================================================
; ---------------------------------------------------------------------------
; Object 01 - Sonic the Hedgehog
; ---------------------------------------------------------------------------
son_maxspeed:   equ     $600                        ; Sonic's max speed
son_acceleration:   equ     $C                          ; Sonic's acceleration
son_deceleration:   equ     $80                         ; Sonic's deceleration
son_jumpspeed:   equ     $680                        ; Sonic's jump speed
; ---------------------------------------------------------------------------

; Obj01:
SonicPlayer:
                tst.w   (v_debuguse).w                  ; is debug mode being used?
                beq.s   Sonic_Normal                    ; if not, branch
                jmp     (DebugMode).l                   ; run debug mode instead of Sonic object
; ===========================================================================

; Obj01_Normal:
Sonic_Normal:
                moveq   #0,d0                           ; clear d0
                move.b  obRoutine(a0),d0                ; get current routine number
                move.w  Sonic_Index(pc,d0.w),d1         ; find appropriate entry in jump table
                jmp     Sonic_Index(pc,d1.w)            ; jump there
; ===========================================================================
; Obj01_Index:
Sonic_Index:   dc.w    Sonic_Main-Sonic_Index      ; 0 - object init
                dc.w    Sonic_Control-Sonic_Index       ; 2 - main mode
                dc.w    Sonic_Hurt-Sonic_Index          ; 4 - while being knocked back from damage
                dc.w    Sonic_Death-Sonic_Index         ; 6 - while dying and falling off screen
                dc.w    Sonic_ResetLevel-Sonic_Index    ; 8 - after having died and waiting for the level to restart

; Note: Sonic's SST aliases are defined in _Constants.asm
; ===========================================================================

; Obj01_Main:
Sonic_Main:                                       ; Routine 0
                addq.b  #2,obRoutine(a0)                ; set to Sonic_Control
                move.b  #sonic_height,obHeight(a0)      ; set default height
                move.b  #sonic_width,obWidth(a0)        ; set default width
                move.l  #Map_Sonic,obMap(a0)            ; set mappings
                move.w  #ArtTile_Sonic,obGfx(a0)        ; set VRAM location
                move.b  #2,obPriority(a0)               ; set sprite priority
                move.b  #48/2,obActWid(a0)              ; set render width
                move.b  #sprite_cam_field,obRender(a0)  ; set to playfield-positioned mode
                move.w  #son_maxspeed,(v_sonspeedmax).w  ; set Sonic's top speed
                move.w  #son_acceleration,(v_sonspeedacc).w  ; set Sonic's acceleration
                move.w  #son_deceleration,(v_sonspeeddec).w  ; set Sonic's deceleration
; ---------------------------------------------------------------------------

; Obj01_Control:
Sonic_Control:                                       ; Routine 2
                tst.w   (f_debugmode).w                 ; is debug cheat enabled?
                beq.s   .nodebug                        ; if not, branch
                btst    #bitB,(v_jpadpress1).w          ; is button B pressed?
                beq.s   .nodebug                        ; if not, branch
                move.w  #1,(v_debuguse).w               ; enter debug mode on the next frame (change Sonic into a ring/item)
                clr.b   (f_lockctrl).w                  ; unlock controls
                rts                                     ; return
; ===========================================================================

; loc_12C58:
.nodebug:
                tst.b   (f_lockctrl).w                  ; are controls locked?
                bne.s   .ignorecontrols                 ; if yes, branch
                move.w  (v_jpadhold1).w,(v_jpadhold2).w  ; enable joypad control

; loc_12C64:
.ignorecontrols:
                btst    #0,(f_playerctrl).w             ; is control override flag set?
                bne.s   .ignoremodes                    ; if yes, don't run Sonic_Modes

                moveq   #0,d0                           ; clear d0
                move.b  obStatus(a0),d0                 ; get Sonic's status flags
                andi.w  #status_in_air|status_rolling,d0  ; limit to "is in air" and "rolling" flags
                move.w  Sonic_Modes(pc,d0.w),d1         ; use the those as routine counter for the correct mode
                jsr     Sonic_Modes(pc,d1.w)            ; jump to that mode

; loc_12C7E:
.ignoremodes:
                bsr.s   Sonic_Display                   ; display Sonic sprite and handle power-up expiration
                bsr.w   Sonic_RecordPosition            ; record Sonic's previous position for the invincibility stars trail
                bsr.w   Sonic_Water                     ; handle Sonic while in water (LZ only)
                move.b  (v_anglebuffer).w,angleright(a0)  ; update front collision hot spot
                move.b  (v_anglebuffer2).w,angleleft(a0)  ; update rear collision hot spot

                tst.b   (f_wtunnelmode).w               ; is Sonic in a wind tunnel? (LZ only)
                beq.s   .nowindtunnel                   ; if not, branch
                tst.b   obAnim(a0)                      ; is current animation null/id_Walk?
                bne.s   .nowindtunnel                   ; if not, branch
                move.b  obPrevAni(a0),obAnim(a0)        ; make sure Sonic is in the correct animation while in a wind tunnel

; loc_12CA6:
.nowindtunnel:
                bsr.w   Sonic_Animate                   ; run Sonic's animation scripts
                tst.b   (f_playerctrl).w                ; is object interactions ignore flag set?
                bmi.s   .ignoreobjcoll                  ; if yes, branch
                jsr     (ReactToItem).l                 ; handle object interaction with Sonic

; loc_12CB6:
.ignoreobjcoll:
                bsr.w   Sonic_Loops                     ; handle Sonic running through loops
                bsr.w   Sonic_LoadGfx                   ; update Sonic's graphics if necessary
                rts                                     ; return
; End of function Sonic_Control

; ===========================================================================
; ---------------------------------------------------------------------------
; Sonic modes table, based on whether he is currently in-air and/or rolling
; This jump table uses Sonic's actual state bits in obStatus for the index
; ---------------------------------------------------------------------------
; Obj01_Modes:
Sonic_Modes:   dc.w    Sonic_MdNormal-Sonic_Modes  ; 0 - while on the ground and not rolling
                dc.w    Sonic_MdJump-Sonic_Modes        ; 2 - while in the air and not rolling
                dc.w    Sonic_MdRoll-Sonic_Modes        ; 4 - while on the ground and rolling
                dc.w    Sonic_MdJump2-Sonic_Modes       ; 6 - while in the air and rolling

; ===========================================================================
; ---------------------------------------------------------------------------
; Music to play after invincibility wears off
; (This is pretty much identical to the first MusicList, so it doesn't
; really make any sense as to why invincibility gets a separate one...)
; ---------------------------------------------------------------------------
MusicList2:
                dc.b    bgm_GHZ                         ; 00 - Green Hill Zone
                dc.b    bgm_LZ                          ; 01 - Labyrinth Zone
                dc.b    bgm_MZ                          ; 02 - Marble Zone
                dc.b    bgm_SLZ                         ; 03 - Star Light Zone
                dc.b    bgm_SYZ                         ; 04 - Spring Yard Zone
                dc.b    bgm_SBZ                         ; 05 - Scrap Brain Zone
                zonewarning MusicList2,1
; The ending doesn't get an entry
                even

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to display Sonic and set music
; ---------------------------------------------------------------------------

Sonic_Display:
                move.w  flashtime(a0),d0                ; get Sonic's remaining invulnerability frames after getting hurt
                beq.s   .display                        ; if there are none, branch
                subq.w  #1,flashtime(a0)                ; decrease invulnerability frames
                lsr.w   #3,d0                           ; don't render Sonic's sprite every
                bcc.s   .chkinvincible                  ; ...3 or 4 frames

; Obj01_Display:
.display:
                jsr     (DisplaySprite).l               ; display Sonic sprite normally

; Obj01_ChkInvin:
.chkinvincible:
                tst.b   (v_invinc).w                    ; does Sonic have invincibility?
                beq.s   .chkshoes                       ; if not, branch
                tst.w   invtime(a0)                     ; check time remaining for invincibility
                beq.s   .chkshoes                       ; if no time remains, branch
                subq.w  #1,invtime(a0)                  ; subtract 1 from time
                bne.s   .chkshoes                       ; if time remains, branch
                tst.b   (f_lockscreen).w                ; is a boss fight active?
                bne.s   .removeinvincible               ; if yes, don't change music
                cmpi.w  #12,(v_air).w                   ; is drowning countdown active?
                blo.s   .removeinvincible               ; if yes, don't change music

                moveq   #0,d0                           ; clear d0
                move.b  (v_zone).w,d0                   ; get current zone ID
                cmpi.w  #id_LZ_act4,(v_zone_act).w      ; check if level is SBZ3 (LZ4)
                bne.s   .music                          ; if not, branch
                moveq   #5,d0                           ; play SBZ music instead of LZ

; Obj01_PlayMusic:
.music:
                lea     (MusicList2).l,a1               ; load music list for post-invincibility
                move.b  (a1,d0.w),d0                    ; get entry for current zone
                jsr     (QueueSound1).l                 ; resume normal level music

; Obj01_RmvInvin:
.removeinvincible:
                move.b  #0,(v_invinc).w                 ; cancel invincibility

; Obj01_ChkShoes:
.chkshoes:
                tst.b   (v_shoes).w                     ; does Sonic have speed shoes?
                beq.s   .return                         ; if not, branch
                tst.w   shoetime(a0)                    ; check time remaining
                beq.s   .return                         ; if there is none, branch
                subq.w  #1,shoetime(a0)                 ; subtract 1 from time
                bne.s   .return                         ; if time remains, branch
                move.w  #son_maxspeed,(v_sonspeedmax).w  ; restore Sonic's max speed
                move.w  #son_acceleration,(v_sonspeedacc).w  ; restore Sonic's acceleration
                move.w  #son_deceleration,(v_sonspeeddec).w  ; restore Sonic's deceleration
                move.b  #0,(v_shoes).w                  ; cancel speed shoes
                move.w  #bgm_Slowdown,d0                ; resume music
                jmp     (QueueSound1).l                 ; ...at normal speed
; ===========================================================================

; Obj01_ExitChk:
.return:
                rts                                     ; return
; End of function Sonic_Display

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to record Sonic's previous positions for invincibility stars
; Interestingly, this buffer is way larger than it needs to be, with just
; over a full second of space for recorded data, even though the star trail
; won't ever be that long. Specifically, it's $100/4 = $40 (64 frames)
; ---------------------------------------------------------------------------

; Sonic_RecordPos:
Sonic_RecordPosition:
                move.w  (v_trackpos).w,d0               ; get current index for the tracking array
                lea     (v_tracksonic).w,a1             ; load tracking array
                lea     (a1,d0.w),a1                    ; set pointer to current index
                move.w  obX(a0),(a1)+                   ; store Sonic's current X-position
                move.w  obY(a0),(a1)+                   ; store Sonic's current Y-position
                addq.b  #4,(v_trackbyte).w              ; advance to next tracking pointer (this is a byte, so it wraps from $FC back to $00)
                rts                                     ; return
; End of function Sonic_RecordPosition

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine for Sonic when he's underwater
; ---------------------------------------------------------------------------

Sonic_Water:
                cmpi.b  #id_LZ,(v_zone).w               ; is level LZ?
                beq.s   .islabyrinth                    ; if yes, branch

; locret_12D80:
.return:
                rts                                     ; return
; ===========================================================================

; Obj01_InWater:
.islabyrinth:
                move.w  (v_waterpos1).w,d0              ; get current water height
                cmp.w   obY(a0),d0                      ; is Sonic above the water?
                bge.s   .abovewater                     ; if yes, branch
                bset    #status_underwater_bit,obStatus(a0)  ; set underwater flag
                bne.s   .return                         ; was Sonic already underwater? if yes, nothing to do

                bsr.w   ResumeMusic                     ; replenish air (music won't resume here, we've only just entered water...)
                move.b  #id_DrownCount,(v_sonicbubbles).w  ; load drown countdown object
                move.b  #$81,(v_sonicbubbles+obSubtype).w  ; prepare subtype so it sets itself to Drown_Countdown
                move.w  #son_maxspeed/2,(v_sonspeedmax).w  ; change Sonic's top speed (half of regular)
                move.w  #son_acceleration/2,(v_sonspeedacc).w  ; change Sonic's acceleration (half or regular)
                move.w  #son_deceleration/2,(v_sonspeeddec).w  ; change Sonic's deceleration (half of regular)
                asr.w   obVelX(a0)                      ; half X-speed when entering water
                asr.w   obVelY(a0)                      ; divide Y-speed by 4 when entering water
                asr.w   obVelY(a0)                      ; (can only do one bit shift at a time on RAM)
                beq.s   .return                         ; if Sonic's new Y-speed is 0, don't load splash object
                move.b  #id_Splash,(v_splash).w         ; load splash object
                move.w  #sfx_Splash,d0                  ; set splash sound
                jmp     (QueueSound2).l                 ; play it
; ===========================================================================

; Obj01_OutWater:
.abovewater:
                bclr    #status_underwater_bit,obStatus(a0)  ; clear underwater flag
                beq.s   .return                         ; was Sonic already above water? if yes, nothing to do

                bsr.w   ResumeMusic                     ; replenish air and resume music if necessary
                move.w  #son_maxspeed,(v_sonspeedmax).w  ; restore Sonic's speed
                move.w  #son_acceleration,(v_sonspeedacc).w  ; restore Sonic's acceleration
                move.w  #son_deceleration,(v_sonspeeddec).w  ; restore Sonic's deceleration
                asl.w   obVelY(a0)                      ; double Y-speed while exiting water
                beq.w   .return                         ; if Sonic's new Y-speed is 0, don't load splash object
                move.b  #id_Splash,(v_splash).w         ; load splash object
                cmpi.w  #-$1000,obVelY(a0)              ; is Sonic's new upwards speed too fast for collision detection to handle? (red springs probably cause this)
                bgt.s   .belowmaxspeed                  ; if not, branch
                move.w  #-$1000,obVelY(a0)              ; set maximum speed on leaving water

; loc_12E0E:
.belowmaxspeed:
                move.w  #sfx_Splash,d0                  ; set splash sound
                jmp     (QueueSound2).l                 ; play it
; End of function Sonic_Water

; ===========================================================================
; ---------------------------------------------------------------------------
; Modes for controlling Sonic
; ---------------------------------------------------------------------------

; Obj01_MdNormal:
Sonic_MdNormal:                                       ; While Sonic is on the ground and not rolling
                bsr.w   Sonic_Jump                      ; check if we need to jump
                bsr.w   Sonic_SlopeResistWalk           ; handle resistance from running up slopes
                bsr.w   Sonic_Move                      ; handle Sonic's left/right movement
                bsr.w   Sonic_Roll                      ; check if we need to roll
                bsr.w   Sonic_LevelBound                ; make sure Sonic stays within level bounds and handle bottomless pits
                jsr     (SpeedToPos).l                  ; update Sonic's position based on his current velocities
                bsr.w   Sonic_AnglePos                  ; update Sonic's current angle as he walks along the floor
                bsr.w   Sonic_SlopeRepel                ; handle Sonic detaching from walls if not fast enough
                rts
; ===========================================================================

; Obj01_MdJump:
Sonic_MdJump:                                       ; While Sonic is in the air but not rolling
                bsr.w   Sonic_JumpHeight                ; handle Sonic's jump height based on whether the jump button is still held
                bsr.w   Sonic_JumpDirection             ; handle midair direction adjustments while jumping
                bsr.w   Sonic_LevelBound                ; make sure Sonic stays within level bounds and handle bottomless pits
                jsr     (ObjectFall).l                  ; apply gravity and update Sonic's position based on his current velocities
                btst    #status_underwater_bit,obStatus(a0)  ; is Sonic underwater?
                beq.s   .notunderwater                  ; if not, branch
                subi.w  #gravity-$10,obVelY(a0)         ; reduce falling speed (ObjectFall applies $38, so this subtraction makes it $10)

; loc_12E5C:
.notunderwater:
                bsr.w   Sonic_JumpAngle                 ; steadily return Sonic's angle while jumping to 0
                bsr.w   Sonic_Floor                     ; handle collision with level while airborne
                rts                                     ; return
; ===========================================================================

; Obj01_MdRoll:
Sonic_MdRoll:                                       ; While Sonic is on the ground and rolling
                bsr.w   Sonic_Jump                      ; check if we need to jump
                bsr.w   Sonic_SlopeResistRoll           ; handle resistance from rolling up slopes
                bsr.w   Sonic_RollSpeed                 ; update speed as Sonic rolls
                bsr.w   Sonic_LevelBound                ; make sure Sonic stays within level bounds and handle bottomless pits
                jsr     (SpeedToPos).l                  ; update Sonic's position based on his current velocities
                bsr.w   Sonic_AnglePos                  ; update Sonic's current angle as he walks along the floor
                bsr.w   Sonic_SlopeRepel                ; handle Sonic detaching from walls if not fast enough
                rts
; ===========================================================================

; Obj01_MdJump2:
Sonic_MdJump2:                                       ; While Sonic is in the air and rolling (usually, but not limited to, jumping)
                bsr.w   Sonic_JumpHeight                ; handle Sonic's jump height based on whether the jump button is still held
                bsr.w   Sonic_JumpDirection             ; handle midair direction adjustments while jumping
                bsr.w   Sonic_LevelBound                ; make sure Sonic stays within level bounds and handle bottomless pits
                jsr     (ObjectFall).l                  ; apply gravity and update Sonic's position based on his current velocities
                btst    #status_underwater_bit,obStatus(a0)  ; is Sonic underwater?
                beq.s   .notunderwater                  ; if not, branch
                subi.w  #gravity-$10,obVelY(a0)         ; reduce falling speed (ObjectFall applies $38, so this subtraction makes it $10)

; loc_12EA6:
.notunderwater:
                bsr.w   Sonic_JumpAngle                 ; steadily return Sonic's angle while jumping to 0
                bsr.w   Sonic_Floor                     ; handle collision with level while airborne
                rts                                     ; return
; End of Sonic_Modes

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to make Sonic walk/run
; ---------------------------------------------------------------------------
