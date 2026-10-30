Sonic_Move:
                move.w  (v_sonspeedmax).w,d6            ; get Sonic's current top speed
                move.w  (v_sonspeedacc).w,d5            ; get Sonic's current acceleration
                move.w  (v_sonspeeddec).w,d4            ; get Sonic's current deceleration

                tst.b   (f_slidemode).w                 ; is Sonic currently on a water slide? (LZ only)
                bne.w   Sonic_AngleSpeed                ; if yes, branch
                tst.w   locktime(a0)                    ; is Sonic's D-Pad input temporarily locked?
                bne.w   Sonic_ResetScr                  ; if yes, ignore D-Pad input
                btst    #bitL,(v_jpadhold2).w           ; is left being held?
                beq.s   .notleft                        ; if not, branch
                bsr.w   Sonic_MoveLeft                  ; apply left side movement updates

; Obj01_NotLeft:
.notleft:
                btst    #bitR,(v_jpadhold2).w           ; is right being held?
                beq.s   .notright                       ; if not, branch
                bsr.w   Sonic_MoveRight                 ; apply right side movement updates

; Obj01_NotRight:
.notright:
                move.b  obAngle(a0),d0                  ; get Sonic's current angle
                addi.b  #$20,d0                         ; rotate it 45 degrees clockwise
                andi.b  #$C0,d0                         ; snap to nearest multiple of 90 degrees
                bne.w   Sonic_ResetScr                  ; is Sonic on a slope? if yes, branch

                tst.w   obInertia(a0)                   ; is Sonic standing still?
                bne.w   Sonic_ResetScr                  ; if not, branch
                bclr    #status_pushing_bit,obStatus(a0)  ; clear pushing flag
                move.b  #id_Wait,obAnim(a0)             ; use "standing" animation
                btst    #status_on_object_bit,obStatus(a0)  ; is Sonic standing on a platform object?
                beq.s   .chkbalance                     ; if not, branch

                moveq   #0,d0                           ; clear d0
                move.b  standonobject(a0),d0            ; get OST index of object Sonic is currently standing on
                lsl.w   #object_size_bits,d0            ; multiply by $40 (object_size)
                lea     (v_objspace).w,a1               ; load object space
                lea     (a1,d0.w),a1                    ; load stood-on object
                tst.b   obStatus(a1)                    ; does the object block Sonic's balancing animation?
                bmi.s   Sonic_LookUp                    ; if yes, skip over balance check

                moveq   #0,d1                           ; clear d1
                move.b  obActWid(a1),d1                 ; get physical width of stood-on object
                move.w  d1,d2                           ; copy width
                add.w   d2,d2                           ; double it
                subq.w  #4,d2                           ; minus 4
                add.w   obX(a0),d1                      ; get Sonic's current X-position
                sub.w   obX(a1),d1                      ; subtract stood-on object's X-position
                cmpi.w  #4,d1                           ; is Sonic within 4px of the object's left edge?
                blt.s   .leftbalance                    ; if yes, branch
                cmp.w   d2,d1                           ; is Sonic within 4px of the object's right edge?
                bge.s   .rightbalance                   ; if yes, branch
                bra.s   Sonic_LookUp                    ; skip over (no balancing)
; ===========================================================================

; Sonic_Balance:
.chkbalance:
                jsr     (ObjFloorDist).l                ; get distance of Sonic to nearest floor
                cmpi.w  #12,d1                          ; is he within 12px to floor?
                blt.s   Sonic_LookUp                    ; if yes, don't do balance animation (would look awkward)
                cmpi.b  #3,angleright(a0)               ; is Sonic at the right edge of the floor?
                bne.s   .chkleftedge                    ; if not, check for the left edge

; loc_12F5A:
.rightbalance:
                bclr    #status_xflip_bit,obStatus(a0)  ; clear X-flip flag (make Sonic face right)
                bra.s   .balance                        ; do balance animation
; ===========================================================================

; loc_12F62:
.chkleftedge:
                cmpi.b  #3,angleleft(a0)                ; is Sonic at the left edge of the floor?
                bne.s   Sonic_LookUp                    ; if not, branch (no balancing)

; loc_12F6A:
.leftbalance:
                bset    #status_xflip_bit,obStatus(a0)  ; set X-flip flag (make Sonic face left)

; loc_12F70:
.balance:
                move.b  #id_Balance,obAnim(a0)          ; use "balancing" animation
                bra.s   Sonic_ResetScr                  ; prevent looking up/down
; ===========================================================================

Sonic_LookUp:
                btst    #bitUp,(v_jpadhold2).w          ; is up being held?
                beq.s   Sonic_Duck                      ; if not, check for ducking instead
                move.b  #id_LookUp,obAnim(a0)           ; use "looking up" animation
                cmpi.w  #$C8,(v_lookshift).w            ; has camera already fully moved up?
                beq.s   Sonic_CheckDpadLetGo            ; if yes, don't move it up further
                addq.w  #2,(v_lookshift).w              ; move camera up further
                bra.s   Sonic_CheckDpadLetGo            ; skip over
; ===========================================================================

; Sonic_LookDown:
Sonic_Duck:
                btst    #bitDn,(v_jpadhold2).w          ; is down being held?
                beq.s   Sonic_ResetScr                  ; if not, branch
                move.b  #id_Duck,obAnim(a0)             ; use "ducking" animation
                cmpi.w  #8,(v_lookshift).w              ; has camera already fully moved down?
                beq.s   Sonic_CheckDpadLetGo            ; if yes, branch
                subq.w  #2,(v_lookshift).w              ; move camera down further
                bra.s   Sonic_CheckDpadLetGo            ; skip over
; ===========================================================================

; Obj01_ResetScr:
Sonic_ResetScr:
                cmpi.w  #$60,(v_lookshift).w            ; is screen in its default position?
                beq.s   Sonic_CheckDpadLetGo            ; if yes, branch
                bcc.s   .resetdown                      ; does camera need to go back down? if yes, branch
                addq.w  #4,(v_lookshift).w              ; move camera back up (becomes 2 with the next line)

; loc_12FBE:
.resetdown:
                subq.w  #2,(v_lookshift).w              ; move camera back down
; ---------------------------------------------------------------------------

; loc_12FC2:
Sonic_CheckDpadLetGo:
                move.b  (v_jpadhold2).w,d0              ; get held buttons
                andi.b  #btnL+btnR,d0                   ; is left or right held?
                bne.s   Sonic_AngleSpeed                ; if yes, branch (don't decrease speed)
                move.w  obInertia(a0),d0                ; get Sonic's current ground speed
                beq.s   Sonic_AngleSpeed                ; is he standing still? if yes, branch
                bmi.s   .movingleftward                 ; is he moving to the left? if yes, branch
                sub.w   d5,d0                           ; reduce current rightward speed by acceleration
                bcc.s   .stillright                     ; if result is still to the right, branch
                move.w  #0,d0                           ; reset speed to zero on sign change

; loc_12FDC:
.stillright:
                move.w  d0,obInertia(a0)                ; set Sonic's new ground speed
                bra.s   Sonic_AngleSpeed                ; skip over
; ===========================================================================

; loc_12FE2:
.movingleftward:
                add.w   d5,d0                           ; reduce current leftward speed by acceleration
                bcc.s   .stillleft                      ; if result is still to the left, branch
                move.w  #0,d0                           ; reset speed to zero on sign change

; loc_12FEA:
.stillleft:
                move.w  d0,obInertia(a0)                ; set Sonic's new ground speed
; ---------------------------------------------------------------------------

; loc_12FEE:
Sonic_AngleSpeed:
                move.b  obAngle(a0),d0                  ; get Sonic's current angle in relation to the floor
                jsr     (CalcSine).l                    ; get sine and cosine values based on angle
                muls.w  obInertia(a0),d1                ; multiply cosine value by current ground speed
                asr.l   #8,d1                           ; shift result up a byte
                move.w  d1,obVelX(a0)                   ; set new X-velocity
                muls.w  obInertia(a0),d0                ; multiply sine value by current ground speed
                asr.l   #8,d0                           ; shift result up a byte
                move.w  d0,obVelY(a0)                   ; set new Y-velocity
; ---------------------------------------------------------------------------

; loc_1300C:
Sonic_WallSpeedAdjust:
                move.b  obAngle(a0),d0                  ; get Sonic's current angle in relation to the floor
                addi.b  #$40,d0                         ; rotate it by 90 degrees
                bmi.s   .return                         ; if Sonic is upside down, branch (to prevent potential collision issues with loops)

.noearlyexit:
                move.b  #$40,d1                         ; get angle rotation for wall collision detection
                tst.w   obInertia(a0)                   ; is Sonic standing still?
                beq.s   .return                         ; if yes, branch
                bmi.s   .negspeed                       ; is he moving to the left? if yes, branch
                neg.w   d1                              ; invert angle rotation when moving right

; loc_13024:
.negspeed:
                move.b  obAngle(a0),d0                  ; get Sonic's current angle
                add.b   d1,d0                           ; rotate it by 90 degrees depending on directional speed
                move.w  d0,-(sp)                        ; backup d0
                bsr.w   Sonic_CalcRoomAhead             ; calculate distance to the wall in front of Sonic (if any)
                move.w  (sp)+,d0                        ; restore d0
                tst.w   d1                              ; has Sonic touched a wall?
                bpl.s   .return                         ; if not, branch
                asl.w   #8,d1                           ; convert diff to wall into 8.8 fixed point for adjusting velocity
                addi.b  #$20,d0                         ; rotate angle by 45 degrees clockwise
                andi.b  #$C0,d0                         ; snap angle to nearest multiple of 90 degrees
                beq.s   .hitdown                        ; if Sonic is facing down, branch
                cmpi.b  #$40,d0                         ; is Sonic facing left?
                beq.s   .hitleft                        ; if yes, branch
                cmpi.b  #$80,d0                         ; is Sonic facing up?
                beq.s   .hitup                          ; if yes, branch

.hitright:                                       ; d0 is $C0, Sonic is facing right
                add.w   d1,obVelX(a0)                   ; adjust X-velocity to prevent Sonic from walking into the wall
                bset    #status_pushing_bit,obStatus(a0)  ; set pushing flag
                move.w  #0,obInertia(a0)                ; clear ground speed
                rts                                     ; return
; ===========================================================================

; loc_13060:
.hitup:                                       ; d0 is $80, Sonic is facing up
                sub.w   d1,obVelY(a0)                   ; adjust Y-velocity to prevent Sonic from walking into the ceiling
                rts
; ===========================================================================

; loc_13066:
.hitleft:                                       ; d0 is $40, Sonic is facing left
                sub.w   d1,obVelX(a0)                   ; adjust X-velocity to prevent Sonic from walking into the wall
                bset    #status_pushing_bit,obStatus(a0)  ; set pushing flag
                move.w  #0,obInertia(a0)                ; clear ground speed
                rts                                     ; return
; ===========================================================================

; loc_13078:
.hitdown:                                       ; d0 is $00, Sonic is facing down
                add.w   d1,obVelY(a0)                   ; adjust Y-velocity to prevent Sonic from walking into the floor

; locret_1307C:
.return:
                rts                                     ; return
; End of function Sonic_Move

; ---------------------------------------------------------------------------
; Subroutine handling Sonic's movement while moving to the left
; ---------------------------------------------------------------------------

Sonic_MoveLeft:
                move.w  obInertia(a0),d0                ; get Sonic's current ground speed
                beq.s   .still                          ; is Sonic standing still? if yes, branch
                bpl.s   .changeddirection               ; has Sonic changed direction? if yes, branch

; loc_13086:
.still:
                bset    #status_xflip_bit,obStatus(a0)  ; set X-flip flag (Sonic is facing left)
                bne.s   .alreadyleft                    ; if he already was facing left, branch
                bclr    #status_pushing_bit,obStatus(a0)  ; clear pushing flag
                move.b  #id_Run,obPrevAni(a0)           ; restart Sonic's animation

; loc_1309A:
.alreadyleft:
                sub.w   d5,d0                           ; subtract acceleration to current ground speed
                move.w  d6,d1                           ; get current top speed
                neg.w   d1                              ; negate it for left-side check
                cmp.w   d1,d0                           ; is new speed above max speed?
                bgt.s   .nocap                          ; if not, branch
                move.w  d1,d0                           ; cap Sonic's ground speed

; loc_130A6:
.nocap:
                move.w  d0,obInertia(a0)                ; set new ground speed
                move.b  #id_Walk,obAnim(a0)             ; use walking animation
                rts                                     ; return
; ===========================================================================

; loc_130B2:
.changeddirection:
                sub.w   d4,d0                           ; apply deceleration to current speed
                bcc.s   .stilldecel                     ; if still decelerating, branch
                move.w  #-$80,d0                        ; set minimum speed on sign change

; loc_130BA:
.stilldecel:
                move.w  d0,obInertia(a0)                ; set new ground speed
; d0 should not be used here, as it results in obInertia being
; partially overwritten! This causes Sonic's skidding animation
; to activate at differing speeds when he's moving left or right

; This oversight was only corrected in Knuckles in Sonic 2. Not
; even Sonic 3 & Knuckles itself had this fixed
                move.b  obAngle(a0),d0                  ; get Sonic's current angle (and partially overwrite d0...)
                addi.b  #$20,d0                         ; rotate by 45 degrees clockwise
                andi.b  #$C0,d0                         ; snap to nearest multiple of 90 degrees
                bne.s   .nostopping                     ; if Sonic is on a wall or ceiling, prevent stopping animation
                cmpi.w  #$400,d0                        ; has Sonic changed direction while being really fast?
                blt.s   .nostopping                     ; if not, don't play skidding animation/sound
                move.b  #id_Stop,obAnim(a0)             ; use "stopping" animation
                bclr    #status_xflip_bit,obStatus(a0)  ; clear X-flip flag (Sonic is now facing right)
                move.w  #sfx_Skid,d0                    ; set skidding sound
                jsr     (QueueSound2).l                 ; play it

; locret_130E8:
.nostopping:
                rts                                     ; return
; End of function Sonic_MoveLeft

; ---------------------------------------------------------------------------
; Subroutine handling Sonic's movement while moving to the right
; ---------------------------------------------------------------------------

Sonic_MoveRight:
                move.w  obInertia(a0),d0                ; get Sonic's current ground speed
                bmi.s   .changedirection                ; has Sonic changed direction? if yes, branch
                bclr    #status_xflip_bit,obStatus(a0)  ; clear X-flip flag (Sonic is facing right)
                beq.s   .alreadyright                   ; if he already was facing right, branch
                bclr    #status_pushing_bit,obStatus(a0)  ; clear pushing flag
                move.b  #id_Run,obPrevAni(a0)           ; restart Sonic's animation

; loc_13104:
.alreadyright:
                add.w   d5,d0                           ; add acceleration to current ground speed
                cmp.w   d6,d0                           ; is new speed above max speed?
                blt.s   .nocap                          ; if not, branch
                move.w  d6,d0                           ; cap Sonic's ground speed

; loc_1310C:
.nocap:
                move.w  d0,obInertia(a0)                ; set new ground speed
                move.b  #id_Walk,obAnim(a0)             ; use walking animation
                rts                                     ; return
; ===========================================================================

; loc_13118:
.changedirection:
                add.w   d4,d0                           ; apply deceleration to current speed
                bcc.s   .stilldecel                     ; if still decelerating, branch
                move.w  #$80,d0                         ; set minimum speed on sign change

; loc_13120:
.stilldecel:
                move.w  d0,obInertia(a0)                ; set new ground speed
; See explanation in Sonic_MoveLeft
                move.b  obAngle(a0),d0                  ; get Sonic's current angle (and partially overwrite d0...)
                addi.b  #$20,d0                         ; rotate by 45 degrees clockwise
                andi.b  #$C0,d0                         ; snap to nearest multiple of 90 degrees
                bne.s   .nostopping                     ; if Sonic is on a wall or ceiling, prevent stopping animation
                cmpi.w  #-$400,d0                       ; has Sonic changed direction while being really fast?
                bgt.s   .nostopping                     ; if not, don't play skidding animation/sound

                move.b  #id_Stop,obAnim(a0)             ; use "stopping" animation
                bset    #status_xflip_bit,obStatus(a0)  ; set X-flip flag (Sonic is now facing left)
                move.w  #sfx_Skid,d0                    ; set skidding sound
                jsr     (QueueSound2).l                 ; play it

; locret_1314E:
.nostopping:
                rts                                     ; return
; End of function Sonic_MoveRight

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to change Sonic's speed as he rolls
; ---------------------------------------------------------------------------
