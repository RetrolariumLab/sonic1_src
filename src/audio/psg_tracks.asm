PSGUpdateTrack:
                subq.b  #1,SMPS_Track.DurationTimeout(a5)  ; update note timeout
                bne.s   .notegoing
                bclr    #4,SMPS_Track.PlaybackControl(a5)  ; clear 'do not attack note' bit
                jsr     PSGDoNext(pc)
                jsr     PSGDoNoteOn(pc)
                bra.w   PSGDoVolFX
; ===========================================================================
; loc_72866:
.notegoing:
                jsr     NoteTimeoutUpdate(pc)
                jsr     PSGUpdateVolFX(pc)
                jsr     DoModulation(pc)
                jsr     PSGUpdateFreq(pc)               ; it would be better if this were a jmp and the rts was removed
                rts
; End of function PSGUpdateTrack
; ===========================================================================

; sub_72878:
PSGDoNext:
                bclr    #1,SMPS_Track.PlaybackControl(a5)  ; clear 'track at rest' bit
                movea.l SMPS_Track.DataPointer(a5),a4   ; get track data pointer
; loc_72880:
.noteloop:
                moveq   #0,d5
                move.b  (a4)+,d5                        ; get byte from track
                cmpi.b  #$E0,d5                         ; is it a coord. flag?
                blo.s   .gotnote                        ; branch if not
                jsr     CoordFlag(pc)
                bra.s   .noteloop
; ===========================================================================
; loc_72890:
.gotnote:
                tst.b   d5                              ; is it a note?
                bpl.s   .gotduration                    ; branch if not
                jsr     PSGSetFreq(pc)
                move.b  (a4)+,d5                        ; get another byte
                tst.b   d5                              ; is it a duration?
                bpl.s   .gotduration                    ; branch if yes
                subq.w  #1,a4                           ; put byte back
                bra.w   FinishTrackUpdate
; ===========================================================================
; loc_728A4:
.gotduration:
                jsr     SetDuration(pc)
                bra.w   FinishTrackUpdate
; End of function PSGDoNext
; ===========================================================================

; sub_728AC:
PSGSetFreq:
                subi.b  #$81,d5                         ; convert to 0-based index
                bcs.s   .restpsg                        ; if $80, put track at rest
                add.b   SMPS_Track.Transpose(a5),d5     ; add in channel transposition
                andi.w  #$7F,d5                         ; clear high byte and sign bit
                lsl.w   #1,d5
                lea     PSGFrequencies(pc),a0
                move.w  (a0,d5.w),SMPS_Track.Freq(a5)   ; set new frequency
                bra.w   FinishTrackUpdate
; ===========================================================================
; loc_728CA:
.restpsg:
                bset    #1,SMPS_Track.PlaybackControl(a5)  ; set 'track at rest' bit
                move.w  #-1,SMPS_Track.Freq(a5)         ; invalidate note frequency
                jsr     FinishTrackUpdate(pc)
                bra.w   PSGNoteOff
; End of function PSGSetFreq
; ===========================================================================

; sub_728DC:
PSGDoNoteOn:
                move.w  SMPS_Track.Freq(a5),d6          ; get note frequency
                bmi.s   PSGSetRest                      ; if invalid, branch
; End of function PSGDoNoteOn
; ===========================================================================

; sub_728E2:
PSGUpdateFreq:
                move.b  SMPS_Track.Detune(a5),d0        ; get detune value
                ext.w   d0
                add.w   d0,d6                           ; add to frequency
                btst    #2,SMPS_Track.PlaybackControl(a5)  ; is track being overridden?
                bne.s   .locret                         ; return if yes
                btst    #1,SMPS_Track.PlaybackControl(a5)  ; is track at rest?
                bne.s   .locret                         ; return if yes
                move.b  SMPS_Track.VoiceControl(a5),d0  ; get channel bits
                cmpi.b  #$E0,d0                         ; is it a noise channel?
                bne.s   .notnoise                       ; branch if not
                move.b  #$C0,d0                         ; use PSG 3 channel bits
; loc_72904:
.notnoise:
                move.w  d6,d1
                andi.b  #$F,d1                          ; low nibble of frequency
                or.b    d1,d0                           ; latch tone data to channel
                lsr.w   #4,d6                           ; get upper 6 bits of frequency
                andi.b  #$3F,d6                         ; send to latched channel
                move.b  d0,(psg_input).l
                move.b  d6,(psg_input).l
; locret_7291E:
.locret:
                rts
; End of function PSGUpdateFreq

; ===========================================================================
; loc_72920:
PSGSetRest:
                bset    #1,SMPS_Track.PlaybackControl(a5)  ; set 'track at rest' bit
                rts
; ===========================================================================

; sub_72926:
PSGUpdateVolFX:
                tst.b   SMPS_Track.VoiceIndex(a5)       ; test PSG tone
                beq.w   locret_7298A                    ; return if it is zero
; loc_7292E:
PSGDoVolFX:
                move.b  SMPS_Track.Volume(a5),d6        ; get volume
                moveq   #0,d0
                move.b  SMPS_Track.VoiceIndex(a5),d0    ; get PSG tone
                beq.s   SetPSGVolume
                movea.l (Go_PSGIndex).l,a0
                subq.w  #1,d0
                lsl.w   #2,d0
                movea.l (a0,d0.w),a0

                move.b  SMPS_Track.VolEnvIndex(a5),d0   ; get volume envelope index
                move.b  (a0,d0.w),d0                    ; volume envelope value
                addq.b  #1,SMPS_Track.VolEnvIndex(a5)   ; increment volume envelope index
                btst    #7,d0                           ; is volume envelope value negative?
                beq.s   .gotflutter                     ; branch if not
                cmpi.b  #$80,d0                         ; is it the terminator?
                beq.s   VolEnvHold                      ; if so, branch

; loc_72960:
.gotflutter:
                add.w   d0,d6                           ; add volume envelope value to volume
                cmpi.b  #$10,d6                         ; is volume $10 or higher?
                blo.s   SetPSGVolume                    ; branch if not
                moveq   #$F,d6                          ; limit to silence and fall through
; End of function PSGUpdateVolFX
; ===========================================================================

; sub_7296A:
SetPSGVolume:
                btst    #1,SMPS_Track.PlaybackControl(a5)  ; is track at rest?
                bne.s   locret_7298A                    ; return if so
                btst    #2,SMPS_Track.PlaybackControl(a5)  ; is SFX overriding?
                bne.s   locret_7298A                    ; return if so
                btst    #4,SMPS_Track.PlaybackControl(a5)  ; is track set to not attack next note?
                bne.s   PSGCheckNoteTimeout             ; branch if yes
; loc_7297C:
PSGSendVolume:
                or.b    SMPS_Track.VoiceControl(a5),d6  ; add in track selector bits
                addi.b  #$10,d6                         ; mark it as a volume command
                move.b  d6,(psg_input).l

locret_7298A:
                rts
; ===========================================================================
; loc_7298C: PSGCheckNoteFill:
PSGCheckNoteTimeout:
                tst.b   SMPS_Track.NoteTimeoutMaster(a5)  ; is note timeout on?
                beq.s   PSGSendVolume                   ; branch if not
                tst.b   SMPS_Track.NoteTimeout(a5)      ; has note timeout expired?
                bne.s   PSGSendVolume                   ; branch if not
                rts
; End of function SetPSGVolume

; ===========================================================================
; loc_7299A: FlutterDone:
VolEnvHold:
                subq.b  #1,SMPS_Track.VolEnvIndex(a5)   ; decrement volume envelope index
                rts
; ===========================================================================

; sub_729A0:
PSGNoteOff:
                btst    #2,SMPS_Track.PlaybackControl(a5)  ; is SFX overriding?
                bne.s   locret_729B4                    ; return if so
; loc_729A6:
SendPSGNoteOff:
                move.b  SMPS_Track.VoiceControl(a5),d0  ; PSG channel to change
                ori.b   #$1F,d0                         ; maximum volume attenuation
                move.b  d0,(psg_input).l

locret_729B4:
                rts
; End of function PSGNoteOff
; ===========================================================================

; sub_729B6:
PSGSilenceAll:
                lea     (psg_input).l,a0
                move.b  #$9F,(a0)                       ; silence PSG 1
                move.b  #$BF,(a0)                       ; silence PSG 2
                move.b  #$DF,(a0)                       ; silence PSG 3
                move.b  #$FF,(a0)                       ; silence noise channel
                rts
; End of function PSGSilenceAll

; ===========================================================================
; ---------------------------------------------------------------------------
; PSG Note Values: c-1 to a-6
;
; Each row is an octave, starting with C and ending with B. Sonic 3's driver
; adds another octave at the start, as well as two more notes and the end to
; complete the last octave. Notably, a-6 is changed from 223721.56Hz to
; 6991.28Hz. These changes need to be applied here in order for ports of
; songs from Sonic 3 and later to sound correct
;
; Here is what Sonic 3's version of this table looks like:
; MakePSGFrequencies  109.34,    109.34,    109.34,    109.34,    109.34,    109.34,    109.34,    109.34,    109.34,    110.20,    116.76,    123.73
; MakePSGFrequencies  130.98,    138.78,    146.99,    155.79,    165.22,    174.78,    185.19,    196.24,    207.91,    220.63,    233.52,    247.47
; MakePSGFrequencies  261.96,    277.56,    293.59,    311.58,    329.97,    349.56,    370.39,    392.49,    415.83,    440.39,    468.03,    494.95
; MakePSGFrequencies  522.71,    556.51,    588.73,    621.44,    661.89,    699.12,    740.79,    782.24,    828.59,    880.79,    932.17,    989.91
; MakePSGFrequencies 1045.42,   1107.52,   1177.47,   1242.89,   1316.00,   1398.25,   1491.47,   1575.50,   1669.55,   1747.82,   1864.34,   1962.46
; MakePSGFrequencies 2071.49,   2193.34,   2330.42,   2485.78,   2601.40,   2796.51,   2943.69,   3107.23,   3290.01,   3495.64,   3608.40,   3857.25
; MakePSGFrequencies 4142.98,   4302.32,   4660.85,   4863.50,   5084.56,   5326.69,   5887.39,   6214.47,   6580.02,   6991.28, 223721.56, 223721.56
; ---------------------------------------------------------------------------
MakePSGFrequency   function frequency,min($3FF,roundFloatToInteger(PSG_Sample_Rate/(frequency*2)))
MakePSGFrequencies   macro
                    irp     op,ALLARGS
                    dc.w    MakePSGFrequency(op)
                endm
                endm

; word_729CE:
PSGFrequencies:
                MakePSGFrequencies 130.98,    138.78,    146.99,    155.79,    165.22,    174.78,    185.19,    196.24,    207.91,    220.63,    233.52,    247.47
                MakePSGFrequencies 261.96,    277.56,    293.59,    311.58,    329.97,    349.56,    370.39,    392.49,    415.83,    440.39,    468.03,    494.95
                MakePSGFrequencies 522.71,    556.51,    588.73,    621.44,    661.89,    699.12,    740.79,    782.24,    828.59,    880.79,    932.17,    989.91
                MakePSGFrequencies 1045.42,   1107.52,   1177.47,   1242.89,   1316.00,   1398.25,   1491.47,   1575.50,   1669.55,   1747.82,   1864.34,   1962.46
                MakePSGFrequencies 2071.49,   2193.34,   2330.42,   2485.78,   2601.40,   2796.51,   2943.69,   3107.23,   3290.01,   3495.64,   3608.40,   3857.25
                MakePSGFrequencies 4142.98,   4302.32,   4660.85,   4863.50,   5084.56,   5326.69,   5887.39,   6214.47,   6580.02, 223721.56
; ===========================================================================

; sub_72A5A:
