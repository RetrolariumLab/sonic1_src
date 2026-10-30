EggmanCylinder_Delete:
                jmp     (DeleteObject).l
; ===========================================================================

EggmanCylinder:
                moveq   #0,d0
                move.b  obRoutine(a0),d0                ; copy object routine
                move.w  EggmanCylinder_Index(pc,d0.w),d0  ; use the object routine index and EggmanCylinder_Index to calculate our offset
                jmp     EggmanCylinder_Index(pc,d0.w)   ; jump into the table and use our offset to pick a routine in the index to go to
; ===========================================================================
EggmanCylinder_Index:
                dc.w    EggmanCylinder_Main-EggmanCylinder_Index
                dc.w    EggmanCylinder_Action-EggmanCylinder_Index
                dc.w    EggmanCylinder_Move-EggmanCylinder_Index

EggmanCylinder_HasEggman:   equ     objoff_30                   ; offset used to denote which cylinder in the attacking pair Eggman is hiding in (-1 = Eggman present, 0 = decoy cylinder)
EggmanCylinder_BaseY:   equ     objoff_38                   ; offset used for the base Y position as a fixed-point value
EggmanCylinder_Displacement:   equ     objoff_3C                   ; offset used for a vertical displacement for the cylinder
EggmanCylinder_FracDisplace:   equ     objoff_3E                   ; offset that gets written to when doing vertical displacement, ends up being sub pixel values
; ===========================================================================

EggmanCylinder_PosData:
                dc.w    boss_fz_x+$80,  boss_fz_y+$110
                dc.w    boss_fz_x+$100, boss_fz_y+$110
                dc.w    boss_fz_x+$40,  boss_fz_y-$50
                dc.w    boss_fz_x+$C0,  boss_fz_y-$50
; ===========================================================================

EggmanCylinder_Main:                                       ; Routine 0
                lea     EggmanCylinder_PosData(pc),a1   ; load cylinder position data table
                moveq   #0,d0
                move.b  obSubtype(a0),d0                ; load cylinder number (set when boss was loaded)
                add.w   d0,d0                           ; double it to set up word based indexing
                adda.w  d0,a1                           ; add to position data table to find proper cylinder position
                move.b  #sprite_cam_field,obRender(a0)  ; set render bits
                bset    #sprite_rendered_bit,obRender(a0)
                bset    #sprite_customheight_bit,obRender(a0)  ; set to use actual object height rather than default of 32 pixels
                move.w  #ArtTile_FZ_Boss,obGfx(a0)      ; load art and mappings
                move.l  #Map_EggCyl,obMap(a0)
                move.w  (a1)+,obX(a0)                   ; copy position and increment
                move.w  (a1),obY(a0)                    ; copy Y and don't increment yet
                move.w  (a1)+,EggmanCylinder_BaseY(a0)  ; store same Y as a base position and increment
; These are likely the result of the developers fumbling obWidth and
; obActWidth, which wasn't completely fixed until REV01
                move.b  #64/2,obHeight(a0)
                move.b  #192/2,obWidth(a0)
                move.b  #64/2,obActWid(a0)
                move.b  #192/2,obHeight(a0)
                move.b  #3,obPriority(a0)               ; set priority
                addq.b  #2,obRoutine(a0)                ; increment routine

; loc_1A4CE:
EggmanCylinder_Action:                                       ; Routine 2
                cmpi.b  #2,obSubtype(a0)                ; is this a floor cylinder?
                ble.s   .checkAction                    ; if yes, branch
                bset    #sprite_yflip_bit,obRender(a0)  ; ceiling cylinder, flip Y

; loc_1A4DC:
.checkAction:
                clr.l   EggmanCylinder_Displacement(a0)  ; clear vertical displacement offset
                tst.b   BossFinal_ChildCmd(a0)          ; are we ready to move?
                beq.s   EggmanCylinder_UpdatePos        ; if not, branch ahead so we don't start moving
                addq.b  #2,obRoutine(a0)

; loc_1A4EA:
EggmanCylinder_UpdatePos:
                move.l  EggmanCylinder_Displacement(a0),d0  ; copy how far we have traveled
                move.l  EggmanCylinder_BaseY(a0),d1     ; copy base position
                add.l   d0,d1                           ; current position
                swap    d1                              ; swap so that base pixels are in lower word
                move.w  d1,obY(a0)                      ; set base pixels to object Y
                cmpi.b  #4,obRoutine(a0)                ; are we ready to go to the move routine?
                bne.s   .calcFloorFrame                 ; if not, branch
                tst.w   EggmanCylinder_HasEggman(a0)    ; is this cylinder the one holding Eggman? -1 yes, 0 is decoy
                bpl.s   .calcFloorFrame                 ; if not (0), branch
                moveq   #-$A,d0                         ; floor cylinder, move 10 pixels up from origin
                cmpi.b  #2,obSubtype(a0)                ; is it a floor cylinder?
                ble.s   .setPosition                    ; if yes (0 or 2) branch
                moveq   #$E,d0                          ; must be ceiling, move 14 pixels down

; loc_1A514:
.setPosition:
                add.w   d0,d1                           ; add offset + cylinder position
                movea.l BossFinal_ParentObj(a0),a1      ; copy Eggman object address
                move.w  d1,obY(a1)                      ; write into Eggman's Y and X (now Eggman's code in BossFinal_Eggman_Crush will run and set his hitbox and check for his collision)
                move.w  obX(a0),obX(a1)

; loc_1A524:
.calcFloorFrame:
                move.w  #64/2+sonic_solid_width,d1      ; set up collision and jsr to SolidObject to calculate hitbox
                move.w  #192/2,d2
                move.w  #194/2,d3
                move.w  obX(a0),d4
                jsr     (SolidObject).l
                moveq   #0,d0                           ; set initial sprite frame
                move.w  EggmanCylinder_Displacement(a0),d1  ; copy the pixel half only (3C to 3D offset) first runthrough this is 0 due to the clr.l above
                bpl.s   .calcCeilingFrame               ; if positive (ceiling) branch
                neg.w   d1                              ; negative (floor) so make it positive
                subq.w  #8,d1                           ; have we traveled 8 pixels yet?
                bcs.s   .checkOffscreen                 ; no (there was a carry) so branch
                addq.b  #1,d0                           ; increment sprite frame
                asr.w   #4,d1                           ; divide by 16
                add.w   d1,d0                           ; add sprite frame to division result (this means every 16 pixels a new frame is loaded, EXCEPT after the first 8 pixels a new frame is loaded)
                bra.s   .checkOffscreen
; ===========================================================================

; loc_1A550:
.calcCeilingFrame:
                subi.w  #$27,d1                         ; have we traveled 39 pixels yet?
                bcs.s   .checkOffscreen                 ; no (there was a carry) so branch
                addq.b  #1,d0                           ; increment sprite frame
                asr.w   #4,d1                           ; divide by 16
                add.w   d1,d0                           ; add sprite frame to division result (this means every 16 pixels a new frame is loaded, EXCEPT after the first 39 pixels a new frame is loaded)

; loc_1A55C:
.checkOffscreen:
                move.b  d0,obFrame(a0)                  ; set sprite frame
                move.w  (v_player+obX).w,d0             ; copy Sonic's X
                sub.w   obX(a0),d0                      ; subtract Sonic's X and cylinder X
                bmi.s   .exit                           ; Sonic is left of cylinder, branch
                subi.w  #$140,d0                        ; subtract 320 (a screen's width) from Sonic's position
                bmi.s   .exit                           ; Sonic is still within a screen's width to the cylinder, branch
                tst.b   obRender(a0)                    ; is the cylinder currently on screen?
                bpl.w   EggmanCylinder_Delete           ; if not, branch (you can't move back left post-Eggman defeat so this is a guaranteed way to delete the cylinders)

; loc_1A578:
.exit:
                jmp     (DisplaySprite).l
; ===========================================================================

; loc_1A57E:
EggmanCylinder_Move:                                       ; Routine 4
                moveq   #0,d0
                move.b  obSubtype(a0),d0
                move.w  EggmanCylinder_Move_Index(pc,d0.w),d0  ; use the object subtype and Move_Index to calculate our offset and determine top or bottom cylinder
                jsr     EggmanCylinder_Move_Index(pc,d0.w)  ; jump (but return) into the table and use our offset to pick a routine
                bra.w   EggmanCylinder_UpdatePos        ; when done, go and update cylinder position
; ===========================================================================
EggmanCylinder_Move_Index:
                dc.w    EggmanCylinder_Bottom-EggmanCylinder_Move_Index  ; bottom left
                dc.w    EggmanCylinder_Bottom-EggmanCylinder_Move_Index  ; bottom right
                dc.w    EggmanCylinder_Top-EggmanCylinder_Move_Index  ; top left
                dc.w    EggmanCylinder_Top-EggmanCylinder_Move_Index  ; top right
; ===========================================================================

; loc_1A598:
EggmanCylinder_Bottom:
                tst.b   BossFinal_ChildCmd(a0)          ; are we currently attacking?
                bne.s   .extend                         ; if yes, branch
                movea.l BossFinal_ParentObj(a0),a1      ; copy Eggman's address
                tst.b   obBossHits(a1)                  ; are there any hits left?
                bne.s   .retract                        ; if yes, branch
                bsr.w   BossDefeated
                subi.l  #$10000,EggmanCylinder_Displacement(a0)  ; retract cylinder at half speed (from 2px to 1px speed)

; loc_1A5B4:
.retract:
                addi.l  #$20000,EggmanCylinder_Displacement(a0)  ; retract at 2px a frame
                bcc.s   .exit                           ; have we reached home (was there a carry)? if not, branch
                clr.l   EggmanCylinder_Displacement(a0)  ; clear displacement and go right back to 0
                movea.l BossFinal_ParentObj(a0),a1      ; copy Eggman's address
                subq.w  #1,BossFinal_ChildCounter(a1)   ; tell Eggman an object is done executing
                clr.w   BossFinal_AttackState(a1)       ; clear attack state so that new cylinder pair can eventually be picked again
                subq.b  #2,obRoutine(a0)                ; go back to the Action routine
                rts
; ===========================================================================

; loc_1A5D4:
.extend:
                cmpi.w  #-$10,EggmanCylinder_Displacement(a0)  ; has the cylinder traveled more than 16 pixels?
                bge.s   .checkExtension                 ; if not, branch
                subi.l  #$28000,EggmanCylinder_Displacement(a0)  ; yes, add 2.5px of speed

; loc_1A5E4:
.checkExtension:
                subi.l  #$8000,EggmanCylinder_Displacement(a0)  ; base value of 0.5px a frame
                cmpi.w  #-$A0,EggmanCylinder_Displacement(a0)  ; has the full extension been reached?
                bgt.s   .exit                           ; if not, branch
                clr.w   EggmanCylinder_FracDisplace(a0)  ; clear fractional movement
                move.w  #-$A0,EggmanCylinder_Displacement(a0)  ; snap to full extension
                clr.b   BossFinal_ChildCmd(a0)          ; clear attacking flag

; locret_1A602:
.exit:
                rts
; ===========================================================================

; loc_1A604:
EggmanCylinder_Top:
                bset    #sprite_yflip_bit,obRender(a0)  ; flip sprite to face downwards
                tst.b   BossFinal_ChildCmd(a0)          ; are we currently attacking?
                bne.s   .extend                         ; if yes, branch
                movea.l BossFinal_ParentObj(a0),a1      ; copy Eggman's address
                tst.b   obBossHits(a1)                  ; are there any hits left?
                bne.s   .retract                        ; if yes, branch
                bsr.w   BossDefeated
                addi.l  #$10000,EggmanCylinder_Displacement(a0)  ; retract cylinder at half speed (from 2px to 1px speed)

; loc_1A626:
.retract:
                subi.l  #$20000,EggmanCylinder_Displacement(a0)  ; retract 2px a frame
                bcc.s   .exit                           ; have we reached home (was there a carry)? if not, branch
                clr.l   EggmanCylinder_Displacement(a0)  ; clear displacement and go right back to 0
                movea.l BossFinal_ParentObj(a0),a1      ; copy Eggman's address
                subq.w  #1,BossFinal_ChildCounter(a1)   ; tell Eggman an object is done executing
                clr.w   BossFinal_AttackState(a1)       ; clear attack state so that new cylinder pair can eventually be picked again
                subq.b  #2,obRoutine(a0)                ; go back to the Action routine
                rts
; ===========================================================================

; loc_1A646:
.extend:
                cmpi.w  #$10,EggmanCylinder_Displacement(a0)  ; has the cylinder traveled more than 16 pixels?
                blt.s   .checkExtension                 ; if not, branch
                addi.l  #$28000,EggmanCylinder_Displacement(a0)  ; yes, add 2.5px of speed

; loc_1A656:
.checkExtension:
                addi.l  #$8000,EggmanCylinder_Displacement(a0)  ; base value of 0.5px a frame
                cmpi.w  #$A0,EggmanCylinder_Displacement(a0)  ; has the full extension been reached?
                blt.s   .exit                           ; if not, branch
                clr.w   EggmanCylinder_FracDisplace(a0)  ; clear fractional movement
                move.w  #$A0,EggmanCylinder_Displacement(a0)  ; snap to full extension
                clr.b   BossFinal_ChildCmd(a0)          ; clear attacking flag

; locret_1A674
.exit:
                rts
; ===========================================================================

Map_EggCyl:   include "src/rendering/mappings/FZ Eggman's Cylinders.asm"

; ===========================================================================
; ---------------------------------------------------------------------------
; Object 86 - energy balls (FZ)
; ---------------------------------------------------------------------------
