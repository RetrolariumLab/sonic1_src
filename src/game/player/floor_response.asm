Sonic_Floor:
                move.w  obVelX(a0),d1                   ; get current horizontal speed
                move.w  obVelY(a0),d2                   ; get current vertical speed
                jsr     (CalcAngle).l                   ; calculate arctan based on Sonic's current fall direction
                move.b  d0,(v_unused3).w                ; (unused) store basic angle
                subi.b  #$20,d0                         ; rotate 45 degrees counterclockwise
                move.b  d0,(v_unused4).w                ; (unused) store -45 degrees angle
                andi.b  #$C0,d0                         ; snap to nearest multiple of 90 degrees
                move.b  d0,(v_unused5).w                ; (unused) store snapped angle

                cmpi.b  #$40,d0                         ; is main movement direction to the left?
                beq.w   Sonic_FloorLeft                 ; if yes, branch
                cmpi.b  #$80,d0                         ; is main movement direction upward?
                beq.w   Sonic_FloorUp                   ; if yes, branch
                cmpi.b  #$C0,d0                         ; is main movement direction to the right?
                beq.w   Sonic_FloorRight                ; if yes, branch
; otherwise, d0 is $00 (fall-through...)

; ---------------------------------------------------------------------------
; When Sonic is in-air with his main momentum being downward
; ---------------------------------------------------------------------------

Sonic_FloorDown:
                bsr.w   Sonic_FindWallLeft_Quick_UsePos  ; check Sonic's distance to nearest left wall
                tst.w   d1                              ; is Sonic grazing a wall to the left while falling?
                bpl.s   .noleftgraze                    ; if not, branch
                sub.w   d1,obX(a0)                      ; align Sonic with the wall
                move.w  #0,obVelX(a0)                   ; clear horizontal speed

; loc_135F0:
.noleftgraze:
                bsr.w   Sonic_FindWallRight_Quick_UsePos  ; check Sonic's distance to nearest right wall
                tst.w   d1                              ; is Sonic grazing a wall to the right while falling?
                bpl.s   .norightgraze                   ; if not, branch
                add.w   d1,obX(a0)                      ; align Sonic with the wall
                move.w  #0,obVelX(a0)                   ; clear horizontal speed

; loc_13602:
.norightgraze:
                bsr.w   Sonic_FindFloor                 ; find distance between Sonic and floor
                move.b  d1,(v_unused6).w                ; (unused) store distance to floor
                tst.w   d1                              ; has Sonic touched the floor again?
                bpl.s   .return                         ; if not, branch
                move.b  obVelY(a0),d2                   ; get Sonic's fall speed at the time of impact (upper byte only, pixel delta)
                addq.b  #8,d2                           ; increase it by one tile
                neg.b   d2                              ; mirror it
                cmp.b   d2,d1                           ; is result bigger than distance to floor?
                bge.s   .landed                         ; if yes, branch
                cmp.b   d2,d0                           ; is result bigger than distance to floor? (sloped variant)
                blt.s   .return                         ; if not, branch

; loc_1361E:
.landed:
                add.w   d1,obY(a0)                      ; fix Sonic to floor
                move.b  d3,obAngle(a0)                  ; update Sonic's angle for the landed-on floor
                bsr.w   Sonic_ResetOnFloor              ; reset various flags and states back to standing state
                move.b  #id_Walk,obAnim(a0)             ; set to "walking" animation

                move.b  d3,d0                           ; get landing angle
                addi.b  #$20,d0                         ; rotate it by 45 degrees clockwise
                andi.b  #$40,d0                         ; are we landing on a steep slope?
                bne.s   .steepslope                     ; if yes, branch
                move.b  d3,d0                           ; get landing angle
                addi.b  #$10,d0                         ; rotate it by 22.5 degrees clockwise
                andi.b  #$20,d0                         ; are we landing on a shallow slope?
                beq.s   .flatsurface                    ; if not, branch
                asr.w   obVelY(a0)                      ; halve Sonic's vertical speed when landing on a shallow slope
                bra.s   .noslopecap                     ; skip over
; ===========================================================================

; loc_1364E:
.flatsurface:
                move.w  #0,obVelY(a0)                   ; completely clear Sonic's vertical speed when landing on a flat surface
                move.w  obVelX(a0),obInertia(a0)        ; convert in-air horizontal speed to ground speed when landing
                rts                                     ; return
; ===========================================================================

; loc_1365C:
.steepslope:
                move.w  #0,obVelX(a0)                   ; completely clear Sonic's horizontal speed when landing on a steep slope
                cmpi.w  #$FC0,obVelY(a0)                ; is Sonic's fall speed almost at the maximum screen shift speed?
                ble.s   .noslopecap                     ; if not, branch
                move.w  #$FC0,obVelY(a0)                ; otherwise, cap it to not exceed maximum screen shift speed

; loc_13670:
.noslopecap:
                move.w  obVelY(a0),obInertia(a0)        ; convert in-air vertical speed to ground speed when landing
                tst.b   d3                              ; is slope (when viewed left-to-right in game) ascending?
                bpl.s   .return                         ; if not, branch
                neg.w   obInertia(a0)                   ; negate converted ground speed for ascending slopes

; locret_1367E:
.return:
                rts                                     ; return
; End of function Sonic_FloorDown

; ---------------------------------------------------------------------------
; When Sonic is in-air with his main momentum being to the left
; ---------------------------------------------------------------------------

; loc_13680:
Sonic_FloorLeft:
                bsr.w   Sonic_FindWallLeft_Quick_UsePos  ; check Sonic's distance to nearest left wall
                tst.w   d1                              ; is Sonic grazing a wall to the left while falling?
                bpl.s   .noleftgraze                    ; if not, branch
                sub.w   d1,obX(a0)                      ; align Sonic to the wall
                move.w  #0,obVelX(a0)                   ; clear horizontal speed
                move.w  obVelY(a0),obInertia(a0)        ; convert in-air vertical speed to ground speed when landing
                rts                                     ; return
; ===========================================================================

; loc_1369A:
.noleftgraze:
                bsr.w   Sonic_FindCeiling               ; check if Sonic's distance to the ceiling
                tst.w   d1                              ; is Sonic touching the ceiling?
                bpl.s   .noceiling                      ; if not, branch
                sub.w   d1,obY(a0)                      ; align Sonic with the ceiling
                tst.w   obVelY(a0)                      ; is vertical speed positive? (going down)
                bpl.s   .noyspeedreset                  ; if yes, branch
                move.w  #0,obVelY(a0)                   ; if going up, reset it to zero

; locret_136B2:
.noyspeedreset:
                rts                                     ; return
; ===========================================================================

; loc_136B4:
.noceiling:
                tst.w   obVelY(a0)                      ; is Sonic going up?
                bmi.s   .return                         ; if yes, branch
                bsr.w   Sonic_FindFloor                 ; find Sonic's distance to floor
                tst.w   d1                              ; has Sonic touched the floor?
                bpl.s   .return                         ; if not, branch
                add.w   d1,obY(a0)                      ; align Sonic with floor
                move.b  d3,obAngle(a0)                  ; update Sonic's angle for the landed-on floor
                bsr.w   Sonic_ResetOnFloor              ; reset various flags and states back to standing state
                move.b  #id_Walk,obAnim(a0)             ; set to "walking" animation
                move.w  #0,obVelY(a0)                   ; completely clear Sonic's vertical speed when landing on a flat surface
                move.w  obVelX(a0),obInertia(a0)        ; convert in-air horizontal speed to ground speed when landing

; locret_136E0:
.return:
                rts                                     ; return
; End of function Sonic_FloorLeft

; ---------------------------------------------------------------------------
; When Sonic is in-air with his main momentum being upward
; ---------------------------------------------------------------------------

; loc_136E2:
Sonic_FloorUp:
                bsr.w   Sonic_FindWallLeft_Quick_UsePos  ; check Sonic's distance to nearest left wall
                tst.w   d1                              ; is Sonic grazing a wall to the left while going up?
                bpl.s   .noleftgraze                    ; if not, branch
                sub.w   d1,obX(a0)                      ; align Sonic to wall
                move.w  #0,obVelX(a0)                   ; clear horizontal speed

; loc_136F4:
.noleftgraze:
                bsr.w   Sonic_FindWallRight_Quick_UsePos  ; check Sonic's distance to nearest right wall
                tst.w   d1                              ; is Sonic grazing a wall to the right while going up?
                bpl.s   .norightgraze                   ; if not, branch
                add.w   d1,obX(a0)                      ; align Sonic to wall
                move.w  #0,obVelX(a0)                   ; clear horizontal speed

; loc_13706:
.norightgraze:
                bsr.w   Sonic_FindCeiling               ; find Sonic's distance to the ceiling
                tst.w   d1                              ; is Sonic touching the ceiling?
                bpl.s   .return                         ; if not, branch
                sub.w   d1,obY(a0)                      ; align Sonic with the ceiling
                move.b  d3,d0                           ; get Sonic's landing angle
                addi.b  #$20,d0                         ; rotate it by 45 degrees
                andi.b  #$40,d0                         ; are we bumping against an angled ceiling?
                bne.s   .angledceiling                  ; if yes, branch
                move.w  #0,obVelY(a0)                   ; clear vertical speed when bumping against a flat ceiling
                rts                                     ; return
; ===========================================================================

; loc_13726:
.angledceiling:
                move.b  d3,obAngle(a0)                  ; update Sonic's angle for the landed-on floor
                bsr.w   Sonic_ResetOnFloor              ; reset various flags and states back to standing state
                move.w  obVelY(a0),obInertia(a0)        ; convert in-air vertical speed to ground speed when landing
                tst.b   d3                              ; is slope (when viewed left-to-right in game) ascending?
                bpl.s   .return                         ; if not, branch
                neg.w   obInertia(a0)                   ; negate converted ground speed for ascending slopes

; locret_1373C:
.return:
                rts                                     ; return
; End of function Sonic_FloorUp

; ---------------------------------------------------------------------------
; When Sonic is in-air with his main momentum being towards the right
; ---------------------------------------------------------------------------

; loc_1373E:
Sonic_FloorRight:
                bsr.w   Sonic_FindWallRight_Quick_UsePos  ; check Sonic's distance to nearest right wall
                tst.w   d1                              ; is Sonic grazing a wall to the right while falling?
                bpl.s   .norightgraze                   ; if not, branch
                add.w   d1,obX(a0)                      ; align Sonic to the wall
                move.w  #0,obVelX(a0)                   ; clear horizontal speed
                move.w  obVelY(a0),obInertia(a0)        ; convert in-air vertical speed to ground speed when landing
                rts                                     ; return
; ===========================================================================

; loc_13758:
.norightgraze:
                bsr.w   Sonic_FindCeiling               ; check if Sonic's distance to the ceiling
                tst.w   d1                              ; is Sonic touching the ceiling?
                bpl.s   .noceiling                      ; if not, branch
                sub.w   d1,obY(a0)                      ; align Sonic with the ceiling
                tst.w   obVelY(a0)                      ; is vertical speed positive? (going down)
                bpl.s   .noyspeedreset                  ; if yes, branch
                move.w  #0,obVelY(a0)                   ; if going up, reset it to zero

; locret_13770:
.noyspeedreset:
                rts                                     ; return
; ===========================================================================

; loc_13772:
.noceiling:
                tst.w   obVelY(a0)                      ; is Sonic going up?
                bmi.s   .return                         ; if yes, branch
                bsr.w   Sonic_FindFloor                 ; find Sonic's distance to floor
                tst.w   d1                              ; has Sonic touched the floor?
                bpl.s   .return                         ; if not, branch
                add.w   d1,obY(a0)                      ; align Sonic with floor
                move.b  d3,obAngle(a0)                  ; update Sonic's angle for the landed-on floor
                bsr.w   Sonic_ResetOnFloor              ; reset various flags and states back to standing state
                move.b  #id_Walk,obAnim(a0)             ; set to "walking" animation
                move.w  #0,obVelY(a0)                   ; completely clear Sonic's vertical speed when landing on a flat surface
                move.w  obVelX(a0),obInertia(a0)        ; convert in-air horizontal speed to ground speed when landing

; locret_1379E:
.return:
                rts                                     ; return
; End of function Sonic_FloorRight
; End of function Sonic_Floor (as a whole)

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to reset Sonic's mode when he lands on the floor
; ---------------------------------------------------------------------------

Sonic_ResetOnFloor:
                btst    #status_rolljumping_bit,obStatus(a0)  ; is Sonic roll-jumping?
                beq.s   .notrolljump                    ; if not, skip
                nop                                     ; unknown removed code
                nop                                     ; (some extra feature of the roll-jump lock?)
                nop                                     ; (we will never know...)

; loc_137AE:
.notrolljump:
                bclr    #status_pushing_bit,obStatus(a0)  ; clear push flag
                bclr    #status_in_air_bit,obStatus(a0)  ; clear in-air flag
                bclr    #status_rolljumping_bit,obStatus(a0)  ; clear roll-jump flag
                btst    #status_rolling_bit,obStatus(a0)  ; check if Sonic is in a ball state
                beq.s   .notball                        ; if not, skip
                bclr    #status_rolling_bit,obStatus(a0)  ; clear ball flag
                move.b  #sonic_height,obHeight(a0)      ; set Sonic's hitbox height to standing
                move.b  #sonic_width,obWidth(a0)        ; set Sonic's hitbox width to standing
                move.b  #id_Walk,obAnim(a0)             ; use running/walking animation
                subq.w  #sonic_height-sonic_roll_height,obY(a0)  ; raise Sonic up 5 pixels so he's not inside the ground

; loc_137E4:
.notball:
                move.b  #0,jumping(a0)                  ; clear jump flag
                move.w  #0,(v_itembonus).w              ; clear enemy score chain
                rts                                     ; return
; End of function Sonic_ResetOnFloor

; ===========================================================================
; ---------------------------------------------------------------------------
; Sonic when he gets hurt
; ---------------------------------------------------------------------------

; Obj01_Hurt:
