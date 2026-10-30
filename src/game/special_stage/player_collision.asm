SonicSS_FindWall:
                lea     (v_sslayout_base).l,a1          ; get special stage layout in RAM

                moveq   #0,d4                           ; clear d4
                swap    d2                              ; move main pixel Y position into lower word
                move.w  d2,d4                           ; copy that word to d4
                swap    d2                              ; revert swapping
                addi.w  #20+(ss_blocksize*2),d4         ; manually adjust target Y position by 68 pixels down
                divu.w  #ss_blocksize,d4                ; divide by size of SS blocks (24 pixels)
                mulu.w  #ss_layout_rowlength,d4         ; multiply by bytes per layout row
                adda.l  d4,a1                           ; add result to a1 to find current row Sonic is in

                moveq   #0,d4                           ; clear d4
                swap    d3                              ; move main pixel X position into lower word
                move.w  d3,d4                           ; copy that word to d4
                swap    d3                              ; revert swapping
                addi.w  #20,d4                          ; manually adjust target X position by 20 pixels to the right
                divu.w  #ss_blocksize,d4                ; divide by size of SS blocks (24 pixels)
                adda.w  d4,a1                           ; add result to a1 to find current column Sonic is in

; a1 is now pointing to the exact byte (row/column) within the layout Sonic is in
; From there, check if this position intersects with any of the four nearest blocks
; around Sonic, checking them one by one. If any of them are solid, d5 gets set

                moveq   #0,d5                           ; set to no collision detected

                move.b  (a1)+,d4                        ; get top-left block
                bsr.s   SonicSS_FindWall_CheckType      ; check for collision
                move.b  (a1)+,d4                        ; get top-right block
                bsr.s   SonicSS_FindWall_CheckType      ; check for collision
                adda.w  #ss_layout_rowlength-2,a1       ; advance to next row (2 bytes were already advanced)
                move.b  (a1)+,d4                        ; get bottom-left block
                bsr.s   SonicSS_FindWall_CheckType      ; check for collision
                move.b  (a1)+,d4                        ; get bottom-right block
                bsr.s   SonicSS_FindWall_CheckType      ; check for collision

                tst.b   d5                              ; unset Z-flag if any of the four blocks were solid
                rts                                     ; return with result in CCR
; ===========================================================================

; sub_1BD30:
SonicSS_FindWall_CheckType:
                beq.s   .return                         ; if it's a blank block ($00), branch
                cmpi.b  #id_SS_1Up,d4                   ; is block ID = $28? (1-Up)
                beq.s   .return                         ; if yes, branch
                cmpi.b  #id_SS_Ring,d4                  ; is block ID < $3A? (solid blocks, ring is first non-solid)
                blo.s   .solidblock                     ; if yes, branch
; IDs $3A-$4A are non-solid blocks (e.g. rings)
                cmpi.b  #id_SS_Glass_Ani1,d4            ; is block ID >= $4B (special blocks for broken glass)
                bhs.s   .solidblock                     ; if yes, branch

; locret_1BD44:
.return:
                rts                                     ; return with d5 unchanged
; ===========================================================================

; loc_1BD46:
.solidblock:
                move.b  d4,sonss_touchedblock_id(a0)    ; remember ID of touched block
                move.l  a1,sonss_touchedblock_ram(a0)   ; remember RAM address of touched block
                moveq   #-1,d5                          ; set flag that a solid block was found
                rts                                     ; return with d5 changed
; End of function SonicSS_FindWall

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to check for collision blocks that have no solidity (rings etc.)
;
; output:
; d4 = (unused) 0 if block is a regular item or blank; -1 otherwise
; ---------------------------------------------------------------------------

; Obj09_ChkItems: SonicSS_ChkItems:
SonicSS_ChkItems_NonSolidActionBlock:
                lea     (v_sslayout_base).l,a1          ; get special stage layout in RAM

                moveq   #0,d4                           ; clear d4
                move.w  obY(a0),d4                      ; get Sonic's Y position
                addi.w  #80,d4                          ; manually adjust a bit
                divu.w  #ss_blocksize,d4                ; divide by size of SS blocks (24 pixels)
                mulu.w  #ss_layout_rowlength,d4         ; multiply by bytes per layout row
                adda.l  d4,a1                           ; add result to a1 to find current row Sonic is in

                moveq   #0,d4                           ; clear d4
                move.w  obX(a0),d4                      ; get Sonic's X position
                addi.w  #32,d4                          ; manually adjust a bit
                divu.w  #ss_blocksize,d4                ; divide by size of SS blocks (24 pixels)
                adda.w  d4,a1                           ; add result to a1 to find current column Sonic is in

                move.b  (a1),d4                         ; is Sonic touching a non-blank block?
                bne.s   SonicSS_ChkRing                 ; if yes, check which one it was

                tst.b   sonss_ghoststate(a0)            ; has ghost block or its trigger been passed?
                bne.w   SonicSS_MakeGhostSolid          ; if yes, branch

                moveq   #0,d4                           ; blank
                rts                                     ; return
; ===========================================================================

; Obj09_ChkCont:
SonicSS_ChkRing:
                cmpi.b  #id_SS_Ring,d4                  ; is the item a ring?
                bne.s   SonicSS_Chk1Up                  ; if not, branch

                bsr.w   SS_FindFreeAnimationSlot        ; find a free animation slot
                bne.s   SonicSS_GetContinue             ; if none are free, branch
                _move.b #1,ss_ani_id(a2)                ; set to SS_AniRingSparks
                move.l  a1,ss_ani_block(a2)             ; store address of this block for animation

; Obj09_GetCont:
SonicSS_GetContinue:
                jsr     (CollectRing).l                 ; add a ring
                cmpi.w  #ss_continue_rings,(v_rings).w  ; check if you now have 50 rings
                blo.s   SonicSS_NoContinue              ; if not, branch
                bset    #0,(v_lifecount).w              ; remember that a continue has already been awarded
                bne.s   SonicSS_NoContinue              ; if flag was already set, branch
                addq.b  #1,(v_continues).w              ; add 1 to number of continues
                move.w  #sfx_Continue,d0                ; set extra continue sound
                jsr     (QueueSound1).l                 ; play it

; Obj09_NoCont:
SonicSS_NoContinue:
                moveq   #0,d4                           ; regular item
                rts                                     ; return
; ===========================================================================

; Obj09_Chk1Up:
SonicSS_Chk1Up:
                cmpi.b  #id_SS_1Up,d4                   ; is the item an extra life?
                bne.s   SonicSS_ChkEmerald              ; if not, branch

                bsr.w   SS_FindFreeAnimationSlot        ; find a free animation slot
                bne.s   SonicSS_Get1Up                  ; if none are free, branch
                _move.b #3,ss_ani_id(a2)                ; set to SS_Ani1Up
                move.l  a1,ss_ani_block(a2)             ; store address of this block for animation

; Obj09_Get1Up:
SonicSS_Get1Up:
                addq.b  #1,(v_lives).w                  ; add 1 to number of lives
                addq.b  #1,(f_lifecount).w              ; update the lives counter
                move.w  #bgm_ExtraLife,d0               ; set extra life music
                jsr     (QueueSound1).l                 ; play it

                moveq   #0,d4                           ; regular item
                rts                                     ; return
; ===========================================================================

; Obj09_ChkEmer:
SonicSS_ChkEmerald:
                cmpi.b  #id_SS_Emerald1_Blue,d4         ; is the item an emerald? (lower bound)
                blo.s   SonicSS_ChkGhost                ; if not, branch
                cmpi.b  #id_SS_Emerald6_Grey,d4         ; is the item an emerald? (upper bound)
                bhi.s   SonicSS_ChkGhost                ; if not, branch

                bsr.w   SS_FindFreeAnimationSlot        ; find a free animation slot
                bne.s   SonicSS_GetEmerald              ; if none are free, branch
                _move.b #5,ss_ani_id(a2)                ; set to SS_AniEmeraldSparks
                move.l  a1,ss_ani_block(a2)             ; store address of this block for animation

; Obj09_GetEmer:
SonicSS_GetEmerald:
                cmpi.b  #ss_emeralds_num,(v_emeralds).w  ; do you already have all the emeralds?
                beq.s   SonicSS_NoEmerald               ; if yes, branch (probably a failsafe)

                subi.b  #id_SS_Emerald1_Blue,d4         ; make emerald block ID 0-based
                moveq   #0,d0                           ; clear d0
                move.b  (v_emeralds).w,d0               ; get number of emeralds already collected
                lea     (v_emldlist).w,a2               ; get array of previously collected emerald colors
                move.b  d4,(a2,d0.w)                    ; insert newly collected emerald color as newest entry

                addq.b  #1,(v_emeralds).w               ; add 1 to number of emeralds

; Obj09_NoEmer:
SonicSS_NoEmerald:
                move.w  #bgm_Emerald,d0                 ; set to emerald music
                jsr     (QueueSound2).l                 ; play it

                moveq   #0,d4                           ; regular item
                rts                                     ; return
; ===========================================================================

; Obj09_ChkGhost:
SonicSS_ChkGhost:
                cmpi.b  #id_SS_Ghost,d4                 ; is the item a ghost block?
                bne.s   SonicSS_ChkGhostTag             ; if not, branch

                move.b  #1,sonss_ghoststate(a0)         ; mark the ghost block as "passed" (one-way)

; Obj09_ChkGhostTag:
SonicSS_ChkGhostTag:
                cmpi.b  #id_SS_InvGhostTrigger,d4       ; is the item an invisible switch for ghost blocks?
                bne.s   SonicSS_NoItemBlock             ; if not, branch

                cmpi.b  #1,sonss_ghoststate(a0)         ; have the ghost blocks been passed?
                bne.s   SonicSS_NoItemBlock             ; if not, branch
                move.b  #2,sonss_ghoststate(a0)         ; trigger SonicSS_MakeGhostSolid

; Obj09_NoGhost:
SonicSS_NoItemBlock:
                moveq   #-1,d4                          ; is a ghost block or other non-item block
                rts                                     ; return

; ---------------------------------------------------------------------------
; Turn all ghost blocks in the stage layout into solid blocks, if flag is set
; ---------------------------------------------------------------------------

; Obj09_MakeGhostSolid:
SonicSS_MakeGhostSolid:
                cmpi.b  #2,sonss_ghoststate(a0)         ; have ghost block and then an invisible switch been passed?
                bne.s   SonicSS_GhostNotSolid           ; if not, branch

                lea     (v_sslayout_actual).l,a1        ; get start location of actual stage layout
                moveq   #(v_sslayout_end-v_sslayout_actual)/ss_layout_rowlength-1,d1  ; iterate through all rows
.nextrow:   moveq   #(ss_layout_rowlength/2)-1,d2  ; iterate through all blocks in row
.checkblock:   cmpi.b  #id_SS_Ghost,(a1)           ; is the item a ghost block?
                bne.s   .nextblock                      ; if not, branch
                move.b  #id_SS_RedWhite,(a1)            ; replace ghost block with a solid red/white block
.nextblock:   addq.w  #1,a1                       ; advance to next block in row
                dbf     d2,.checkblock                  ; loop until row is done
                lea     ss_layout_rowlength/2(a1),a1    ; advance to next row
                dbf     d1,.nextrow                     ; loop until all rows are done

; Obj09_GhostNotSolid:
SonicSS_GhostNotSolid:
                clr.b   sonss_ghoststate(a0)            ; clear ghost trigger flag so this doesn't run again

                moveq   #0,d4                           ; not a ghost block (by itself at least)
                rts                                     ; return
; End of function SonicSS_ChkItems_NotSolid

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to check for collision blocks that have solidity
; ---------------------------------------------------------------------------

; Obj09_ChkItems2: SonicSS_ChkItems2:
SonicSS_ChkItems_SolidActionBlock:
                move.b  sonss_touchedblock_id(a0),d0    ; was any solid block found during calls to SonicSS_FindWall?
                bne.s   SonicSS_ChkBumper               ; if yes, check which one it was

                subq.b  #1,sonss_timeout_updown(a0)     ; decrement the UP/DOWN blocks disable timeout
                bpl.s   .decrement_r                    ; if timeout remains, branch
                move.b  #0,sonss_timeout_updown(a0)     ; re-enable UP/DOWN blocks

; loc_1BEA0:
.decrement_r:
                subq.b  #1,sonss_timeout_r(a0)          ; decrement the R block disable timeout
                bpl.s   .return                         ; if timeout remains, branch
                move.b  #0,sonss_timeout_r(a0)          ; re-enable R blocks

; locret_1BEAC:
.return:
                rts                                     ; return
; ===========================================================================

; Obj09_ChkBumper:
SonicSS_ChkBumper:
                cmpi.b  #id_SS_Bumper,d0                ; is the item a bumper?
                bne.s   SonicSS_ChkGOAL                 ; if not, branch

                move.l  sonss_touchedblock_ram(a0),d1   ; get RAM location of touched bumper
                subi.l  #v_sslayout_base+1,d1           ; subtract by base RAM offset to get logical address
                move.w  d1,d2                           ; copy for second check

                andi.w  #ss_layout_rowlength-1,d1       ; limit to a single row ($7F)
                mulu.w  #ss_blocksize,d1                ; multiply by size per block
                subi.w  #20,d1                          ; manually adjust a bit; d1 now is bumper X coordinate

                lsr.w   #7,d2                           ; divide by row length ($80)
                andi.w  #ss_layout_rowlength-1,d2       ; limit to a single column ($7F)
                mulu.w  #ss_blocksize,d2                ; multiply by size per block
                subi.w  #20+(ss_blocksize*2),d2         ; manually adjust a bit; d1 now is bumper Y coordinate

                sub.w   obX(a0),d1                      ; subtract Sonic's X-pos from bumper X coordinate
                sub.w   obY(a0),d2                      ; subtract Sonic's Y-pos from bumper Y coordinate
                jsr     (CalcAngle).l                   ; calculate the angle of Sonic to target - atan2 of (dx,dy)
                jsr     (CalcSine).l                    ; calculate the sine (d0=Y-part) and cosine (d1=X-part) of the input angle in d0
                muls.w  #-$700,d1                       ; multiply X-speed by bumper force
                asr.l   #8,d1                           ; move result to lower word
                move.w  d1,obVelX(a0)                   ; set final result to Sonic's X-speed
                muls.w  #-$700,d0                       ; multiply Y-speed by bumper force
                asr.l   #8,d0                           ; move result to lower word
                move.w  d0,obVelY(a0)                   ; set final result to Sonic's Y-speed

                bset    #status_in_air_bit,obStatus(a0)  ; set in-air flag

                bsr.w   SS_FindFreeAnimationSlot        ; find a free animation slot
                bne.s   SonicSS_BumpSnd                 ; if none are free, branch
                _move.b #2,ss_ani_id(a2)                ; set to SS_AniBumper
                move.l  sonss_touchedblock_ram(a0),d0   ; get location in RAM of touched block
                subq.l  #1,d0                           ; actual touched block is the byte before it
                move.l  d0,ss_ani_block(a2)             ; store address of this block for animation

; Obj09_BumpSnd:
SonicSS_BumpSnd:
                move.w  #sfx_Bumper,d0                  ; set bumper sound
                jmp     (QueueSound2).l                 ; play it
; ===========================================================================

; Obj09_GOAL:
SonicSS_ChkGOAL:
                cmpi.b  #id_SS_GOAL,d0                  ; is the item a "GOAL"?
                bne.s   SonicSS_ChkUP                   ; if not, branch

                addq.b  #2,obRoutine(a0)                ; run routine "SonicSS_ExitStage"

                move.w  #sfx_SSGoal,d0                  ; set "GOAL" sound
                jsr     (QueueSound2).l                 ; play it
                rts                                     ; return
; ===========================================================================

; Obj09_UPblock:
SonicSS_ChkUP:
                cmpi.b  #id_SS_UP,d0                    ; is the item an "UP" block?
                bne.s   SonicSS_ChkDOWN                 ; if not, branch

                tst.b   sonss_timeout_updown(a0)        ; has an UP or DOWN block been touched recently?
                bne.w   SonicSS_NoSolidActionBlock      ; if yes, disable action until timeout has expired
                move.b  #ss_timeout,sonss_timeout_updown(a0)  ; set timeout to next action to half a second

; This check only works correctly if the base rotation speed is EXACTLY $40 (bit 6 = $40)
; It is by default, but altering the default speed in GM_Special will break UP/DOWN blocks
                btst    #6,(v_ssrotate+1).w             ; is stage already at fast speed? (either rotation)
                beq.s   SonicSS_UPsnd                   ; if yes, branch (prevent speeding up twice)

                asl.w   (v_ssrotate).w                  ; multiply current stage rotation speed by 2

; If this "UP" block successfully sped up the rotation, change it to a "DOWN" block
                movea.l sonss_touchedblock_ram(a0),a1   ; get location in RAM of touched block
                subq.l  #1,a1                           ; actual touched block is the byte before it
                move.b  #id_SS_DOWN,(a1)                ; change block to a "DOWN" block

; Obj09_UPsnd:
SonicSS_UPsnd:
                move.w  #sfx_SSItem,d0                  ; set blip sound
                jmp     (QueueSound2).l                 ; play it
; ===========================================================================

; Obj09_DOWNblock:
SonicSS_ChkDOWN:
                cmpi.b  #id_SS_DOWN,d0                  ; is the item a "DOWN" block?
                bne.s   SonicSS_ChkR                    ; if not, branch

                tst.b   sonss_timeout_updown(a0)        ; has an UP or DOWN block been touched recently?
                bne.w   SonicSS_NoSolidActionBlock      ; if yes, disable action until timeout has expired
                move.b  #ss_timeout,sonss_timeout_updown(a0)  ; set timeout to next action to half a second

; This check only works correctly if the base rotation speed is EXACTLY $40 (bit 6 = $40)
; It is by default, but altering the default speed in GM_Special will break UP/DOWN blocks
                btst    #6,(v_ssrotate+1).w             ; is stage already at slow speed? (either rotation)
                bne.s   SonicSS_DOWNsnd                 ; if yes, branch (prevent slowing down twice)

                asr.w   (v_ssrotate).w                  ; divide current stage rotation speed by 2

; If this "DOWN" block successfully slowed down the rotation, change it to an "UP" block
                movea.l sonss_touchedblock_ram(a0),a1   ; get location in RAM of touched block
                subq.l  #1,a1                           ; actual touched block is the byte before it
                move.b  #id_SS_UP,(a1)                  ; change block to an "UP" block

; Obj09_DOWNsnd:
SonicSS_DOWNsnd:
                move.w  #sfx_SSItem,d0                  ; set blip sound
                jmp     (QueueSound2).l                 ; play it
; ===========================================================================

; Obj09_Rblock:
SonicSS_ChkR:
                cmpi.b  #id_SS_R,d0                     ; is the item an "R" block?
                bne.s   SonicSS_ChkGlass                ; if not, branch

                tst.b   sonss_timeout_r(a0)             ; has an R block been touched recently?
                bne.w   SonicSS_NoSolidActionBlock      ; if yes, disable action until timeout has expired
                move.b  #ss_timeout,sonss_timeout_r(a0)  ; set timeout to next action to half a second

                bsr.w   SS_FindFreeAnimationSlot        ; find a free animation slot
                bne.s   SonicSS_RevStage                ; if none are free, branch
                _move.b #4,ss_ani_id(a2)                ; set to SS_AniReverse
                move.l  sonss_touchedblock_ram(a0),d0   ; get location in RAM of touched block
                subq.l  #1,d0                           ; actual touched block is the byte before it
                move.l  d0,ss_ani_block(a2)             ; store address of this block for animation

; Obj09_RevStage:
SonicSS_RevStage:
                neg.w   (v_ssrotate).w                  ; reverse stage rotation, preserving speed

                move.w  #sfx_SSItem,d0                  ; set blip sound
                jmp     (QueueSound2).l                 ; play it
; ===========================================================================

; Obj09_ChkGlass:
SonicSS_ChkGlass:
                cmpi.b  #id_SS_Glass1_Blue,d0           ; is the item a (blue) glass block?
                beq.s   SonicSS_Glass                   ; if yes, branch
                cmpi.b  #id_SS_Glass2_Green,d0          ; is the item a (green) glass block?
                beq.s   SonicSS_Glass                   ; if yes, branch
                cmpi.b  #id_SS_Glass3_Yellow,d0         ; is the item a (yellow) glass block?
                beq.s   SonicSS_Glass                   ; if yes, branch
                cmpi.b  #id_SS_Glass4_Pink,d0           ; is the item a (pink) glass block?
                bne.s   SonicSS_NoSolidActionBlock      ; if not, branch

; Obj09_Glass:
SonicSS_Glass:
                bsr.w   SS_FindFreeAnimationSlot        ; find a free animation slot
                bne.s   SonicSS_GlassSnd                ; if none are free, branch
                _move.b #6,ss_ani_id(a2)                ; set to SS_AniGlassBlock
                movea.l sonss_touchedblock_ram(a0),a1   ; get location in RAM of touched block
                subq.l  #1,a1                           ; actual touched block is the byte before it
                move.l  a1,ss_ani_block(a2)             ; store address of this block for animation

                move.b  (a1),d0                         ; get true ID of touched block
                addq.b  #1,d0                           ; advance to next glass type
                cmpi.b  #id_SS_Glass4_Pink,d0           ; would new ID exceed pink glass blocks?
                bls.s   SonicSS_GlassUpdate             ; if not, branch
                clr.b   d0                              ; otherwise, remove the glass block after pink ones

; Obj09_GlassUpdate:
SonicSS_GlassUpdate:
                move.b  d0,ss_ani_block(a2)             ; prepare updating glass with weaker version (see SS_AniGlassBlock)

; Obj09_GlassSnd:
SonicSS_GlassSnd:
                move.w  #sfx_SSGlass,d0                 ; set glass block sound
                jmp     (QueueSound2).l                 ; play it
; ===========================================================================

; Obj09_NoGlass:
SonicSS_NoSolidActionBlock:
                rts                                     ; block is no regular solid action block
; End of function SonicSS_ChkItems_Solid
