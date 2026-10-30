BossPlasma:
                moveq   #0,d0
                move.b  obRoutine(a0),d0
                move.w  BossPlasma_Index(pc,d0.w),d0    ; use the object routine index and BossPlasma_Index to calculate our offset
                jmp     BossPlasma_Index(pc,d0.w)       ; jump into the table and use our offset to pick a routine
; ===========================================================================
BossPlasma_Index:
                dc.w    BossPlasma_Main-BossPlasma_Index
                dc.w    BossPlasma_Generator-BossPlasma_Index
                dc.w    BossPlasma_MakeBalls-BossPlasma_Index
                dc.w    BossPlasma_Finish-BossPlasma_Index
                dc.w    BossPlasma_Balls-BossPlasma_Index

BossPlasma_TargetX:   equ     objoff_30                   ; offset used to keep track of the target X position in each ball phase, re-used once to set up X spread offsets when first spawning
BossPlasma_BallsAlive:   equ     objoff_38                   ; offset used to keep track of how many plasma balls are still alive
; ===========================================================================

BossPlasma_Main:                                       ; Routine 0
                move.w  #boss_fz_x+$138,obX(a0)         ; set initial X and Y
                move.w  #boss_fz_y+$2C,obY(a0)
                move.w  #ArtTile_FZ_Boss,obGfx(a0)      ; load art and mappings
                move.l  #Map_PLaunch,obMap(a0)
                move.b  #0,obAnim(a0)                   ; set initial animation frame
                move.b  #3,obPriority(a0)               ; set priority, width, and height
                move.b  #16/2,obWidth(a0)
                move.b  #16/2,obHeight(a0)
                move.b  #sprite_cam_field,obRender(a0)  ; set render bits
                bset    #sprite_rendered_bit,obRender(a0)
                addq.b  #2,obRoutine(a0)                ; increment routine

BossPlasma_Generator:;   Routine 2
                movea.l BossFinal_ParentObj(a0),a1      ; copy Eggman's address
                cmpi.b  #6,BossFinal_ParentObj(a1)      ; are we in routine 6 (Fall routine)?
                bne.s   .checkStatus                    ; if not, branch
                move.b  #id_Explosion,obID(a0)          ; change object to explosion
                move.b  #0,obRoutine(a0)                ; set object routine of new explosion object
                jmp     (DisplaySprite).l
; ===========================================================================

; loc_1A850:
.checkStatus:
                move.b  #0,obAnim(a0)                   ; set animation to 0
                tst.b   BossFinal_ChildCmd(a0)          ; has the controller told us to attack?
                beq.s   BossPlasma_Collision            ; if not, branch
                addq.b  #2,obRoutine(a0)                ; increment to MakeBalls
                move.b  #1,obAnim(a0)                   ; set animation to 1
                move.b  #62,obSubtype(a0)               ; use offset to set a timer

; loc_1A86C:
BossPlasma_Collision:
                move.w  #16/2+sonic_solid_width,d1      ; set up collision
                move.w  #16/2,d2
                move.w  #34/2,d3
                move.w  obX(a0),d4
                jsr     (SolidObject).l
                move.w  (v_player+obX).w,d0             ; copy Sonic's X
                sub.w   obX(a0),d0                      ; subtract with plasma's X
                bmi.s   .display                        ; if Sonic is to the left of the plasma, branch
                subi.w  #$140,d0                        ; subtract 320 (a screen's width) from Sonic's position
                bmi.s   .display                        ; Sonic is within a screen's width, branch
                tst.b   obRender(a0)                    ; is the plasma currently on screen?
                bpl.w   EggmanCylinder_Delete           ; if so, branch

; loc_1A89A:
.display:
                lea     Ani_PLaunch(pc),a1
                jsr     (AnimateSprite).l
                jmp     (DisplaySprite).l
; ===========================================================================

BossPlasma_MakeBalls:;   Routine 4
                tst.b   BossFinal_ChildCmd(a0)          ; are we currently attacking?
                beq.w   .checkStatus                    ; if not, branch
                clr.b   BossFinal_ChildCmd(a0)          ; clear flag so it only runs once

; Seemingly dead code here as a2 is never used anywhere, possibly an old table lookup?
                add.w   BossPlasma_TargetX(a0),d0
                andi.w  #$1E,d0
                adda.w  d0,a2

                addq.w  #4,BossPlasma_TargetX(a0)       ; increment spread offset (to spread the ball out horizontally when spawning)
                clr.w   BossFinal_ChildCounter(a0)      ; clear ball counter
                moveq   #3,d2                           ; set to loop 4 times

; BossPlasma_Loop:
.loop:
                jsr     (FindNextFreeObj).l
                bne.w   .checkStatus                    ; no free objects found, branch
                move.b  #id_BossPlasma,obID(a1)         ; set object ID to plasma
                move.w  obX(a0),obX(a1)                 ; copy position
                move.w  #boss_fz_y+$2C,obY(a1)          ; set Y location
                move.b  #8,obRoutine(a1)                ; set routine to Balls
                move.w  #ArtTile_FZ_Boss|Tile_Pal2,obGfx(a1)  ; copy art and mappings
                move.l  #Map_Plasma,obMap(a1)
                move.b  #24/2,obHeight(a1)              ; copy height and collisions
                move.b  #24/2,obWidth(a1)
                move.b  #col_none,obColType(a1)
                move.b  #3,obPriority(a1)               ; set priority
                move.w  #62,obSubtype(a1)               ; set timer and also zero out ChildCmd
                move.b  #sprite_cam_field,obRender(a1)  ; set render bits
                bset    #sprite_rendered_bit,obRender(a1)
                move.l  a0,BossFinal_ParentObj(a1)      ; copy parent object address
                jsr     (RandomNumber).l
                move.w  BossFinal_ChildCounter(a0),d1   ; copy back since RandomNumber also uses d1
                muls.w  #-$4F,d1
                addi.w  #boss_fz_x+$128,d1              ; start at the rightmost position
                andi.w  #$1F,d0                         ; AND to keep 5 bits of the random number (0-31)
                subi.w  #$10,d0                         ; subtract by 16 to center it
                add.w   d1,d0                           ; set ball offset
                move.w  d0,BossPlasma_TargetX(a1)       ; store the ball's target X
                addq.w  #1,BossFinal_ChildCounter(a0)   ; count this ball
                move.w  BossFinal_ChildCounter(a0),BossPlasma_BallsAlive(a0)  ; copy counter
                dbf     d2,.loop                        ; repeat sequence 3 more times

; loc_1A954:
.checkStatus:
                tst.w   BossFinal_ChildCounter(a0)      ; are there still balls that need to reach their X position before dropping? (modified down in Plasma_Balls)
                bne.s   .exit                           ; if yes, exit
                addq.b  #2,obRoutine(a0)                ; increment to Finish

; loc_1A95E:
.exit:
                bra.w   BossPlasma_Collision
; ===========================================================================

; loc_1A962:
BossPlasma_Finish:                                       ; Routine 6
                move.b  #2,obAnim(a0)                   ; set animation type for launcher
                tst.w   BossPlasma_BallsAlive(a0)       ; are there any balls still alive?
                bne.s   .exit                           ; if yes, exit
                move.b  #2,obRoutine(a0)                ; set routine to Generator
                movea.l BossFinal_ParentObj(a0),a1      ; copy Eggman's address
                move.w  #-1,BossFinal_ChildCounter(a1)  ; relay signal that balls are all gone

; loc_1A97E:
.exit:
                bra.w   BossPlasma_Collision
; ===========================================================================

; loc_1A982:
BossPlasma_Balls:                                       ; Routine 8
                moveq   #0,d0
                move.b  ob2ndRout(a0),d0
                move.w  BossPlasma_Index2(pc,d0.w),d0   ; use the object routine index and BossPlasma_Index2 to calculate our offset
                jsr     BossPlasma_Index2(pc,d0.w)      ; jump into the table and use our offset to pick a routine
                lea     Ani_Plasma(pc),a1
                jsr     (AnimateSprite).l
                jmp     (DisplaySprite).l
; ===========================================================================
BossPlasma_Index2:
                dc.w    BossPlasma_Spread-BossPlasma_Index2
                dc.w    BossPlasma_Drop-BossPlasma_Index2
                dc.w    BossPlasma_Move-BossPlasma_Index2
; ===========================================================================

; loc_1A9A6:
BossPlasma_Spread:
                move.w  BossPlasma_TargetX(a0),d0       ; copy target X
                sub.w   obX(a0),d0                      ; subtract distance from generator to target
                asl.w   #4,d0                           ; multiply by 16
                move.w  d0,obVelX(a0)                   ; set that as velocity
                move.w  #180,obSubtype(a0)              ; set a timer for 180 frames
                addq.b  #2,ob2ndRout(a0)                ; increment to Drop
                rts
; ===========================================================================

; loc_1A9C0:
BossPlasma_Drop:
                tst.w   obVelX(a0)                      ; are we currently set to move?
                beq.s   .aim                            ; if not, branch
                jsr     (SpeedToPos).l                  ; calculate movement
                move.w  obX(a0),d0                      ; copy current X
                sub.w   BossPlasma_TargetX(a0),d0       ; subtract current X from target X
                bcc.s   .aim                            ; have we reached the target starting X? if not, branch (moving from right to left so if there is no carry, then too far left)
                clr.w   obVelX(a0)                      ; target reached, stop
; this is intended to keep the leftmost energy ball in bounds,
; but it actually pushes it FURTHER to the left
                add.w   d0,obX(a0)
                movea.l BossFinal_ParentObj(a0),a1
                subq.w  #1,BossFinal_ChildCounter(a1)

; loc_1A9E6:
.aim:
                move.b  #0,obAnim(a0)                   ; set animation type to hovering
                subq.w  #1,obSubtype(a0)                ; decrement timer
                bne.s   .exit                           ; not ready to drop yet, exit
                addq.b  #2,ob2ndRout(a0)                ; increment routine to Move
                move.b  #1,obAnim(a0)                   ; set animation type to attacking
                move.b  #col_24x24|col_hurt,obColType(a0)  ; enable collision
                move.w  #180,obSubtype(a0)              ; set another timer for 180 frames
                moveq   #0,d0
                move.w  (v_player+obX).w,d0             ; copy Sonic's X
                sub.w   obX(a0),d0                      ; subtract ball position
                move.w  d0,obVelX(a0)                   ; aim in the direction of Sonic
                move.w  #$140,obVelY(a0)                ; start falling downwards

; locret_1AA1C:
.exit:
                rts
; ===========================================================================

; loc_1AA1E:
BossPlasma_Move:
                jsr     (SpeedToPos).l
                cmpi.w  #boss_fz_y+$D0,obY(a0)          ; have we reached the bottom of the screen?
                bhs.s   .deleteChild                    ; if yes, branch
                subq.w  #1,obSubtype(a0)                ; decrement timer
                beq.s   .deleteChild                    ; has timer hit 0? if so, branch
                rts
; ===========================================================================

; loc_1AA34:
.deleteChild:
                movea.l BossFinal_ParentObj(a0),a1      ; copy ball launcher's address
                subq.w  #1,BossPlasma_BallsAlive(a1)    ; decrement ball count
                bra.w   EggmanCylinder_Delete
; ===========================================================================

                include "src/rendering/animation/plasma_ball_launcher.s"
Map_PLaunch:   include "src/rendering/mappings/plasma_ball_launcher.s"
                include "src/rendering/animation/plasma_balls.s"
Map_Plasma:   include "src/rendering/mappings/plasma_balls.s"
