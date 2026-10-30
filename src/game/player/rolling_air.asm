Sonic_RollSpeed:
                move.w  (v_sonspeedmax).w,d6            ; get Sonic's current max speed
                asl.w   #1,d6                           ; ...doubled while rolling
                move.w  (v_sonspeedacc).w,d5            ; get Sonic's current acceleration
                asr.w   #1,d5                           ; ...halved while rolling
                move.w  (v_sonspeeddec).w,d4            ; get Sonic's current deceleration
                asr.w   #2,d4                           ; ...divided by 4 while rolling

                tst.b   (f_slidemode).w                 ; is Sonic on a water slide? (LZ only)
                bne.w   Sonic_AngledRollSpeed           ; if yes, branch (no rolling)
                tst.w   locktime(a0)                    ; is Sonic's D-Pad input temporarily locked?
                bne.s   .notright                       ; if yes, ignore D-Pad input
                btst    #bitL,(v_jpadhold2).w           ; is left being held?
                beq.s   .notleft                        ; if not, branch
                bsr.w   Sonic_RollLeft                  ; apply leftside movement updates for rolling

; loc_1317C:
.notleft:
                btst    #bitR,(v_jpadhold2).w           ; is right being held?
                beq.s   .notright                       ; if not, branch
                bsr.w   Sonic_RollRight                 ; apply rightward movement updates for rolling
; ---------------------------------------------------------------------------

; loc_13188:
.notright:
                move.w  obInertia(a0),d0                ; get Sonic's current ground speed
                beq.s   Sonic_RollSlowdownDone          ; is he standing still? if yes, branch
                bmi.s   .rollingleft                    ; is he moving to the left? if yes, branch
                sub.w   d5,d0                           ; slightly decrease Sonic's current roll speed
                bcc.s   .stillrollingright              ; if still rolling, branch
                move.w  #0,d0                           ; reset speed to zero on sign change

; loc_13198:
.stillrollingright:
                move.w  d0,obInertia(a0)                ; set new ground speed
                bra.s   Sonic_RollSlowdownDone          ; skip over leftward rolling updates
; ===========================================================================

; loc_1319E:
.rollingleft:
                add.w   d5,d0                           ; slightly decrease Sonic's current roll speed
                bcc.s   .stillrollingleft               ; if still rolling, branch
                move.w  #0,d0                           ; reset speed to zero on sign change

; loc_131A6:
.stillrollingleft:
                move.w  d0,obInertia(a0)                ; set new ground speed
; ---------------------------------------------------------------------------

; loc_131AA:
Sonic_RollSlowdownDone:
                tst.w   obInertia(a0)                   ; is Sonic standing still?
                bne.s   Sonic_AngledRollSpeed           ; if not, branch

                bclr    #status_rolling_bit,obStatus(a0)  ; clear rolling flag
                move.b  #sonic_height,obHeight(a0)      ; reset Sonic's hitbox height to default
                move.b  #sonic_width,obWidth(a0)        ; reset Sonic's hitbox width to default
                move.b  #id_Wait,obAnim(a0)             ; use "standing" animation
                subq.w  #sonic_height-sonic_roll_height,obY(a0)  ; adjust Y-position for standing
; ---------------------------------------------------------------------------

; loc_131CC:
Sonic_AngledRollSpeed:
                move.b  obAngle(a0),d0                  ; get Sonic's current angle in relation to the floor
                jsr     (CalcSine).l                    ; get sine and cosine values for the angle
                muls.w  obInertia(a0),d0                ; multiply angle sine by ground speed
                asr.l   #8,d0                           ; shift result one byte down

                move.w  d0,obVelY(a0)                   ; set new Y-velocity

                muls.w  obInertia(a0),d1                ; multiply angle cosine by ground speed
                asr.l   #8,d1                           ; shift result one byte down
                cmpi.w  #$1000,d1                       ; is new X-velocity bigger than maximum screen shift speed? (rightward)
                ble.s   .noPosIntCapX                   ; if not, branch
                move.w  #$1000,d1                       ; cap roll speed to screen shift speed (rightward)
; loc_131F0:
.noPosIntCapX:
                cmpi.w  #-$1000,d1                      ; is new X-velocity bigger than maximum screen shift speed? (leftward)
                bge.s   .noNegIntCapX                   ; if not, branch
                move.w  #-$1000,d1                      ; cap roll speed to screen shift speed (leftward)
; loc_131FA:
.noNegIntCapX:
                move.w  d1,obVelX(a0)                   ; set new X-velocity

                bra.w   Sonic_WallSpeedAdjust           ; adjust speed variations depending on current angle, or stop at wall
; End of function Sonic_RollSpeed

; ---------------------------------------------------------------------------
; Subroutine handling Sonic's movement while rolling to the left
; ---------------------------------------------------------------------------

Sonic_RollLeft:
                move.w  obInertia(a0),d0                ; get Sonic's current ground speed
                beq.s   .still                          ; is Sonic standing still? if yes, branch
                bpl.s   .changeddirection               ; has Sonic changed direction? if yes, branch

; loc_1320A:
.still:
                bset    #status_xflip_bit,obStatus(a0)  ; set X-flip flag (Sonic is facing left)
                move.b  #id_Roll,obAnim(a0)             ; use "rolling" animation
                rts                                     ; return
; ===========================================================================

; loc_13218:
.changeddirection:
                sub.w   d4,d0                           ; apply deceleration to current speed
                bcc.s   .stilldecel                     ; if still decelerating, branch
                move.w  #-$80,d0                        ; set minimum speed on sign change

; loc_13220:
.stilldecel:
                move.w  d0,obInertia(a0)                ; set new ground speed
                rts                                     ; return
; End of function Sonic_RollLeft

; ---------------------------------------------------------------------------
; Subroutine handling Sonic's movement while rolling to the right
; ---------------------------------------------------------------------------

Sonic_RollRight:
                move.w  obInertia(a0),d0                ; get Sonic's current ground speed
                bmi.s   .changedirection                ; has Sonic changed direction? if yes, branch
                bclr    #status_xflip_bit,obStatus(a0)  ; clear X-flip flag (Sonic is facing right)
                move.b  #id_Roll,obAnim(a0)             ; use "rolling" animation
                rts                                     ; return
; ===========================================================================

; loc_1323A:
.changedirection:
                add.w   d4,d0                           ; apply deceleration to current speed
                bcc.s   .stilldecel                     ; if still decelerating, branch
                move.w  #$80,d0                         ; set minimum speed on sign change

; loc_13242:
.stilldecel:
                move.w  d0,obInertia(a0)                ; set new ground speed
                rts                                     ; return
; End of function Sonic_RollRight

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to change Sonic's direction while jumping
; ---------------------------------------------------------------------------

; Sonic_ChgJumpDir:
Sonic_JumpDirection:
                move.w  (v_sonspeedmax).w,d6            ; get Sonic's current top speed
                move.w  (v_sonspeedacc).w,d5            ; get Sonic's current acceleration
                asl.w   #1,d5                           ; ...doubled

                btst    #status_rolljumping_bit,obStatus(a0)  ; is Roll-Jump flag set?
                bne.s   Sonic_RollJumpLock              ; if yes, prevent midair direction change

                move.w  obVelX(a0),d0                   ; get Sonic's current X-velocity
                btst    #bitL,(v_jpadhold2).w           ; is left being held?
                beq.s   .notleft                        ; if not, branch
                bset    #status_xflip_bit,obStatus(a0)  ; set X-flip flag (Sonic is facing left)
                sub.w   d5,d0                           ; increase leftward movement speed
                move.w  d6,d1                           ; copy top speed
                neg.w   d1                              ; negate it for leftward movement check
                cmp.w   d1,d0                           ; is new speed exceeding maximum?
                bgt.s   .notleft                        ; if not, branch
                move.w  d1,d0                           ; cap leftward X-speed to maximum

; loc_13278:
.notleft:
                btst    #bitR,(v_jpadhold2).w           ; is right being held?
                beq.s   Sonic_JumpMove                  ; if not, branch
                bclr    #status_xflip_bit,obStatus(a0)  ; clear X-flip flag (Sonic is facing right)
                add.w   d5,d0                           ; increase rightward movement speed
                cmp.w   d6,d0                           ; is new speed exceeding maximum?
                blt.s   Sonic_JumpMove                  ; if not, branch
                move.w  d6,d0                           ; cap rightward X-speed to maximum

; Obj01_JumpMove:
Sonic_JumpMove:
                move.w  d0,obVelX(a0)                   ; update Sonic's horizontal speed
; ---------------------------------------------------------------------------

; Obj01_ResetScr2:
Sonic_RollJumpLock:
                cmpi.w  #$60,(v_lookshift).w            ; is screen in its default position?
                beq.s   Sonic_AirDrag                   ; if yes, branch
                bcc.s   .resetdown                      ; does camera need to go back down? if yes, branch
                addq.w  #4,(v_lookshift).w              ; move camera back up (becomes 2 with the next line)

; loc_132A0:
.resetdown:
                subq.w  #2,(v_lookshift).w              ; move camera back down
; ---------------------------------------------------------------------------

; loc_132A4:
Sonic_AirDrag:
                cmpi.w  #-$400,obVelY(a0)               ; is Sonic moving faster than -$400 upwards?
                blo.s   .return                         ; if yes, branch (skip air drag)

                move.w  obVelX(a0),d0                   ; get current X-velocity
                move.w  d0,d1                           ; copy it
                asr.w   #5,d1                           ; divide that copy by $20
                beq.s   .return                         ; if result is zero, branch
                bmi.s   .jumpingleftward                ; if speed is negative, branch
                sub.w   d1,d0                           ; slightly reduce speed (air drag)
                bcc.s   .stillright                     ; if result is still rightward, branch
                move.w  #0,d0                           ; reset speed on sign change

; loc_132C0:
.stillright:
                move.w  d0,obVelX(a0)                   ; set new X-speed
                rts                                     ; return
; ===========================================================================

; loc_132C6:
.jumpingleftward:
                sub.w   d1,d0                           ; slightly reduce speed (air drag)
                bcs.s   .stillleft                      ; if result is still leftward, branch
                move.w  #0,d0                           ; reset speed on sign change

; loc_132CE:
.stillleft:
                move.w  d0,obVelX(a0)                   ; set new X-speed

; locret_132D2:
.return:
                rts                                     ; return
; End of function Sonic_JumpDirection

; ===========================================================================
; ---------------------------------------------------------------------------
; Unused subroutine to squash Sonic into the ceiling. When Sonic gets stuck
; in a ceiling, this would zero all his momentum and set his animation to
; be the vertical "warping" sprite, which is also unused. The purpose of
; this routine isn't known, though it possibly was for troubleshooting
; collision errors in which Sonic would somehow clip through ceilings
; ---------------------------------------------------------------------------

Sonic_SquashUnused:
                move.b  obAngle(a0),d0                  ; get Sonic's current angle
                addi.b  #$20,d0                         ; rotate it by 45 degrees
                andi.b  #$C0,d0                         ; snap angle to nearest multiple of 90 degrees
                bne.s   .return                         ; if Sonic is standing on a wall/ceiling, branch (must be standing on a floor)
                bsr.w   Sonic_FindCeiling               ; find Sonic's distance to the ceiling
                tst.w   d1                              ; is he below it?
                bpl.s   .return                         ; if yes, branch (this should always happen unless he clipped through)

                move.w  #0,obInertia(a0)                ; clear Sonic's ground speed
                move.w  #0,obVelX(a0)                   ; clear Sonic's horizontal speed
                move.w  #0,obVelY(a0)                   ; clear Sonic's vertical speed
                move.b  #id_Warp3,obAnim(a0)            ; use "warping" animation

; locret_13302:
.return:
                rts                                     ; return
; End of function Sonic_SquashUnused

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to prevent Sonic leaving the left/right boundaries of a level,
; dying to bottomless pits, and handling the transition from SBZ2 to SBZ3
; This routine does not do anything about the top boundary
; ---------------------------------------------------------------------------
