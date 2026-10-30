ColIndexLoad:
                moveq   #0,d0                           ; clear d0
                move.b  (v_zone).w,d0                   ; get current zone ID
                lsl.w   #2,d0                           ; multiply by 4 for long-based indexing
                move.l  ColPointers(pc,d0.w),(v_collindex).w  ; set collision index pointer for current zone
                rts                                     ; return
; End of function ColIndexLoad

; ---------------------------------------------------------------------------
; Collision index pointers
; ---------------------------------------------------------------------------

ColPointers:   dc.l    Col_GHZ
                dc.l    Col_LZ
                dc.l    Col_MZ
                dc.l    Col_SLZ
                dc.l    Col_SYZ
                dc.l    Col_SBZ
                zonewarning ColPointers,4
; The ending doesn't get an entry, as it's hardcoded to use Col_GHZ
                even

; ===========================================================================
; >>> Routines to set and update values that change on a fixed timer
                include "src/game/world/oscillatory_routines.s"

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to change synchronised animation variables (rings, giant rings)
; ---------------------------------------------------------------------------

SynchroAnimate:

; Used for GHZ spiked log
Sync1:
                subq.b  #1,(v_ani0_time).w              ; has first timer reached 0?
                bpl.s   Sync2                           ; if not, branch
                move.b  #12-1,(v_ani0_time).w           ; reset first timer to 12 frames
                subq.b  #1,(v_ani0_frame).w             ; go to next frame (backwards)
                andi.b  #7,(v_ani0_frame).w             ; limit to frames 0-7

; Used for rings and giant rings
Sync2:
                subq.b  #1,(v_ani1_time).w              ; has second timer reached 0?
                bpl.s   Sync3                           ; if not, branch
                move.b  #8-1,(v_ani1_time).w            ; reset second timer to 8 frames
                addq.b  #1,(v_ani1_frame).w             ; go to next frame
                andi.b  #3,(v_ani1_frame).w             ; limit to frames 0-3

; Used for nothing
Sync3:
                subq.b  #1,(v_ani2_time).w              ; has third timer reached 0?
                bpl.s   Sync4                           ; if not, branch
                move.b  #8-1,(v_ani2_time).w            ; reset third timer to 8 frames
                addq.b  #1,(v_ani2_frame).w             ; go to next frame
                cmpi.b  #6,(v_ani2_frame).w             ; limit to frames 0-5
                blo.s   Sync4                           ; if still frame 0-5, branch
                move.b  #0,(v_ani2_frame).w             ; set to frame 0 when it reached frame 6

; Used for bouncing rings
Sync4:
                tst.b   (v_ani3_time).w                 ; is ring loss timer active at all?
                beq.s   SyncEnd                         ; if not, don't advance animation
                moveq   #0,d0                           ; clear d0
                move.b  (v_ani3_time).w,d0              ; get remaining ring loss timer
                add.w   (v_ani3_buf).w,d0               ; add buffered timer value
                move.w  d0,(v_ani3_buf).w               ; set that as new buffered timer
                rol.w   #7,d0                           ; align for speed
                andi.w  #3,d0                           ; limit to frames 0-3
                move.b  d0,(v_ani3_frame).w             ; set as current frame for lost rings
                subq.b  #1,(v_ani3_time).w              ; decrease ring loss timer

SyncEnd:
                rts                                     ; return
; End of function SynchroAnimate

; ===========================================================================
; ---------------------------------------------------------------------------
; End-of-act signpost pattern loading subroutine. Also locks left boundary
; ---------------------------------------------------------------------------

SignpostArtLoad:
                tst.w   (v_debuguse).w                  ; is debug mode being used?
                bne.w   .return                         ; if yes, do not lock screen or load art
                cmpi.b  #act3,(v_act).w                 ; is this a third act?
                beq.s   .return                         ; if yes, don't load art (due to the boss fight)

                move.w  (v_screenposx).w,d0             ; get current X-camera position
                move.w  (v_limitright2).w,d1            ; get right level boundary
                subi.w  #$100,d1                        ; check for $100 pixels before the right boundary
                cmp.w   d1,d0                           ; has Sonic reached the right edge of the level?
                blt.s   .return                         ; if not, branch

                tst.b   (f_timecount).w                 ; has time already stopped from touching the signpost?
                beq.s   .return                         ; if yes, branch
                cmp.w   (v_limitleft2).w,d1             ; has left boundary already been locked?
                beq.s   .return                         ; if yes, branch
                move.w  d1,(v_limitleft2).w             ; lock left level boundary to current screen position
                moveq   #plcid_Signpost,d0              ; load signpost, hidden points, giant ring flash patterns
                bra.w   NewPLC                          ; add to new PLC queue

.return:
                rts                                     ; return
; End of function SignpostArtLoad

; ===========================================================================
; >>> Demo inputs for title screen demos
Demo_GHZ:   include "src/game/demos/attract/ghz.s"
Demo_MZ:   include "src/game/demos/attract/mz.s"
Demo_SYZ:   include "src/game/demos/attract/syz.s"
Demo_SS:   include "src/game/demos/attract/special_stage.s"

; ===========================================================================
; ---------------------------------------------------------------------------
; Special Stage
; ---------------------------------------------------------------------------

; SpecialStage:
