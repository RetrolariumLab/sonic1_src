Sonic_LevelBound:
                move.l  obX(a0),d1                      ; get Sonic's current X-position
                move.w  obVelX(a0),d0                   ; get Sonic's current X-velocity
                ext.l   d0                              ; sign-extend X-velocity
                asl.l   #8,d0                           ; shift upper byte of velocity to upper word
                add.l   d0,d1                           ; add to previous X-position
                swap    d1                              ; move new absolute pixel position to lower word

                move.w  (v_limitleft2).w,d0             ; load level's left boundary
                addi.w  #16,d0                          ; add 16px of leeway
                cmp.w   d1,d0                           ; has Sonic touched the left level boundary?
                bhi.s   .sides                          ; if yes, branch

                move.w  (v_limitright2).w,d0            ; load level's right boundary
                addi.w  #320-24,d0                      ; add screen width - 24px of leeway
                tst.b   (f_lockscreen).w                ; is a boss fight active?
                bne.s   .screenlocked                   ; if yes, branch
                addi.w  #64,d0                          ; increase leeway by 64px outside of boss fights

; loc_13332:
.screenlocked:
                cmp.w   d1,d0                           ; has Sonic touched the right level boundary?
                bls.s   .sides                          ; if yes, branch

; loc_13336:
.chkbottom:
                move.w  (v_limitbtm2).w,d0              ; load current target bottom level boundary
                addi.w  #224,d0                         ; add screen height
                cmp.w   obY(a0),d0                      ; has Sonic touched the bottom boundary?
                blt.s   .bottom                         ; if yes, branch
                rts                                     ; return
; ===========================================================================

; Boundary_Bottom:
.bottom:
                cmpi.w  #id_SBZ_act2,(v_zone_act).w     ; is level SBZ2?
                bne.w   KillSonic                       ; if not, kill Sonic
                cmpi.w  #$2000,(v_player+obX).w         ; is Sonic far enough into the level?
                blo.w   KillSonic                       ; if not, kill Sonic

; Transition from SBZ2 to SBZ3
                clr.b   (v_lastlamp).w                  ; clear lamppost counter
                move.w  #1,(f_restart).w                ; restart the level
                move.w  #id_LZ_act4,(v_zone_act).w      ; set level to SBZ3 (LZ4)
                rts                                     ; return
; ===========================================================================

; Boundary_Sides:
.sides:
                move.w  d0,obX(a0)                      ; prevent Sonic from leaving the side boundary
                move.w  #0,obSubpixelX(a0)              ; clear subpixel portion
                move.w  #0,obVelX(a0)                   ; clear X-velocity
                move.w  #0,obInertia(a0)                ; clear ground speed
                bra.s   .chkbottom                      ; check for bottom boundary collision as well
; ===========================================================================

; End of function Sonic_LevelBound

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine allowing Sonic to roll when he's moving
; ---------------------------------------------------------------------------

Sonic_Roll:
                tst.b   (f_slidemode).w                 ; is Sonic currently on a water slide?
                bne.s   .noroll                         ; if yes, don't allow rolling

                move.w  obInertia(a0),d0                ; get Sonic's current ground speed
                bpl.s   .ispositive                     ; is it positive? if yes, branch
                neg.w   d0                              ; otherwise, make it positive
; loc_13392:
.ispositive:
                cmpi.w  #$80,d0                         ; is Sonic moving at $80 speed or faster?
                blo.s   .noroll                         ; if not, branch
                move.b  (v_jpadhold2).w,d0              ; get held buttons
                andi.b  #btnL+btnR,d0                   ; is left/right being held?
                bne.s   .noroll                         ; if yes, prevent rolling (some kind of fat-fingering convenience feature?)
                btst    #bitDn,(v_jpadhold2).w          ; is down being held?
                bne.s   Sonic_ChkRoll                   ; if yes, branch

; Obj01_NoRoll:
.noroll:
                rts                                     ; return
; ===========================================================================

; Obj01_ChkRoll:
Sonic_ChkRoll:
                btst    #status_rolling_bit,obStatus(a0)  ; is Sonic already rolling?
                beq.s   .roll                           ; if not, branch to initiate a roll
                rts                                     ; otherwise, do nothing
; ===========================================================================

; Obj01_DoRoll:
.roll:
                bset    #status_rolling_bit,obStatus(a0)  ; set rolling flag
                move.b  #sonic_roll_height,obHeight(a0)  ; set Sonic's hitbox height to rolling size
                move.b  #sonic_roll_width,obWidth(a0)   ; set Sonic's hitbox width to rolling size
                move.b  #id_Roll,obAnim(a0)             ; use "rolling" animation
                addq.w  #sonic_height-sonic_roll_height,obY(a0)  ; adjust Y-position to align Sonic to the floor
                move.w  #sfx_Roll,d0                    ; set rolling sound
                jsr     (QueueSound2).l                 ; play it

                tst.w   obInertia(a0)                   ; is current speed zero?
                bne.s   .ismoving                       ; if not, branch
                move.w  #$200,obInertia(a0)             ; force forward movement (this is used for the S-tunnels in GHZ to not get stuck)

; locret_133E8:
.ismoving:
                rts                                     ; return
; End of function Sonic_Roll

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine allowing Sonic to jump
; ---------------------------------------------------------------------------

Sonic_Jump:
                move.b  (v_jpadpress2).w,d0             ; get pressed buttons
                andi.b  #btnABC,d0                      ; is A, B or C pressed?
                beq.w   .return                         ; if not, branch

                moveq   #0,d0                           ; clear d0
                move.b  obAngle(a0),d0                  ; get Sonic's current angle
                addi.b  #$80,d0                         ; rotate 180 degrees for ceiling collision check
                bsr.w   Sonic_CalcHeadroom              ; calculate pixels above Sonic's head
                cmpi.w  #6,d1                           ; are there less than 6px between Sonic and the ceiling?
                blt.w   .return                         ; if yes, prevent jumping

                move.w  #son_jumpspeed,d2               ; set initial jump force
                btst    #status_underwater_bit,obStatus(a0)  ; is Sonic underwater?
                beq.s   .notunderwater                  ; if not, continue
                move.w  #son_jumpspeed-$300,d2          ; set underwater jump force
; loc_1341C:
.notunderwater:
                moveq   #0,d0                           ; clear d0
                move.b  obAngle(a0),d0                  ; get Sonic's current angle
                subi.b  #$40,d0                         ; rotate it perpendicularly for jump trajectory
                jsr     (CalcSine).l                    ; find the direction Sonic should jump
                muls.w  d2,d1                           ; apply jump force to the cosine angle
                asr.l   #8,d1                           ; shift it to upper word
                add.w   d1,obVelX(a0)                   ; apply to X speed
                muls.w  d2,d0                           ; apply jump force to the sine angle
                asr.l   #8,d0                           ; shift it to upper word
                add.w   d0,obVelY(a0)                   ; apply to Y speed
                bset    #status_in_air_bit,obStatus(a0)  ; set in-air flag
                bclr    #status_pushing_bit,obStatus(a0)  ; clear pushing flag
                addq.l  #4,sp                           ; run in-air subroutines when we return
                move.b  #1,jumping(a0)                  ; set jump flag
                clr.b   sticktoconvex(a0)               ; detach Sonic from the gears in SBZ
                move.w  #sfx_Jump,d0                    ; set jump sound
                jsr     (QueueSound2).l                 ; play jumping sound
; This sets Sonic's hitbox to standing size when roll-jumping
; A leftover from the victory animation in prototypes
                move.b  #sonic_height,obHeight(a0)      ; set height to standing size
                move.b  #sonic_width,obWidth(a0)        ; set width to standing size

                btst    #status_rolling_bit,obStatus(a0)  ; is Sonic already in a ball state?
                bne.s   .rolljump                       ; if so, branch
                move.b  #sonic_roll_height,obHeight(a0)  ; set height to rolling size
                move.b  #sonic_roll_width,obWidth(a0)   ; set width to rolling size
                move.b  #id_Roll,obAnim(a0)             ; use "jumping" animation
                bset    #status_rolling_bit,obStatus(a0)  ; set rolling flag
                addq.w  #sonic_height-sonic_roll_height,obY(a0)  ; adjust Y-position to align Sonic to the floor

; locret_1348E:
.return:
                rts                                     ; return
; ===========================================================================

; loc_13490:
.rolljump:
                bset    #status_rolljumping_bit,obStatus(a0)  ; set Roll-Jump flag
                rts                                     ; return
; End of function Sonic_Jump

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine controlling Sonic's jump height/duration
; ---------------------------------------------------------------------------

Sonic_JumpHeight:
                tst.b   jumping(a0)                     ; is Sonic airborne specifically from a jump?
                beq.s   .capyvel                        ; if not, just cap Y speed normally
                move.w  #-$400,d1                       ; set max jump height
                btst    #status_underwater_bit,obStatus(a0)  ; is Sonic underwater?
                beq.s   .notunderwater                  ; if not, continue
                move.w  #-$200,d1                       ; set underwater jump height

; loc_134AE:
.notunderwater:
                cmp.w   obVelY(a0),d1                   ; get current y speed
                ble.s   .return                         ; is Sonic moving up slower than the cap speed? if yes, branch
                move.b  (v_jpadhold2).w,d0              ; get currently held buttons
                andi.b  #btnABC,d0                      ; is A, B or C still held after jumping?
                bne.s   .return                         ; if yes, branch
                move.w  d1,obVelY(a0)                   ; otherwise, cap Sonic's maximum jump height

; locret_134C2:
.return:
; This prevents the max Y-vel cap from running while jumping
                rts                                     ; return
; ===========================================================================

; loc_134C4:
.capyvel:
                cmpi.w  #-$FC0,obVelY(a0)               ; is Sonic moving up just below the maximum screen scroll speed? (-$1000)
                bge.s   .return2                        ; if not, branch
                move.w  #-$FC0,obVelY(a0)               ; force Sonic to stay below maximum screen scroll speed

; locret_134D2:
.return2:
                rts                                     ; return
; End of function Sonic_JumpHeight

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to adjust Sonic's speed while walking up/down slopes
; ---------------------------------------------------------------------------

; Sonic_SlopeResist:
Sonic_SlopeResistWalk:
                move.b  obAngle(a0),d0                  ; get Sonic's current angle
                addi.b  #$60,d0                         ; rotate it by 135 degrees
                cmpi.b  #$C0,d0                         ; is Sonic on a steep enough slope?
                bhs.s   .return                         ; if no, don't do slope resist

                move.b  obAngle(a0),d0                  ; get Sonic's current angle
                jsr     (CalcSine).l                    ; get sine and cosine values for angle
                muls.w  #$20,d0                         ; multiply by resist force while walking
                asr.l   #8,d0                           ; shift down a byte

                tst.w   obInertia(a0)                   ; check Sonic's ground speed
                beq.s   .return                         ; if he's standing still, branch
                bmi.s   .left                           ; if he's walking leftward, branch
                tst.w   d0                              ; is resist force zero?
                beq.s   .noresist                       ; if yes, branch
                add.w   d0,obInertia(a0)                ; add resist force to Sonic's speed while walking up a right slope

; locret_13502:
.noresist:
                rts                                     ; return
; ===========================================================================

; loc_13504:
.left:
                add.w   d0,obInertia(a0)                ; add resist force to Sonic's speed while walking up a left slope

; locret_13508:
.return:
                rts                                     ; return
; End of function Sonic_SlopeResist

; ---------------------------------------------------------------------------
; ; Subroutine to adjust Sonic's speed while rolling up/down slopes
; ---------------------------------------------------------------------------

; Sonic_RollRepel:
Sonic_SlopeResistRoll:
                move.b  obAngle(a0),d0                  ; get Sonic's current angle
                addi.b  #$60,d0                         ; rotate it by 135 degrees
                cmpi.b  #$C0,d0                         ; is Sonic on a steep enough slope?
                bhs.s   .return                         ; if no, don't do slope resist

                move.b  obAngle(a0),d0                  ; get Sonic's current angled
                jsr     (CalcSine).l                    ; get sine and cosine values for angle
                muls.w  #$50,d0                         ; multiply by resist force while rolling (2.5x larger than walking)
                asr.l   #8,d0                           ; shift down a byte

                tst.w   obInertia(a0)                   ; check Sonic's current ground speed
                bmi.s   .left                           ; he's rolling to the left, branch
                tst.w   d0                              ; is resist force zero or positive?
                bpl.s   .resistright                    ; if yes, branch (descending from slope rolls faster)
                asr.l   #2,d0                           ; reduce resist force while ascending a slope

; loc_13534:
.resistright:
                add.w   d0,obInertia(a0)                ; add resist force to Sonic's speed while rolling up a right slope
                rts                                     ; return
; ===========================================================================

; loc_1353A:
.left:
                tst.w   d0                              ; is resist force negative?
                bmi.s   .resistleft                     ; if yes, branch (descending from slope rolls faster)
                asr.l   #2,d0                           ; reduce resist force while ascending a slope

; loc_13540:
.resistleft:
                add.w   d0,obInertia(a0)                ; add resist force to Sonic's speed while walking up a left slope

; locret_13544:
.return:
                rts                                     ; return
; End of function Sonic_RollRepel

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to detach Sonic from steep slopes if he's too slow
; ---------------------------------------------------------------------------

Sonic_SlopeRepel:
                nop                                     ; (probably replaced with an rts during development to stick to walls)
                tst.b   sticktoconvex(a0)               ; is Sonic on an SBZ gear?
                bne.s   .return                         ; if yes, branch
                tst.w   locktime(a0)                    ; are left/right controls temporarily locked?
                bne.s   .decrementlocktime              ; if yes, branch

                move.b  obAngle(a0),d0                  ; get Sonic's current angle
                addi.b  #$20,d0                         ; rotate it by 45 degrees
                andi.b  #$C0,d0                         ; snap to nearest multiple of 90 degrees
                beq.s   .return                         ; if Sonic is not on a wall or ceiling, branch

                move.w  obInertia(a0),d0                ; get Sonic's current ground speed
                bpl.s   .posinertia                     ; is it positive? if yes, branch
                neg.w   d0                              ; otherwise, make it positive

; loc_1356A:
.posinertia:
                cmpi.w  #$280,d0                        ; is Sonic's ground speed high enough?
                bhs.s   .return                         ; if yes, branch
                clr.w   obInertia(a0)                   ; clear ground speed
                bset    #status_in_air_bit,obStatus(a0)  ; set in-air flag to detach Sonic from wall
                move.w  #30,locktime(a0)                ; disable left/right input for half a second

; locret_13580:
.return:
                rts                                     ; return
; ===========================================================================

; loc_13582:
.decrementlocktime:
                subq.w  #1,locktime(a0)                 ; decrement left/right disable timer
                rts                                     ; return
; End of function Sonic_SlopeRepel

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to return Sonic's angle to 0 as he jumps
; ---------------------------------------------------------------------------

Sonic_JumpAngle:
                move.b  obAngle(a0),d0                  ; get Sonic's angle
                beq.s   .return                         ; if already 0, branch
                bpl.s   .decrease                       ; if higher than 0, branch
                addq.b  #2,d0                           ; increase angle
                bcc.s   .dontclear                      ; if the angle's still below 0, don't clear the angle
                moveq   #0,d0                           ; set angle to d0

; loc_13596:
.dontclear:
                bra.s   .applyangle                     ; skip over to update angle
; ===========================================================================

; loc_13598:
.decrease:
                subq.b  #2,d0                           ; decrease angle
                bcc.s   .applyangle                     ; if the angle's still above 0, don't clear the angle
                moveq   #0,d0                           ; set angle to 0

; loc_1359E:
.applyangle:
                move.b  d0,obAngle(a0)                  ; set new angle value

; locret_135A2:
.return:
                rts                                     ; return
; End of function Sonic_JumpAngle

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine for Sonic to interact with the floor after jumping/falling
; To save on resources, the game will only check one out of four quadrants,
; depending on which direction Sonic moving toward the most
; This routine contains various writes to unused variables, likely used
; during development to debug the collision system while in air
; ---------------------------------------------------------------------------
