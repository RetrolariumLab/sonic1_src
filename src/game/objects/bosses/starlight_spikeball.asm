BossSpikeball:
                moveq   #0,d0
                move.b  obRoutine(a0),d0                ; copy object routine
                move.w  BossSpikeball_Index(pc,d0.w),d0  ; use the object routine index and BossSpikeball_Index to calculate our offset
                jsr     BossSpikeball_Index(pc,d0.w)    ; jump into the table and use our offset to pick a routine in the index to go to
                out_of_range.w BossStarLight_Delete,obBossX(a0),1  ; contains a (redundant) bmi check
                jmp     (DisplaySprite).l
; ===========================================================================
BossSpikeball_Index:
                dc.w    BossSpikeball_Main-BossSpikeball_Index
                dc.w    BossSpikeball_Fall-BossSpikeball_Index
                dc.w    BossSpikeball_Bounce-BossSpikeball_Index
                dc.w    BossSpikeball_HitBoss-BossSpikeball_Index
                dc.w    BossSpikeball_Explode-BossSpikeball_Index
                dc.w    BossSpikeball_MoveFrag-BossSpikeball_Index
; ===========================================================================

BossSpikeball_SeesawY:   equ     objoff_34                   ; offset to store seesaw Y
BossSpikeball_SeesawPtr:   equ     objoff_3C                   ; offset used to keep a pointer of the seesaw that the ball is tied to

BossSpikeball_Main:                                       ; Routine 0
                move.l  #Map_SSawBall,obMap(a0)         ; load mappings and art
                move.w  #ArtTile_Eggman_Spikeball,obGfx(a0)
                move.b  #1,obFrame(a0)                  ; set frame
                ori.b   #sprite_cam_field,obRender(a0)  ; keep all other bits, set render mode to playfield coordinate mode
                move.b  #4,obPriority(a0)               ; set render priority (on the lower side)
                move.b  #col_16x16|col_hurt,obColType(a0)  ; set collision type
                move.b  #24/2,obActWid(a0)              ; set radius of object in pixels (used for hiding sprites when off-screen)
                movea.l BossSpikeball_SeesawPtr(a0),a1  ; copy offset address, a1 now contains the seesaw that this ball is tied to
                move.w  obX(a1),obBossX(a0)             ; copy seesaw X to ball's base X
                move.w  obY(a1),BossSpikeball_SeesawY(a0)  ; store seesaw Y
                bset    #status_xflip_bit,obStatus(a0)  ; flip ball on horizontal axis
                move.w  obX(a0),d0                      ; copy ball's X
                cmp.w   obX(a1),d0                      ; is the ball's X greater than the seesaw's X?
                bgt.s   .skip                           ; if yes, branch
                bclr    #status_xflip_bit,obStatus(a0)  ; no, so remove flip
                move.b  #2,BossStarLight_SeesawSide(a0)  ; set XXXXX to 2

; loc_18D68:
.skip:
                addq.b  #2,obRoutine(a0)                ; increment routine counter (now at the routine below)

BossSpikeball_Fall:                                       ; Routine 2
                jsr     (ObjectFall).l
                movea.l BossSpikeball_SeesawPtr(a0),a1  ; copy offset address, a1 now contains the seesaw that this ball is tied to
                lea     (BossSpikeball_SeesawYOffset).l,a2  ; load table for calculating what part of seesaw is pointing up/down
                moveq   #0,d0
                move.b  obFrame(a1),d0                  ; move current seesaw frame into d0
                move.w  obX(a0),d1                      ; move spikeball x position into d1
                sub.w   obBossX(a0),d1                  ; subtract boss position from spikeball x, creating an offset
                bcc.s   .calculateOffset                ; if the ball is at or to the right of the target, branch
                addq.w  #2,d0                           ; increment (use the left side offset for the table)

; loc_18D8E:
.calculateOffset:
                add.w   d0,d0                           ; add to create word-based index into the table
                move.w  BossSpikeball_SeesawY(a0),d1    ; copy Y value originally stored at this offset
                add.w   (a2,d0.w),d1                    ; calculate table offset using word-based index and store
                cmp.w   obY(a0),d1                      ; has the spikeball reached the seesaw?
                bgt.s   .exit                           ; if not, branch and come back later
                movea.l BossSpikeball_SeesawPtr(a0),a1  ; copy offset address, a1 now contains the seesaw that this ball is tied to
                moveq   #2,d1
                btst    #status_xflip_bit,obStatus(a0)  ; are we horizontally flipped (facing the right?)
                beq.s   .landed                         ; if so, branch
                moveq   #0,d1

; loc_18DAE:
.landed:
                move.w  #240,obSubtype(a0)              ; initialize timer for ball countdown, obSubtype offset from here and below is now a timer
                move.b  #10,obDelayAni(a0)              ; set frame duration to 10 frames for ball flicker
                move.b  obDelayAni(a0),obTimeFrame(a0)  ; copy
                bra.w   BossSpikeball_LaunchSonic
; ===========================================================================

; locret_18DC4:
.exit:
                rts
; ===========================================================================

; loc_18DC6:
BossSpikeball_Bounce:                                       ; Routine 4
                movea.l BossSpikeball_SeesawPtr(a0),a1  ; copy offset address, a1 now contains the seesaw that this ball is tied to
                moveq   #0,d0
                move.b  BossStarLight_SeesawSide(a0),d0  ; move spike ball's side value
                sub.b   BossStarLight_SeesawSide(a1),d0  ; subtract seesaw's side value with spike ball's value
                beq.s   BossSpikeball_CalcPos           ; if equal, the ball hasn't left the saw, so branch
                bcc.s   .calcLaunch                     ; if no carry (2-0), the ball has been launched, so branch
                neg.b   d0                              ; ball was on opposite side but has been launched, so negate, this is just calculating absolute value

; loc_18DDA:
.calcLaunch:
                move.w  #-$818,d1                       ; set up initial velocity values
                move.w  #-$114,d2
                cmpi.b  #1,d0                           ; is the seesaw perfectly flat?
                beq.s   .launch                         ; if so, branch
                move.w  #-$960,d1                       ; increase velocity values
                move.w  #-$F4,d2
                cmpi.w  #$9C0,see_landspeed(a1)         ; is Sonic's landing speed greater than or equal to $9C0 (offset from object 5E)
                blt.s   .launch                         ; if not, branch
                move.w  #-$A20,d1                       ; increase velocity values
                move.w  #-$80,d2

; loc_18E00:
.launch:
                move.w  d1,obVelY(a0)                   ; copy values to actual velocity
                move.w  d2,obVelX(a0)
                move.w  obX(a0),d0                      ; move x position
                sub.w   obBossX(a0),d0                  ; subtract seesaw's x position
                bcc.s   .skip                           ; is the ball on the right side of the saw? if so, branch
                neg.w   obVelX(a0)                      ; flip velocity, ball is on left side traveling right

; loc_18E16:
.skip:
                move.b  #1,obFrame(a0)                  ; set frame
                move.w  #32,obSubtype(a0)               ; set ball explosion countdown
                addq.b  #2,obRoutine(a0)                ; increment routine counter
                bra.w   BossSpikeball_HitBoss
; ===========================================================================

; loc_18E2A:
BossSpikeball_CalcPos:
                lea     (BossSpikeball_SeesawYOffset).l,a2  ; load seesaw y offset table
                moveq   #0,d0
                move.b  obFrame(a1),d0                  ; move current seesaw frame
                move.w  #40,d2                          ; set a 40 pixel offset from seesaw center to use later
                move.w  obX(a0),d1                      ; copy ball position
                sub.w   obBossX(a0),d1                  ; subtract with position relative to seesaw to create offset
                bcc.s   .setPos                         ; if on right side of seesaw, branch
                neg.w   d2                              ; left side of seesaw, negate
                addq.w  #2,d0                           ; set index in order to account for left side

; loc_18E48:
.setPos:
                add.w   d0,d0                           ; add to create word-based index into the table
                move.w  BossSpikeball_SeesawY(a0),d1    ; copy seesaw Y position
                add.w   (a2,d0.w),d1                    ; index into the table using calculated offset and Y position of seesaw
                move.w  d1,obY(a0)                      ; set ball position based on seesaw index calculated
                add.w   obBossX(a0),d2                  ; add seesaw position plus 40 pixel offset
                move.w  d2,obX(a0)                      ; move ball position to offset
                clr.w   obSubpixelY(a0)                 ; clear sub pixels
                clr.w   obSubpixelX(a0)
                subq.w  #1,obSubtype(a0)                ; has the timer reached 0?
                bne.s   BossSpikeball_CheckFlicker      ; if not, branch
                move.w  #32,obSubtype(a0)               ; reset timer
                move.b  #8,obRoutine(a0)                ; advance to explode routine
                rts
; ===========================================================================

; loc_18E7A:
BossSpikeball_CheckFlicker:
                cmpi.w  #120,obSubtype(a0)              ; has two seconds passed?
                bne.s   .mediumFlicker                  ; if not, branch
                move.b  #5,obDelayAni(a0)               ; set animation delay to 5 frames for flicker

; loc_18E88:
.mediumFlicker:
                cmpi.w  #60,obSubtype(a0)               ; has three seconds passed?
                bne.s   .fastFlicker                    ; if not, branch
                move.b  #2,obDelayAni(a0)               ; set animation delay to 2 frames for flicker

; loc_18E96:
.fastFlicker:
                subq.b  #1,obTimeFrame(a0)              ; subtract frame timer in order to increment flicker
                bgt.s   .exit                           ; is there still time left? if yes, leave early
                bchg    #0,obFrame(a0)                  ; flip the frame
                move.b  obDelayAni(a0),obTimeFrame(a0)  ; copy

; locret_18EA8:
.exit:
                rts
; ===========================================================================

; loc_18EAA:
BossSpikeball_HitBoss:                                       ; Routine 6
                lea     (v_objspace+object_size*1).w,a1  ; Nonsensical starting point, since dynamic object allocations begin at v_lvlobjspace
                moveq   #id_BossStarLight,d0
                moveq   #object_size,d1
                moveq   #(v_objspace_end-(v_objspace+object_size*1))/object_size/2-1,d2  ; Nonsensical length, it only covers the first half of object RAM

; loc_18EB4:
.findBoss:
                cmp.b   obID(a1),d0                     ; is the current index the boss object?
                beq.s   BossSpikeball_CheckCollision    ; if yes, branch
                adda.w  d1,a1                           ; add object size to level object space (increment index via word)
                dbf     d2,.findBoss                    ; decrement based on amount of objects in level and loop

                bra.s   BossSpikeball_CheckCollision.checkPhysics  ; no boss found, branch

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to check that the center of the ball is within Eggman's collision in order to trigger a hit
; All 4 conditions must be met by calculating offsets based on X position and collision sizes before a hit can be activated
; ---------------------------------------------------------------------------

; loc_18EC0:
BossSpikeball_CheckCollision:
                move.w  obX(a1),d0                      ; copy boss position
                move.w  obY(a1),d1
                move.w  obX(a0),d2                      ; copy ball position
                move.w  obY(a0),d3
                lea     BossSpikeball_BossHitbox(pc),a2  ; load boss hitbox
                lea     BossSpikeball_BallHitbox(pc),a3  ; load ball hitbox

; check left side of Eggman's collision box in comparison to right side of ball

                move.b  (a2)+,d4                        ; copy first value into d4 (LEFT side of Eggman's hitbox) and increment address
                ext.w   d4                              ; sign extend into a word (due to hitboxes being byte sized, must be extended to prevent pixel boundary overflows in level)
                add.w   d4,d0                           ; add left side hitbox with X position of boss
                move.b  (a3)+,d4                        ; copy first value into d4 (RIGHT side of ball hitbox) and increment address
                ext.w   d4                              ; sign extend into a word
                add.w   d4,d2                           ; add right side hitbox with X position of ball
                cmp.w   d0,d2                           ; is the left side of Eggman colliding with the right side of the ball?
                blo.s   .checkPhysics                   ; if not, branch

; check left side of ball's collision box in comparison to right side of Eggman

                move.b  (a2)+,d4                        ; copy second value into d4 (RIGHT side of Eggman's hitbox) and increment address
                ext.w   d4                              ; sign extend into a word
                add.w   d4,d0                           ; add right side hitbox with X position of boss
                move.b  (a3)+,d4                        ; copy second value into d4 (LEFT side of ball hitbox) and increment address
                ext.w   d4                              ; sign extend into a word
                add.w   d4,d2                           ; add left side hitbox with X position of ball
                cmp.w   d2,d0                           ; is the left side of the ball colliding with the right side of Eggman?
                blo.s   .checkPhysics                   ; if not, branch

; check top side of Eggman's collision box in comparison to bottom side of ball

                move.b  (a2)+,d4                        ; copy third value into d4 (TOP side of Eggman's hitbox) and increment address
                ext.w   d4                              ; sign extend into a word
                add.w   d4,d1                           ; add top side hitbox with Y position of Eggman
                move.b  (a3)+,d4                        ; copy third value into d4 (BOTTOM side of ball's hitbox) and increment address
                ext.w   d4                              ; sign extend into a word
                add.w   d4,d3                           ; add bottom side hitbox with Y position of ball
                cmp.w   d1,d3                           ; is the top side of Eggman colliding with the bottom side of the ball?
                blo.s   .checkPhysics                   ; if not, branch

; check top side of ball's collision box in comparison to bottom side of Eggman

                move.b  (a2)+,d4                        ; copy fourth value into d4 (BOTTOM side of Eggman's hitbox) and increment address
                ext.w   d4                              ; sign extend into a word
                add.w   d4,d1                           ; add bottom side hitbox with Y position of Eggman
                move.b  (a3)+,d4                        ; copy fourth value into d4 (TOP side of ball's hitbox) and increment address
                ext.w   d4                              ; sign extend into a word
                add.w   d4,d3                           ; add top side hitbox with Y position of ball
                cmp.w   d3,d1                           ; is the top side of the ball colliding with the bottom side of Eggman?
                blo.s   .checkPhysics                   ; if not, branch
                addq.b  #2,obRoutine(a0)                ; increment object routine
                clr.w   obSubtype(a0)                   ; clear explosion timer
                clr.b   obColType(a1)                   ; disable boss collision
                subq.b  #1,obBossHits(a1)               ; subtract hits
                bne.s   .checkPhysics                   ; if there are more hits, branch
                bset    #status_defeated_bit,obStatus(a1)  ; set boss flag to defeated
                clr.w   obVelX(a0)                      ; stop moving
                clr.w   obVelY(a0)

; loc_18F38:
.checkPhysics:
                tst.w   obVelY(a0)                      ; is the ball currently falling?
                bpl.s   BossSpikeball_FallingDown       ; if yes, branch
                jsr     (ObjectFall).l
                move.w  BossSpikeball_SeesawY(a0),d0    ; copy seesaw Y
                subi.w  #$2F,d0                         ; subtract 47 pixels
                cmp.w   obY(a0),d0                      ; is the ball resting on the seesaw?
                bgt.s   BossSpikeball_Land              ; if not, branch
                jsr     (ObjectFall).l                  ; lower seesaw since now we landed on the opposite seesaw side

BossSpikeball_Land:
                bra.w   BossSpikeball_CheckFlicker
; ===========================================================================

; loc_18F5C:
BossSpikeball_FallingDown:
                jsr     (ObjectFall).l
                movea.l BossSpikeball_SeesawPtr(a0),a1  ; copy offset address, a1 now contains the seesaw that this ball is tied to
                lea     (BossSpikeball_SeesawYOffset).l,a2  ; load seesaw Y offset table
                moveq   #0,d0
                move.b  obFrame(a1),d0                  ; copy seesaw frame
                move.w  obX(a0),d1                      ; copy spikeball X position
                sub.w   obBossX(a0),d1                  ; subtract seesaw X position
                bcc.s   .checkSawCol                    ; is the ball on the right side of the seesaw? if so, branch
                addq.w  #2,d0                           ; ball is on left side, increment index by 2

; loc_18F7E:
.checkSawCol:
                add.w   d0,d0                           ; add to create word-based index into the table
                move.w  BossSpikeball_SeesawY(a0),d1    ; copy seesaw Y
                add.w   (a2,d0.w),d1                    ; index into the table using calculated offset and Y position of seesaw
                cmp.w   obY(a0),d1                      ; has the spikeball reached the seesaw?
                bgt.s   BossSpikeball_Land              ; if not, branch and come back later
                movea.l BossSpikeball_SeesawPtr(a0),a1  ; copy offset address, a1 now contains the seesaw that this ball is tied to
                moveq   #2,d1
                tst.w   obVelX(a0)                      ; is the ball currently moving to the left?
                bmi.s   .setExplode                     ; if yes, branch
                moveq   #0,d1

; loc_18F9C:
.setExplode:
                move.w  #0,obSubtype(a0)                ; set explosion timer to 0

; loc_18FA2l:
BossSpikeball_LaunchSonic:
                move.b  d1,BossStarLight_SeesawSide(a1)  ; tell seesaw what side ball is on
                move.b  d1,BossStarLight_SeesawSide(a0)  ; update ball
                cmp.b   obFrame(a1),d1                  ; is the seesaw already pushed down?
                beq.s   .noLaunch                       ; if yes, seesaw can't flip, so skip
                bclr    #status_on_object_bit,obStatus(a1)  ; is Sonic currently standing on the seesaw?
                beq.s   .noLaunch                       ; if not, branch (Z flag was set to 0 because bit 3 was already 0!)
                clr.b   ob2ndRout(a1)
                move.b  #2,obRoutine(a1)                ; change seesaw routine state to 2
                lea     (v_player).w,a2                 ; load Sonic's object RAM
                move.w  obVelY(a0),obVelY(a2)           ; copy falling ball's velocity to Sonic's velocity
                neg.w   obVelY(a2)                      ; negate so now velocity will force Sonic upwards
                cmpi.b  #1,obFrame(a1)                  ; was the seesaw perfectly flat before launch?
                bne.s   .applyLaunch                    ; if not, branch
                asr.w   obVelY(a2)                      ; if yes, divide Y velocity by 2

; loc_18FDC:
.applyLaunch:
                bset    #status_in_air_bit,obStatus(a2)  ; set Sonic to air state
                bclr    #status_on_object_bit,obStatus(a2)  ; clear Sonic's standing on object state
                clr.b   jumping(a2)                     ; clear jump flag
                move.l  a0,-(sp)                        ; copy spikeball address to stack and decrement stack
                lea     (a2),a0                         ; load Sonic's object RAM into a0
                jsr     (Sonic_ChkRoll).l               ; check roll, Sonic must be in a0 for this
                movea.l (sp)+,a0                        ; restore a0 and increment the stack
                move.b  #2,obRoutine(a2)                ; set Sonic's routine state to airbourne control
                move.w  #sfx_Spring,d0
                jsr     (QueueSound2).l                 ; play "spring" sound

; loc_19008:
.noLaunch:
                clr.w   obVelX(a0)                      ; stop ball movement
                clr.w   obVelY(a0)
                addq.b  #2,obRoutine(a0)                ; increment ball's state to _HitBoss
                bra.w   BossSpikeball_CheckFlicker

; ===========================================================================
BossSpikeball_SeesawYOffset:
; Y offset between a falling spike ball and the target seesaw's side,
; depending on the current slanting state of the seesaw
; Entries 1-3 are read if ball falls on left side, 3-5 if on right
                dc.w    -8                              ; left - seesaw is raised
                dc.w    -$1C                            ; left - seesaw is flat
                dc.w    -$2F                            ; shared - seesaw is lowered
                dc.w    -$1C                            ; right - seesaw is flat
                dc.w    -8                              ; right - seesaw is raised
                even

BossSpikeball_BossHitbox:
                dc.b    -$18, $18+$18                   ; left to right
                dc.b    -$18, $18+$18                   ; top to bottom
                even

BossSpikeball_BallHitbox:
                dc.b    8, -8-8                         ; right to left
                dc.b    8, -8-8                         ; bottom to top
                even
; ===========================================================================

BossSpikeball_Explode:                                       ; Routine 8
                move.b  #id_Explosion,obID(a0)          ; set object ID of ball to explosion
                clr.b   obRoutine(a0)                   ; clear routine counter to 0
                cmpi.w  #32,obSubtype(a0)               ; is this the first explosion frame?
                beq.s   BossSpikeball_MakeFrag          ; if yes, branch
                rts
; ===========================================================================

BossSpikeball_MakeFrag:
                move.w  BossSpikeball_SeesawY(a0),obY(a0)
                moveq   #3,d1                           ; set up loop to loop 4 times
                lea     BossSpikeball_FragSpeed(pc),a2

BossSpikeball_Loop:
                jsr     (FindFreeObj).l                 ; look for a free object slot
                bne.s   .loop
                move.b  #id_BossSpikeball,obID(a1)      ; load shrapnel object
                move.b  #$A,obRoutine(a1)               ; set routine to routine 10 (below)
                move.l  #Map_BSBall,obMap(a1)           ; set mappings
                move.b  #3,obPriority(a1)               ; set priority (to appear in front of background)
                move.w  #ArtTile_Eggman_Spikeball,obGfx(a1)  ; set art
                move.w  obX(a0),obX(a1)                 ; copy position of fragment to ball
                move.w  obY(a0),obY(a1)
                move.w  (a2)+,obVelX(a1)                ; pull X and Y velocity from the table and move fragements
                move.w  (a2)+,obVelY(a1)
                move.b  #col_8x8|col_hurt,obColType(a1)  ; set 8x8 collision box
                ori.b   #sprite_cam_field,obRender(a1)  ; set render mode to camera playfield mode
                bset    #sprite_rendered_bit,obRender(a1)  ; set to display immediately
                move.b  #24/2,obActWid(a1)              ; set object radius for off-screen hiding purposes

; loc_1909A:
.loop:
                dbf     d1,BossSpikeball_Loop           ; repeat sequence 3 more times

                rts                                     ; no free slots found, leave
; ===========================================================================
BossSpikeball_FragSpeed:
                dc.w    -$100, -$340                    ; horizontal, vertical
                dc.w    -$A0, -$240
                dc.w    $100, -$340
                dc.w    $A0, -$240
; ===========================================================================

BossSpikeball_MoveFrag:                                       ; Routine $A
                jsr     (SpeedToPos).l                  ; add calculated velocity values to X and Y
                move.w  obX(a0),obBossX(a0)             ; copy X and Y positions
                move.w  obY(a0),BossSpikeball_SeesawY(a0)
                addi.w  #$18,obVelY(a0)                 ; start pulling the fragments downwards
                moveq   #4,d0                           ; set up to use the third bit
                and.w   (v_vblank_word).w,d0            ; AND with the global vblank frame counter to get the status of the 3rd bit AKA every 4 frames
                lsr.w   #2,d0                           ; shift that bit all the way to the right
                move.b  d0,obFrame(a0)                  ; set frame to value from above calculation, allowing graphics frame to alternate every 4 frames

                tst.b   obRender(a0)
                bpl.w   BossStarLight_Delete

.return:
                rts
; ===========================================================================

Map_BSBall:   include "src/rendering/mappings/SLZ Boss Spikeball.asm"
