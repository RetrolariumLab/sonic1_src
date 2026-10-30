; ===========================================================================
; ---------------------------------------------------------------------------
; Object 09 - Sonic the Hedgehog (in Special Stages)
; ---------------------------------------------------------------------------
sonss_maxspeed:   equ     $800                        ; Sonic's max speed when moving left/right
sonss_acceleration:   equ     $C                          ; Sonic's acceleration
sonss_deceleration:   equ     $40                         ; Sonic's deceleration
sonss_jumpspeed:   equ     $680                        ; Sonic's jump force
sonss_gravity:   equ     gravity-$E                  ; Sonic's gravity (=$2A, $E lower than main level gravity)
; ---------------------------------------------------------------------------

; Obj09:
SonicSpecial:
                tst.w   (v_debuguse).w                  ; is debug mode being used?
                beq.s   SonicSS_Normal                  ; if not, branch
                bsr.w   SS_FixCamera                    ; keep camera centered while in debug mode
                bra.w   DebugMode                       ; run debug mode instead of Sonic object
; ===========================================================================

; Obj09_Normal:
SonicSS_Normal:
                moveq   #0,d0                           ; clear d0
                move.b  obRoutine(a0),d0                ; get current routine number
                move.w  SonicSS_Index(pc,d0.w),d1       ; find appropriate entry in jump table
                jmp     SonicSS_Index(pc,d1.w)          ; jump there
; ===========================================================================
; Obj09_Index:
SonicSS_Index:   dc.w    SonicSS_Main-SonicSS_Index  ; 0 - object init
                dc.w    SonicSS_Control-SonicSS_Index   ; 2 - main mode
                dc.w    SonicSS_ExitStage-SonicSS_Index  ; 4 - rotate stage while exiting
                dc.w    SonicSS_ExitStage_Unused-SonicSS_Index  ; 6 - unreachable secondary exiting state

sonss_touchedblock_id:   equ     objoff_30                   ; ID of currently touched block (byte)
sonss_touchedblock_ram:   equ     objoff_32                   ; RAM address of currently touched block (longword)
sonss_timeout_updown:   equ     objoff_36                   ; timeout before an UP/DOWN block can be triggered again (byte)
sonss_timeout_r:   equ     objoff_37                   ; timeout before an R block can be triggered again (byte)
sonss_exittimer:   equ     objoff_38                   ; (unused) timer for the secondary exiting routine (word)
sonss_ghoststate:   equ     objoff_3A                   ; current solidity state of ghost blocks (byte)
; ===========================================================================

; Obj09_Main:
SonicSS_Main:                                       ; Routine 0
                addq.b  #2,obRoutine(a0)                ; set to SonicSS_Control
                move.b  #sonic_roll_height,obHeight(a0)  ; set rolling height
                move.b  #sonic_roll_width,obWidth(a0)   ; set rolling width
                move.l  #Map_Sonic,obMap(a0)            ; set mappings
                move.w  #ArtTile_Sonic,obGfx(a0)        ; set VRAM location
                move.b  #sprite_cam_field,obRender(a0)  ; set to playfield-positioned mode
                move.b  #0,obPriority(a0)               ; set sprite priority to top

                move.b  #id_Roll,obAnim(a0)             ; set to rolling animation
                bset    #status_rolling_bit,obStatus(a0)  ; set rolling flag
                bset    #status_in_air_bit,obStatus(a0)  ; set in-air flag
; ---------------------------------------------------------------------------

; Obj09_ChkDebug: SonicSS_ChkDebug:
SonicSS_Control:                                       ; Routine 2
                tst.w   (f_debugmode).w                 ; is debug mode cheat enabled?
                beq.s   SonicSS_NoDebug                 ; if not, branch
                btst    #bitB,(v_jpadpress1).w          ; is button B pressed?
                beq.s   SonicSS_NoDebug                 ; if not, branch
                move.w  #1,(v_debuguse).w               ; change Sonic into a ring

; Obj09_NoDebug:
SonicSS_NoDebug:
                move.b  #0,sonss_touchedblock_id(a0)    ; reset currently touched block to none (blank)

                moveq   #0,d0                           ; clear d0
                move.b  obStatus(a0),d0                 ; get Sonic's status flags
                andi.w  #status_in_air,d0               ; limit to "is in air" flag
                move.w  SonicSS_Modes(pc,d0.w),d1       ; use that as routine counter for the correct mode
                jsr     SonicSS_Modes(pc,d1.w)          ; jump to that mode

                jsr     (Sonic_LoadGfx).l               ; update Sonic's graphics if necessary (accessing Obj01)
                jmp     (DisplaySprite).l               ; display Sonic's sprites

; ===========================================================================
; ---------------------------------------------------------------------------
; Modes for controlling Sonic in Special Stages
; ---------------------------------------------------------------------------
; Obj09_Modes:
SonicSS_Modes:   dc.w    SonicSS_OnWall-SonicSS_Modes  ; 0 - while touching a block
                dc.w    SonicSS_InAir-SonicSS_Modes     ; 2 - while airborne
; ===========================================================================

; Obj09_OnWall:
SonicSS_OnWall:                                       ; While Sonic is touching a solid block
                bsr.w   SonicSS_Jump                    ; allow Sonic to jump from walls
                bsr.w   SonicSS_Move                    ; update position based on button inputs
                bsr.w   SonicSS_Fall                    ; apply gravity based on stage rotation
                bra.s   SonicSS_Display                 ; skip over
; ===========================================================================

; Obj09_InAir:
SonicSS_InAir:                                       ; While Sonic is airborne from jumping or falling
                bsr.w   SonicSS_JumpHeight_Unused       ; (disabled code) would have allowed to granularly control jump height
                bsr.w   SonicSS_Move                    ; update position based on button inputs
                bsr.w   SonicSS_Fall                    ; apply gravity based on stage rotation
; ---------------------------------------------------------------------------

; Obj09_Display:
SonicSS_Display:
                bsr.w   SonicSS_ChkItems_NonSolidActionBlock  ; check if items without collision were touched (rings etc.)
                bsr.w   SonicSS_ChkItems_SolidActionBlock  ; check if items with collision were touched (UP/DOWN blocks etc.)

                jsr     (SpeedToPos).l                  ; apply velocity and update position
                bsr.w   SS_FixCamera                    ; keep camera fixated on Sonic

                move.w  (v_ssangle).w,d0                ; get current stage rotation angle
                add.w   (v_ssrotate).w,d0               ; apply current rotation speed
                move.w  d0,(v_ssangle).w                ; save new angle

                jsr     (Sonic_Animate).l               ; animate Sonic (accessing Obj01)
                rts                                     ; return
; End of function SonicSS_Control

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to move Sonic in Special Stages based on D-Pad inputs
; ---------------------------------------------------------------------------

; Obj09_Move:
SonicSS_Move:
                btst    #bitL,(v_jpadhold2).w           ; is left being held?
                beq.s   SonicSS_ChkRight                ; if not, branch
                bsr.w   SonicSS_MoveLeft                ; apply left side movement updates

; Obj09_ChkRight:
SonicSS_ChkRight:
                btst    #bitR,(v_jpadhold2).w           ; is right being held?
                beq.s   SonicSS_CheckDpadLetGo          ; if not, branch
                bsr.w   SonicSS_MoveRight               ; apply right side movement updates
; ---------------------------------------------------------------------------

; This part is mostly identical to Sonic_CheckDpadLetGo in Obj01,
; except that the deceleration value is hardcoded

; loc_1BA78:
SonicSS_CheckDpadLetGo:
                move.b  (v_jpadhold2).w,d0              ; get held buttons
                andi.b  #btnL+btnR,d0                   ; is left or right being held?
                bne.s   SonicSS_AngleSpeed              ; if yes, branch (don't decrease speed)
                move.w  obInertia(a0),d0                ; get Sonic's current ground speed
                beq.s   SonicSS_AngleSpeed              ; is he standing still? if yes, branch
                bmi.s   .movingleftward                 ; is he moving to the left? if yes, branch
                subi.w  #sonss_acceleration,d0          ; reduce current rightward speed by acceleration
                bcc.s   .stillright                     ; if result is still to the right, branch
                move.w  #0,d0                           ; reset speed to zero on sign change

; loc_1BA94:
.stillright:
                move.w  d0,obInertia(a0)                ; set Sonic's new ground speed
                bra.s   SonicSS_AngleSpeed              ; skip over
; ===========================================================================

; loc_1BA9A:
.movingleftward:
                addi.w  #sonss_acceleration,d0          ; reduce current leftward speed by acceleration
                bcc.s   .stillleft                      ; if result is still to the left, branch
                move.w  #0,d0                           ; reset speed to zero on sign change

; loc_1BAA4:
.stillleft:
                move.w  d0,obInertia(a0)                ; set Sonic's new ground speed
; ---------------------------------------------------------------------------

; loc_1BAA8:
SonicSS_AngleSpeed:
                move.b  (v_ssangle).w,d0                ; get current angle of the special stage rotation
                addi.b  #$20,d0                         ; rotate angle by 45 degrees clockwise
                andi.b  #$C0,d0                         ; snap angle to nearest multiple of 90 degrees
                neg.b   d0                              ; negate for sine calculation
                jsr     (CalcSine).l                    ; get sine and cosine values based on angle
                muls.w  obInertia(a0),d1                ; multiply cosine value by current ground speed
                add.l   d1,obX(a0)                      ; add delta to X-velocity
                muls.w  obInertia(a0),d0                ; multiply sine value by current ground speed
                add.l   d0,obY(a0)                      ; add delta to Y-velocity

                movem.l d0-d1,-(sp)                     ; backup X and Y speed deltas
                move.l  obY(a0),d2                      ; get Sonic's current Y position
                move.l  obX(a0),d3                      ; get Sonic's current X position
                bsr.w   SonicSS_FindWall                ; has Sonic touched a (solid) block?
                beq.s   .nowall                         ; if not, branch
                movem.l (sp)+,d0-d1                     ; restore X and Y speed deltas
                sub.l   d1,obX(a0)                      ; undo delta addition to X-velocity
                sub.l   d0,obY(a0)                      ; undo delta addition to Y-velocity
                move.w  #0,obInertia(a0)                ; reset ground speed
                rts                                     ; return
; ===========================================================================

; loc_1BAF2:
.nowall:
                movem.l (sp)+,d0-d1                     ; restore stack
                rts                                     ; return
; End of function SonicSS_Move

; ---------------------------------------------------------------------------
; Subroutine handling Sonic's movement while moving to the left
; ---------------------------------------------------------------------------

; Obj09_MoveLeft:
SonicSS_MoveLeft:
                bset    #status_xflip_bit,obStatus(a0)  ; set X-flip flag (Sonic is facing left)

                move.w  obInertia(a0),d0                ; get Sonic's current ground speed
                beq.s   .accelerate                     ; is Sonic standing still? if yes, branch
                bpl.s   .changeddirection               ; has Sonic changed direction? if yes, branch

; loc_1BB06:
.accelerate:
                subi.w  #sonss_acceleration,d0          ; increase leftward speed
                cmpi.w  #-sonss_maxspeed,d0             ; is new speed above max speed?
                bgt.s   .nocap                          ; if not, branch
                move.w  #-sonss_maxspeed,d0             ; cap Sonic's ground speed

; loc_1BB14:
.nocap:
                move.w  d0,obInertia(a0)                ; set new ground speed
                rts
; ===========================================================================

; loc_1BB1A:
.changeddirection:
                subi.w  #sonss_deceleration,d0          ; apply deceleration to current speed

; Unknown, removed extra functionality. In Obj01, this part gives
; a tiny speed boost on a sign change, but here it does nothing
                bcc.s   .stilldecel                     ; if still decelerating, branch
                nop                                     ; no operation

; loc_1BB22:
.stilldecel:
                move.w  d0,obInertia(a0)                ; set new ground speed
                rts                                     ; return
; End of function SonicSS_MoveLeft

; ---------------------------------------------------------------------------
; Subroutine handling Sonic's movement while moving to the right
; ---------------------------------------------------------------------------

; Obj09_MoveRight:
SonicSS_MoveRight:
                bclr    #status_xflip_bit,obStatus(a0)  ; clear X-flip flag (Sonic is facing right)

                move.w  obInertia(a0),d0                ; get Sonic's current ground speed
                bmi.s   .changedirection                ; has Sonic changed direction? if yes, branch
                addi.w  #sonss_acceleration,d0          ; increase rightward speed
                cmpi.w  #sonss_maxspeed,d0              ; is new speed above max speed?
                blt.s   .nocap                          ; if not, branch
                move.w  #sonss_maxspeed,d0              ; cap Sonic's ground speed

; loc_1BB42:
.nocap:
                move.w  d0,obInertia(a0)                ; set new ground speed
                bra.s   .return                         ; skip over
; ===========================================================================

; loc_1BB48:
.changedirection:
                addi.w  #sonss_deceleration,d0          ; apply deceleration to current speed

; Unknown, removed extra functionality. In Obj01, this part gives
; a tiny speed boost on a sign change, but here it does nothing
                bcc.s   .stilldecel                     ; if still decelerating, branch
                nop                                     ; no operation

; loc_1BB50:
.stilldecel:
                move.w  d0,obInertia(a0)                ; set new ground speed

; locret_1BB54:
.return:
                rts                                     ; return
; End of function SonicSS_MoveRight

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine allowing Sonic to jump in Special Stages
; ---------------------------------------------------------------------------

; Obj09_Jump:
SonicSS_Jump:
                move.b  (v_jpadpress2).w,d0             ; get pressed buttons
                andi.b  #btnABC,d0                      ; is A, B or C pressed?
                beq.s   SonicSS_NoJump                  ; if not, branch

                move.b  (v_ssangle).w,d0                ; get current angle of the special stage rotation
                andi.b  #$FC,d0                         ; snap to nearest multiple of 4 to match stage rotation
                neg.b   d0                              ; negate for sine calculation
                subi.b  #$40,d0                         ; rotate it perpendicularly for jump trajectory
                jsr     (CalcSine).l                    ; get sine and cosine values based on angle
                muls.w  #sonss_jumpspeed,d1             ; apply jump force to the cosine angle
                asr.l   #8,d1                           ; shift result to lower word
                move.w  d1,obVelX(a0)                   ; set result as new X speed
                muls.w  #sonss_jumpspeed,d0             ; apply jump force to the sine angle
                asr.l   #8,d0                           ; shift result to lower word
                move.w  d0,obVelY(a0)                   ; set result as new Y speed

                bset    #status_in_air_bit,obStatus(a0)  ; set in-air flag

                move.w  #sfx_Jump,d0                    ; set jump sound
                jsr     (QueueSound2).l                 ; play jumping sound

; Obj09_NoJump:
SonicSS_NoJump:
                rts                                     ; return
; End of function SonicSS_Jump

; ===========================================================================
; ---------------------------------------------------------------------------
; Unused subroutine to limit Sonic's upward vertical speed depending on
; how long the jump button was held after the initial jump. This likely got
; removed as it doesn't work (it doesn't account for the stage rotation)
; ---------------------------------------------------------------------------

; nullsub_2:
SonicSS_JumpHeight_Unused:
                rts                                     ; immediately return
; ---------------------------------------------------------------------------

; dead code
                move.w  #-$400,d1                       ; set maximum jump speed
                cmp.w   obVelY(a0),d1                   ; is Sonic already below the cap?
                ble.s   .return                         ; if yes, branch
                move.b  (v_jpadhold2).w,d0              ; get held buttons
                andi.b  #btnABC,d0                      ; is A, B, or C being held?
                bne.s   .return                         ; if yes, branch
                move.w  d1,obVelY(a0)                   ; cap vertical speed if not holding ABC

; locret_1BBB4:
.return:
                rts                                     ; return
; End of function SonicSS_JumpHeight

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to fix the camera on Sonic's position (special stage)
; ---------------------------------------------------------------------------

SS_FixCamera:
                move.w  obY(a0),d2                      ; get Sonic's current Y position

                move.w  obX(a0),d3                      ; get Sonic's current X position
                move.w  (v_screenposx).w,d0             ; get current horizontal camera position
                subi.w  #320/2,d3                       ; subtract half screen width from Sonic's X position
                bcs.s   .updatevertical                 ; did result underflow? if yes, branch
                sub.w   d3,d0                           ; subtract result from horizontal camera positon
                sub.w   d0,(v_screenposx).w             ; set result as new horizontal camera position

; loc_1BBCE:
.updatevertical:
                move.w  (v_screenposy).w,d0             ; get current vertical camera position
                subi.w  #224/2,d2                       ; subtract half screen height from Sonic's Y position
                bcs.s   .return                         ; did result underflow? if yes, branch
                sub.w   d2,d0                           ; subtract result from vertical camera positon
                sub.w   d0,(v_screenposy).w             ; set result as new vertical camera position

; locret_1BBDE:
.return:
                rts                                     ; return
; End of function SS_FixCamera

; ===========================================================================
; ---------------------------------------------------------------------------
; Sonic while exiting a Special Stage (make it spin increasingly faster)
; ---------------------------------------------------------------------------

; Obj09_ExitStage:
SonicSS_ExitStage:
                addi.w  #ss_rotatespeed,(v_ssrotate).w  ; increase spin speed during exit sequence
                cmpi.w  #$60*ss_rotatespeed,(v_ssrotate).w  ; is the stage spinning fast enough? ($1800)
                bne.s   .noexit                         ; if not, branch
                move.b  #id_Level,(v_gamemode).w        ; change game mode to Level to trigger exit in main loop

; loc_1BBF4:
.noexit:                                       ; Impossible condition, see notes below
                cmpi.w  #2*($60*ss_rotatespeed),(v_ssrotate).w  ; is stage spinning twice as fast as exit trigger above? ($3000)
                blt.s   .noexit2                        ; if not, branch
                move.w  #0,(v_ssrotate).w               ; stop stage rotation
                move.w  #$4000,(v_ssangle).w            ; keep rotation fixed to 90 degrees clockwise
                addq.b  #2,obRoutine(a0)                ; advance to "SonicSS_ExitStage_Unused"
                move.w  #60,sonss_exittimer(a0)         ; set delay timer in there to one second

; loc_1BC12:
.noexit2:
                move.w  (v_ssangle).w,d0                ; get current stage rotation angle
                add.w   (v_ssrotate).w,d0               ; apply current rotation speed
                move.w  d0,(v_ssangle).w                ; save new angle

                jsr     (Sonic_Animate).l               ; animate Sonic (accessing Obj01)
                jsr     (Sonic_LoadGfx).l               ; update Sonic's graphics if necessary (accessing Obj01)
                bsr.w   SS_FixCamera                    ; keep camera centered on Sonic
                jmp     (DisplaySprite).l               ; display Sonic's sprites
; End of function SonicSS_ExitStage

; ---------------------------------------------------------------------------
; Unused secondary exiting mode. This would technically be triggered once
; the stage is spinning fast enough during the exiting sequence above, but
; this will in practice never be the case before the stage is forcibly exited
; in the main game mode loop, as the code above already changes the game mode
; before it has any chance to spin fast enough. It's likely that this was a
; leftover from the prototype, where the stage would restart indefinitely
; ---------------------------------------------------------------------------

; Obj09_Exit2: SonicSS_Exit2:
SonicSS_ExitStage_Unused:
                subq.w  #1,sonss_exittimer(a0)          ; decrement remaining delay
                bne.s   .timeremaining                  ; if time remains, branch
                move.b  #id_Level,(v_gamemode).w        ; change game mode to Level to trigger exit in main loop

; loc_1BC40:
.timeremaining:
                jsr     (Sonic_Animate).l               ; animate Sonic (accessing Obj01)
                jsr     (Sonic_LoadGfx).l               ; update Sonic's graphics if necessary (accessing Obj01)
                bsr.w   SS_FixCamera                    ; keep camera centered on Sonic
                jmp     (DisplaySprite).l               ; display Sonic's sprites
; End of function SonicSS_ExitStage_Unused

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to apply gravity to Sonic based on the current layout rotation
; ---------------------------------------------------------------------------

; Obj09_Fall:
SonicSS_Fall:
                move.l  obY(a0),d2                      ; get Sonic's current Y position
                move.l  obX(a0),d3                      ; get Sonic's current X position
                move.b  (v_ssangle).w,d0                ; get current angle of the special stage rotation
                andi.b  #$FC,d0                         ; snap to nearest multiple of 4 to match stage rotation
                jsr     (CalcSine).l                    ; get sine and cosine values based on angle

                move.w  obVelX(a0),d4                   ; get Sonic's current X velocity
                ext.l   d4                              ; extend X velocity to longword
                asl.l   #8,d4                           ; shift it to upper word
                muls.w  #sonss_gravity,d0               ; multiply sine value by gravitational force
                add.l   d4,d0                           ; add shifted X velocity to it
                move.w  obVelY(a0),d4                   ; get Sonic's current Y velocity
                ext.l   d4                              ; extend Y velocity to longword
                asl.l   #8,d4                           ; shift it to upper word
                muls.w  #sonss_gravity,d1               ; multiply cosine value by gravitational force
                add.l   d4,d1                           ; add shifted Y velocity to it

                add.l   d0,d3                           ; add new X delta to target X position
                bsr.w   SonicSS_FindWall                ; check if the new result would make Sonic clip through a left/right wall
                beq.s   .noleftrightwall                ; if not, branch
                sub.l   d0,d3                           ; undo X delta addition
                moveq   #0,d0                           ; clear d0
                move.w  d0,obVelX(a0)                   ; stop Sonic's horizonal momentum
                bclr    #status_in_air_bit,obStatus(a0)  ; clear in-air flag

                add.l   d1,d2                           ; add new Y delta to target Y position
                bsr.w   SonicSS_FindWall                ; check if the new result would make Sonic clip through a floor wall
                beq.s   .nofloor                        ; if not, branch
                sub.l   d1,d2                           ; undo Y delta addition
                moveq   #0,d1                           ; clear d1
                move.w  d1,obVelY(a0)                   ; stop Sonic's vertical momentum
                rts                                     ; return
; ===========================================================================

; loc_1BCB0:
.noleftrightwall:
                add.l   d1,d2                           ; add new Y delta to target Y position
                bsr.w   SonicSS_FindWall                ; check if the new result would make Sonic clip through a floor wall
                beq.s   .airborne                       ; if not, branch
                sub.l   d1,d2                           ; undo Y delta addition
                moveq   #0,d1                           ; clear d1
                move.w  d1,obVelY(a0)                   ; stop Sonic's vertical momentum
                bclr    #status_in_air_bit,obStatus(a0)  ; clear in-air flag

; loc_1BCC6:
.nofloor:
                asr.l   #8,d0                           ; shift new X speed back to word range
                asr.l   #8,d1                           ; shift new Y speed back to word range
                move.w  d0,obVelX(a0)                   ; set new X velocity
                move.w  d1,obVelY(a0)                   ; set new Y velocity
                rts                                     ; return
; ===========================================================================

; loc_1BCD4:
.airborne:
                asr.l   #8,d0                           ; shift new X speed back to word range
                asr.l   #8,d1                           ; shift new Y speed back to word range
                move.w  d0,obVelX(a0)                   ; set new X velocity
                move.w  d1,obVelY(a0)                   ; set new Y velocity
                bset    #status_in_air_bit,obStatus(a0)  ; set in-air flag
                rts                                     ; return
; End of function SonicSS_Fall

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to detect a Special Stage wall at a given position
;
; input:
; d2 = y position (including subpixel)
; d3 = x position (including subpixel)
;
; output:
; d4 = id of wall or item
; d5 = flag: 0 = no collision (e.g. rings); -1 = collision with solid wall
; ---------------------------------------------------------------------------

; sub_1BCE8:
