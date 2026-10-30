Sonic_Animate:
                lea     (Ani_Sonic).l,a1                ; load Sonic's animation scripts
                moveq   #0,d0                           ; clear d0
                move.b  obAnim(a0),d0                   ; get Sonic's currently set animation ID
                cmp.b   obPrevAni(a0),d0                ; does it differ from the previous animation? (i.e. has animation changed?)
                beq.s   .do                             ; if not, branch
                move.b  d0,obPrevAni(a0)                ; remember new animation
                move.b  #0,obAniFrame(a0)               ; restart animation from beginning
                move.b  #0,obTimeFrame(a0)              ; reset animation frame duration

; SAnim_Do:
.do:
                add.w   d0,d0                           ; double animation ID for word-based indexing
                adda.w  (a1,d0.w),a1                    ; jump to appropriate animation script
                move.b  (a1),d0                         ; load frame interval for this animation
                bmi.s   .walkrunroll                    ; if frame interval is negative, this is a special walk/run/roll/jump animation, branch

                move.b  obStatus(a0),d1                 ; get Sonic's status bitfield
                andi.b  #status_xflip,d1                ; mask out everything but the X-flip flag
                andi.b  #~(sprite_xflip|sprite_yflip),obRender(a0)  ; clear X-flip and Y-flip flags in Sonic's render flags
                or.b    d1,obRender(a0)                 ; set new X-flip flag state

                subq.b  #1,obTimeFrame(a0)              ; subtract 1 from frame duration
                bpl.s   .delay                          ; if time remains, branch
                move.b  d0,obTimeFrame(a0)              ; reset frame duration

; SAnim_Do2:
.loadframe:
                moveq   #0,d1                           ; clear d1
                move.b  obAniFrame(a0),d1               ; load current frame number
                move.b  1(a1,d1.w),d0                   ; read sprite number from script
                bmi.s   .end_FF                         ; if animation is complete, branch

; SAnim_Next:
.next:
                move.b  d0,obFrame(a0)                  ; load sprite number
                addq.b  #1,obAniFrame(a0)               ; next frame number

; SAnim_Delay:
.delay:
                rts                                     ; return
; ===========================================================================

; SAnim_End_FF:
.end_FF:
                addq.b  #1,d0                           ; is this the afEnd flag ($FF)?
                bne.s   .end_FE                         ; if not, branch
                move.b  #0,obAniFrame(a0)               ; restart the animation
                move.b  1(a1),d0                        ; read sprite number
                bra.s   .next                           ; set new frame
; ===========================================================================

; SAnim_End_FE
.end_FE:
                addq.b  #1,d0                           ; is this the afBack flag ($FE)?
                bne.s   .end_FD                         ; if not, branch
                move.b  2(a1,d1.w),d0                   ; read the next byte in the script
                sub.b   d0,obAniFrame(a0)               ; jump back d0 bytes in the script
                sub.b   d0,d1                           ; adjust sprite index
                move.b  1(a1,d1.w),d0                   ; read new sprite number
                bra.s   .next                           ; set new frame
; ===========================================================================

; SAnim_End_FD:
.end_FD:
                addq.b  #1,d0                           ; is this the afChange flag ($FD)?
                bne.s   .end                            ; if not, branch
                move.b  2(a1,d1.w),obAnim(a0)           ; read next byte, run that animation

; SAnim_End:
.end:
                rts                                     ; return
; ===========================================================================

; SAnim_WalkRun:
.walkrunroll:
                subq.b  #1,obTimeFrame(a0)              ; subtract 1 from frame duration
                bpl.s   .delay                          ; if time remains, branch
                addq.b  #1,d0                           ; is animation walking/running?
                bne.w   .rolljump                       ; if not, branch
                moveq   #0,d1                           ; clear d1 (do not alter flip flags)
                move.b  obAngle(a0),d0                  ; get Sonic's angle
                move.b  obStatus(a0),d2                 ; get Sonic's current status bitfield
                andi.b  #status_xflip,d2                ; mask out anything but the X-flip flag
                bne.s   .flip                           ; is Sonic mirrored horizontally? if yes, branch
                not.b   d0                              ; reverse angle
; loc_13A70:
.flip:
                addi.b  #$10,d0                         ; add $10 to angle
                bpl.s   .noinvert                       ; if angle is $0-$7F, branch
                moveq   #sprite_xflip|sprite_yflip,d1   ; invert both flip flags
; loc_13A78:
.noinvert:
                andi.b  #~(sprite_xflip|sprite_yflip),obRender(a0)  ; clear current flip flags
                eor.b   d1,d2                           ; invert flip flags depending on current angle
                or.b    d2,obRender(a0)                 ; set new flip flags

                btst    #status_pushing_bit,obStatus(a0)  ; is Sonic pushing something?
                bne.w   .push                           ; if yes, branch

                lsr.b   #4,d0                           ; divide angle by $10
                andi.b  #6,d0                           ; angle must be 0, 2, 4 or 6 (this is now the octant modifier)
                move.w  obInertia(a0),d2                ; get Sonic's ground speed
                bpl.s   .nomodspeed                     ; if it's positive, branch
                neg.w   d2                              ; otherwise, make it positive

; loc_13A9C:
.nomodspeed:
                lea     (SonAni_Run).l,a1               ; use running animation
                cmpi.w  #$600,d2                        ; is Sonic at running speed?
                bhs.s   .running                        ; if yes, branch

                lea     (SonAni_Walk).l,a1              ; use walking animation instead
                move.b  d0,d1                           ; make octant modifier a multiple of 3
                lsr.b   #1,d1                           ; (0, 3, 6, 9)
                add.b   d1,d0                           ; this accounts for 6 total walking frames (Sonic 2 would change this to support 8)

; loc_13AB4:
.running:
                add.b   d0,d0                           ; multiply octant modifier by 2
                move.b  d0,d3                           ; (becomes multiple of 4 for running (0, 4, 8, 12), multiple of 6 for walking (0, 6, 12, 18))
                neg.w   d2                              ; make speed negative
                addi.w  #$800,d2                        ; add a significant amount of speed (-$600+$800 >> 8 would result in a frame interval of 2)
                bpl.s   .belowmax                       ; if result is positive, use that as frame interval
                moveq   #0,d2                           ; otherwise, set max animation speed

; loc_13AC2:
.belowmax:
                lsr.w   #8,d2                           ; shift down by one byte
                move.b  d2,obTimeFrame(a0)              ; modify frame duration
                bsr.w   .loadframe                      ; update current frame
                add.b   d3,obFrame(a0)                  ; modify frame number
                rts                                     ; return
; ===========================================================================

; SAnim_RollJump:
.rolljump:
                addq.b  #1,d0                           ; is animation rolling/jumping?
                bne.s   .push                           ; if not, branch
                move.w  obInertia(a0),d2                ; get Sonic's speed
                bpl.s   .nomodspeed2                    ; is it positive? if yes, branch
                neg.w   d2                              ; otherwise, make it positive

; loc_13ADE:
.nomodspeed2:
                lea     (SonAni_Roll2).l,a1             ; use fast rolling animation
                cmpi.w  #$600,d2                        ; is Sonic moving fast?
                bhs.s   .rollfast                       ; if yes, branch
                lea     (SonAni_Roll).l,a1              ; use slower rolling animation instead

; loc_13AF0:
.rollfast:
                neg.w   d2                              ; make speed negative
                addi.w  #$400,d2                        ; add a significant amount of speed (-$200+$400 >> 8 would result in a frame interval of 2)
                bpl.s   .belowmax2                      ; if result is positive, use that as frame interval
                moveq   #0,d2                           ; otherwise, set maximum animation speed

; loc_13AFA:
.belowmax2:
                lsr.w   #8,d2                           ; shift down a byte
                move.b  d2,obTimeFrame(a0)              ; modify frame duration

                move.b  obStatus(a0),d1                 ; get Sonic's current status flags
                andi.b  #status_xflip,d1                ; mask out everything but the X-flip flag
                andi.b  #~(sprite_xflip|sprite_yflip),obRender(a0)  ; clear Sonic's current flip flags
                or.b    d1,obRender(a0)                 ; set new X-flip flag
                bra.w   .loadframe                      ; update current frame
; ===========================================================================

; SAnim_Push:
.push:
                move.w  obInertia(a0),d2                ; get Sonic's speed
                bmi.s   .negspeed                       ; if it's negative, branch
                neg.w   d2                              ; otherwise, make it negative

; loc_13B1E:
.negspeed:
                addi.w  #$800,d2                        ; add a significant amount of speed (-$100+$700 >> 6 would result in a frame interval of 7)
                bpl.s   .belowmax3                      ; if result is positive, use that as frame interval
                moveq   #0,d2                           ; otherwise, set maximum animation speed (with pushing, this shouldn't ever happen...)

; loc_13B26:
.belowmax3:
                lsr.w   #6,d2                           ; shift down a byte and further multiply frame interval by 4
                move.b  d2,obTimeFrame(a0)              ; modify frame duration

                lea     (SonAni_Push).l,a1              ; load Sonic's animation script for pushing

                move.b  obStatus(a0),d1                 ; get Sonic's current status flags
                andi.b  #status_xflip,d1                ; mask out everything but the X-flip flag
                andi.b  #~(sprite_xflip|sprite_yflip),obRender(a0)  ; clear Sonic's current flip flags
                or.b    d1,obRender(a0)                 ; set new X-flip flag
                bra.w   .loadframe                      ; update current frame
; End of function Sonic_Animate

; ---------------------------------------------------------------------------
; Animation scripts - Sonic (also includes constants for frame IDs)
; SonicAniData:
                include "src/rendering/animation/Sonic.asm"
; ---------------------------------------------------------------------------

; ===========================================================================
; ---------------------------------------------------------------------------
; Sonic graphics loading subroutine (DPLC - Dynamic Pattern Load Cues)
; ---------------------------------------------------------------------------

; LoadSonicDynPLC:
Sonic_LoadGfx:
                moveq   #0,d0
                move.b  obFrame(a0),d0                  ; load frame number
                cmp.b   (v_sonframenum).w,d0            ; has frame changed?
                beq.s   .nochange                       ; if not, branch (nothing to do)

                move.b  d0,(v_sonframenum).w            ; remember new frame ID
                lea     (SonicDynPLC).l,a2              ; load PLC script
                add.w   d0,d0                           ; double current frame for word-based indexing
                adda.w  (a2,d0.w),a2                    ; find relevant DPLC definition for new frame
                moveq   #0,d1                           ; clear d1
                move.b  (a2)+,d1                        ; read "number of entries" value
                subq.b  #1,d1                           ; subtract by 1 for first iteration
                bmi.s   .nochange                       ; if this was an empty entry, nothing to do, branch

                lea     (v_sgfx_buffer).w,a3            ; load Sonic's graphics transfer buffer
                move.b  #1,(f_sonframechg).w            ; set flag for VBlank to update Sonic graphics via DMA

; SPLC_ReadEntry:
.readentry:
                moveq   #0,d2                           ; clear d2
                move.b  (a2)+,d2                        ; read next byte of DPLC entry
                move.w  d2,d0                           ; copy to d0
                lsr.b   #4,d0                           ; shift out lower nybble, upper nybble is number of tiles
                lsl.w   #8,d2                           ; shift value into upper byte of word
                move.b  (a2)+,d2                        ; read next byte of DPLC entry
                lsl.w   #5,d2                           ; multiply by $20 (tile_size)
                lea     (Art_Sonic).l,a1                ; load Sonic's uncompressed graphics
                adda.l  d2,a1                           ; add offset for current DPLC entry

; SPLC_LoadTile:
.loadtile:
                movem.l (a1)+,d2-d6/a4-a6               ; copy a full tile's worth of data to 8 different registers
                movem.l d2-d6/a4-a6,(a3)                ; write them to Sonic's graphics transfer buffer
                lea     tile_size(a3),a3                ; go to next tile
                dbf     d0,.loadtile                    ; repeat for number of tiles
                dbf     d1,.readentry                   ; repeat for number of entries

; locret_13C96:
.nochange:
                rts                                     ; return
; End of function Sonic_LoadGfx
; ===========================================================================
