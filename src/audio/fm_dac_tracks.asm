DACUpdateTrack:
                subq.b  #1,SMPS_Track.DurationTimeout(a5)  ; has DAC sample timeout expired?
                bne.s   .locret                         ; return if not
                move.b  #$80,SMPS_RAM.f_updating_dac(a6)  ; set flag to indicate this is the DAC
; DACDoNext:
                movea.l SMPS_Track.DataPointer(a5),a4   ; dAC track data pointer
; loc_71C5E:
.sampleloop:
                moveq   #0,d5
                move.b  (a4)+,d5                        ; get next SMPS unit
                cmpi.b  #$E0,d5                         ; is it a coord. flag?
                blo.s   .notcoord                       ; branch if not
                jsr     CoordFlag(pc)
                bra.s   .sampleloop
; ===========================================================================
; loc_71C6E:
.notcoord:
                tst.b   d5                              ; is it a sample?
                bpl.s   .gotduration                    ; branch if not (duration)
                move.b  d5,SMPS_Track.SavedDAC(a5)      ; store new sample
                move.b  (a4)+,d5                        ; get another byte
                bpl.s   .gotduration                    ; branch if it is a duration
                subq.w  #1,a4                           ; put byte back
                move.b  SMPS_Track.SavedDuration(a5),SMPS_Track.DurationTimeout(a5)  ; use last duration
                bra.s   .gotsampleduration
; ===========================================================================
; loc_71C84:
.gotduration:
                jsr     SetDuration(pc)
; loc_71C88:
.gotsampleduration:
                move.l  a4,SMPS_Track.DataPointer(a5)   ; save pointer
                btst    #2,SMPS_Track.PlaybackControl(a5)  ; is track being overridden?
                bne.s   .locret                         ; return if yes
                moveq   #0,d0
                move.b  SMPS_Track.SavedDAC(a5),d0      ; get sample
                cmpi.b  #$80,d0                         ; is it a rest?
                beq.s   .locret                         ; return if yes
                btst    #3,d0                           ; is bit 3 set (samples between $88-$8F)?
                bne.s   .timpani                        ; various timpani
                move.b  d0,(z80_ram+zDAC_Sample).l
; locret_71CAA:
.locret:
                rts
; ===========================================================================
; loc_71CAC:
.timpani:
                subi.b  #$88,d0                         ; convert into an index
                move.b  DAC_sample_rate(pc,d0.w),d0
; Warning: this affects the raw pitch of sample $83, meaning it will
; use this value from then on
                move.b  d0,(z80_ram+zTimpani_Pitch).l
                move.b  #$83,(z80_ram+zDAC_Sample).l    ; use timpani
                rts
; End of function DACUpdateTrack

; ===========================================================================
; Note: this only defines rates for samples $88-$8D, meaning $8E-$8F are invalid
; Also, $8C-$8D are so slow you may want to skip them
; byte_71CC4:
timpaniLoopCounter   function scale,dpcmLoopCounter(int(zDAC_Timpani.sample_rate*scale))

DAC_sample_rate:
                dc.b    timpaniLoopCounter(1.30)
                dc.b    timpaniLoopCounter(1.20)
                dc.b    timpaniLoopCounter(0.97)
                dc.b    timpaniLoopCounter(0.95)
                dc.b    $FF, $FF
                even
; ===========================================================================

; sub_71CCA:
FMUpdateTrack:
                subq.b  #1,SMPS_Track.DurationTimeout(a5)  ; update duration timeout
                bne.s   .notegoing                      ; branch if it hasn't expired
                bclr    #4,SMPS_Track.PlaybackControl(a5)  ; clear 'do not attack next note' bit
                jsr     FMDoNext(pc)
                jsr     FMPrepareNote(pc)
                bra.w   FMNoteOn
; ===========================================================================
; loc_71CE0:
.notegoing:
                jsr     NoteTimeoutUpdate(pc)
                jsr     DoModulation(pc)
                bra.w   FMUpdateFreq
; End of function FMUpdateTrack
; ===========================================================================

; sub_71CEC:
FMDoNext:
                movea.l SMPS_Track.DataPointer(a5),a4   ; track data pointer
                bclr    #1,SMPS_Track.PlaybackControl(a5)  ; clear 'track at rest' bit
; loc_71CF4:
.noteloop:
                moveq   #0,d5
                move.b  (a4)+,d5                        ; get byte from track
                cmpi.b  #$E0,d5                         ; is this a coord. flag?
                blo.s   .gotnote                        ; branch if not
                jsr     CoordFlag(pc)
                bra.s   .noteloop
; ===========================================================================
; loc_71D04:
.gotnote:
                jsr     FMNoteOff(pc)
                tst.b   d5                              ; is this a note?
                bpl.s   .gotduration                    ; branch if not
                jsr     FMSetFreq(pc)
                move.b  (a4)+,d5                        ; get another byte
                bpl.s   .gotduration                    ; branch if it is a duration
                subq.w  #1,a4                           ; otherwise, put it back
                bra.w   FinishTrackUpdate
; ===========================================================================
; loc_71D1A:
.gotduration:
                jsr     SetDuration(pc)
                bra.w   FinishTrackUpdate
; End of function FMDoNext
; ===========================================================================

; sub_71D22:
FMSetFreq:
                subi.b  #$80,d5                         ; make it a zero-based index
                beq.s   TrackSetRest
                add.b   SMPS_Track.Transpose(a5),d5     ; add track transposition
                andi.w  #$7F,d5                         ; clear high byte and sign bit
                lsl.w   #1,d5
                lea     FMFrequencies(pc),a0
                move.w  (a0,d5.w),d6
                move.w  d6,SMPS_Track.Freq(a5)          ; store new frequency
                rts
; End of function FMSetFreq
; ===========================================================================

; sub_71D40:
SetDuration:
                move.b  d5,d0
                move.b  SMPS_Track.TempoDivider(a5),d1  ; get dividing timing
; loc_71D46:
.multloop:
                subq.b  #1,d1
                beq.s   .donemult
                add.b   d5,d0
                bra.s   .multloop
; ===========================================================================
; loc_71D4E:
.donemult:
                move.b  d0,SMPS_Track.SavedDuration(a5)  ; save duration
                move.b  d0,SMPS_Track.DurationTimeout(a5)  ; save duration timeout
                rts
; End of function SetDuration

; ===========================================================================
; loc_71D58:
TrackSetRest:
                bset    #1,SMPS_Track.PlaybackControl(a5)  ; set 'track at rest' bit
                clr.w   SMPS_Track.Freq(a5)             ; clear frequency
; ===========================================================================

; sub_71D60:
FinishTrackUpdate:
                move.l  a4,SMPS_Track.DataPointer(a5)   ; store new track position
                move.b  SMPS_Track.SavedDuration(a5),SMPS_Track.DurationTimeout(a5)  ; reset note timeout
                btst    #4,SMPS_Track.PlaybackControl(a5)  ; is track set to not attack note?
                bne.s   .locret                         ; if so, branch
                move.b  SMPS_Track.NoteTimeoutMaster(a5),SMPS_Track.NoteTimeout(a5)  ; reset note fill timeout
                clr.b   SMPS_Track.VolEnvIndex(a5)      ; reset PSG volume envelope index (even on FM tracks...)
                btst    #3,SMPS_Track.PlaybackControl(a5)  ; is modulation on?
                beq.s   .locret                         ; if not, return
                movea.l SMPS_Track.ModulationPtr(a5),a0  ; modulation data pointer
                move.b  (a0)+,SMPS_Track.ModulationWait(a5)  ; reset wait
                move.b  (a0)+,SMPS_Track.ModulationSpeed(a5)  ; reset speed
                move.b  (a0)+,SMPS_Track.ModulationDelta(a5)  ; reset delta
                move.b  (a0)+,d0                        ; get steps
                lsr.b   #1,d0                           ; halve them
                move.b  d0,SMPS_Track.ModulationSteps(a5)  ; then store
                clr.w   SMPS_Track.ModulationVal(a5)    ; reset frequency change
; locret_71D9C:
.locret:
                rts
; End of function FinishTrackUpdate
; ===========================================================================

; sub_71D9E: NoteFillUpdate
NoteTimeoutUpdate:
                tst.b   SMPS_Track.NoteTimeout(a5)      ; is note fill on?
                beq.s   .locret
                subq.b  #1,SMPS_Track.NoteTimeout(a5)   ; update note fill timeout
                bne.s   .locret                         ; return if it hasn't expired
                bset    #1,SMPS_Track.PlaybackControl(a5)  ; put track at rest
                tst.b   SMPS_Track.VoiceControl(a5)     ; is this a PSG track?
                bmi.w   .psgnoteoff                     ; if yes, branch
                jsr     FMNoteOff(pc)
                addq.w  #4,sp                           ; do not return to caller
                rts
; ===========================================================================
; loc_71DBE:
.psgnoteoff:
                jsr     PSGNoteOff(pc)
                addq.w  #4,sp                           ; do not return to caller
; locret_71DC4:
.locret:
                rts
; End of function NoteTimeoutUpdate
; ===========================================================================

; sub_71DC6:
DoModulation:
                addq.w  #4,sp                           ; do not return to caller (but see below)
                btst    #3,SMPS_Track.PlaybackControl(a5)  ; is modulation active?
                beq.s   .locret                         ; return if not
                tst.b   SMPS_Track.ModulationWait(a5)   ; has modulation wait expired?
                beq.s   .waitdone                       ; if yes, branch
                subq.b  #1,SMPS_Track.ModulationWait(a5)  ; update wait timeout
                rts
; ===========================================================================
; loc_71DDA:
.waitdone:
                subq.b  #1,SMPS_Track.ModulationSpeed(a5)  ; update speed
                beq.s   .updatemodulation               ; if it expired, want to update modulation
                rts
; ===========================================================================
; loc_71DE2:
.updatemodulation:
                movea.l SMPS_Track.ModulationPtr(a5),a0  ; get modulation data
                move.b  1(a0),SMPS_Track.ModulationSpeed(a5)  ; restore modulation speed
                tst.b   SMPS_Track.ModulationSteps(a5)  ; check number of steps
                bne.s   .calcfreq                       ; if nonzero, branch
                move.b  3(a0),SMPS_Track.ModulationSteps(a5)  ; restore from modulation data
                neg.b   SMPS_Track.ModulationDelta(a5)  ; negate modulation delta
                rts
; ===========================================================================
; loc_71DFE:
.calcfreq:
                subq.b  #1,SMPS_Track.ModulationSteps(a5)  ; update modulation steps
                move.b  SMPS_Track.ModulationDelta(a5),d6  ; get modulation delta
                ext.w   d6
                add.w   SMPS_Track.ModulationVal(a5),d6  ; add cumulative modulation change
                move.w  d6,SMPS_Track.ModulationVal(a5)  ; store it
                add.w   SMPS_Track.Freq(a5),d6          ; add note frequency to it
                subq.w  #4,sp                           ; in this case, we want to return to caller after all
; locret_71E16:
.locret:
                rts
; End of function DoModulation
; ===========================================================================

; sub_71E18:
FMPrepareNote:
                btst    #1,SMPS_Track.PlaybackControl(a5)  ; is track resting?
                bne.s   locret_71E48                    ; return if so
                move.w  SMPS_Track.Freq(a5),d6          ; get current note frequency
                beq.s   FMSetRest                       ; branch if zero
; loc_71E24:
FMUpdateFreq:
                move.b  SMPS_Track.Detune(a5),d0        ; get detune value
                ext.w   d0
                add.w   d0,d6                           ; add note frequency
                btst    #2,SMPS_Track.PlaybackControl(a5)  ; is track being overridden?
                bne.s   locret_71E48                    ; return if so
                move.w  d6,d1
                lsr.w   #8,d1
                move.b  #$A4,d0                         ; register for upper 6 bits of frequency
                jsr     WriteFMIorII(pc)
                move.b  d6,d1
                move.b  #$A0,d0                         ; register for lower 8 bits of frequency
                jsr     WriteFMIorII(pc)                ; (it would be better if this were a jmp)
; locret_71E48:
locret_71E48:
                rts
; ===========================================================================
; loc_71E4A:
FMSetRest:
                bset    #1,SMPS_Track.PlaybackControl(a5)  ; set 'track at rest' bit
                rts
; End of function FMPrepareNote

; ===========================================================================
; loc_71E50:
