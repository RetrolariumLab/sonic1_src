cfModulation:
                bset    #3,SMPS_Track.PlaybackControl(a5)  ; turn on modulation
                move.l  a4,SMPS_Track.ModulationPtr(a5)  ; save pointer to modulation data
                move.b  (a4)+,SMPS_Track.ModulationWait(a5)  ; modulation delay
                move.b  (a4)+,SMPS_Track.ModulationSpeed(a5)  ; modulation speed
                move.b  (a4)+,SMPS_Track.ModulationDelta(a5)  ; modulation delta
                move.b  (a4)+,d0                        ; modulation steps
                lsr.b   #1,d0                           ; ... divided by 2
                move.b  d0,SMPS_Track.ModulationSteps(a5)  ; ... before being stored
                clr.w   SMPS_Track.ModulationVal(a5)    ; total accumulated modulation frequency change
                rts
; ===========================================================================
; loc_72D52:
cfEnableModulation:
                bset    #3,SMPS_Track.PlaybackControl(a5)  ; turn on modulation
                rts
; ===========================================================================
; loc_72D58:
cfStopTrack:
                bclr    #7,SMPS_Track.PlaybackControl(a5)  ; stop track
                bclr    #4,SMPS_Track.PlaybackControl(a5)  ; clear 'do not attack next note' bit
                tst.b   SMPS_Track.VoiceControl(a5)     ; is this a PSG track?
                bmi.s   .stoppsg                        ; branch if yes
                tst.b   SMPS_RAM.f_updating_dac(a6)     ; is this the DAC we are updating?
                bmi.w   .locexit                        ; exit if yes
                jsr     FMNoteOff(pc)
                bra.s   .stoppedchannel
; ===========================================================================
; loc_72D74:
.stoppsg:
                jsr     PSGNoteOff(pc)
; loc_72D78:
.stoppedchannel:
                tst.b   SMPS_RAM.f_voice_selector(a6)   ; are we updating SFX?
                bpl.w   .locexit                        ; exit if not
                _clr.b  SMPS_RAM.v_sndprio(a6)          ; clear priority
                moveq   #0,d0
                move.b  SMPS_Track.VoiceControl(a5),d0  ; get voice control bits
                bmi.s   .getpsgptr                      ; branch if PSG
                lea     SFX_BGMChannelRAM(pc),a0
                movea.l a5,a3
                cmpi.b  #4,d0                           ; is this FM4?
                bne.s   .getpointer                     ; branch if not
                tst.b   SMPS_RAM.v_spcsfx_fm4_track.PlaybackControl(a6)  ; is special SFX playing?
                bpl.s   .getpointer                     ; branch if not
                lea     SMPS_RAM.v_spcsfx_fm4_track(a6),a5
                movea.l SMPS_RAM.v_special_voice_ptr(a6),a1  ; get voice pointer
                bra.s   .gotpointer
; ===========================================================================
; loc_72DA8:
.getpointer:
                subq.b  #2,d0                           ; SFX can only use FM3 and up
                lsl.b   #2,d0
                movea.l (a0,d0.w),a5
                tst.b   SMPS_Track.PlaybackControl(a5)  ; is track playing?
                bpl.s   .novoiceupd                     ; branch if not
                movea.l SMPS_RAM.v_voice_ptr(a6),a1     ; get voice pointer
; loc_72DB8:
.gotpointer:
                bclr    #2,SMPS_Track.PlaybackControl(a5)  ; clear 'SFX overriding' bit
                bset    #1,SMPS_Track.PlaybackControl(a5)  ; set 'track at rest' bit
                move.b  SMPS_Track.VoiceIndex(a5),d0    ; current voice
                jsr     SetVoice(pc)
; loc_72DC8:
.novoiceupd:
                movea.l a3,a5
                bra.s   .locexit
; ===========================================================================
; loc_72DCC:
.getpsgptr:
                lea     SMPS_RAM.v_spcsfx_psg3_track(a6),a0
                tst.b   SMPS_Track.PlaybackControl(a0)  ; is track playing?
                bpl.s   .getchannelptr                  ; branch if not
                cmpi.b  #$E0,d0                         ; is it the noise channel?
                beq.s   .gotchannelptr                  ; branch if yes
                cmpi.b  #$C0,d0                         ; is it PSG 3?
                beq.s   .gotchannelptr                  ; branch if yes
; loc_72DE0:
.getchannelptr:
                lea     SFX_BGMChannelRAM(pc),a0
                lsr.b   #3,d0
                movea.l (a0,d0.w),a0
; loc_72DEA:
.gotchannelptr:
                bclr    #2,SMPS_Track.PlaybackControl(a0)  ; clear 'SFX overriding' bit
                bset    #1,SMPS_Track.PlaybackControl(a0)  ; set 'track at rest' bit
                cmpi.b  #$E0,SMPS_Track.VoiceControl(a0)  ; is this a noise pointer?
                bne.s   .locexit                        ; branch if not
                move.b  SMPS_Track.PSGNoise(a0),(psg_input).l  ; set noise tone
; loc_72E02:
.locexit:
                addq.w  #8,sp                           ; tamper with return value so we don't go back to caller
                rts
; ===========================================================================
; loc_72E06:
cfSetPSGNoise:
                move.b  #$E0,SMPS_Track.VoiceControl(a5)  ; turn channel into noise channel
                move.b  (a4)+,SMPS_Track.PSGNoise(a5)   ; save noise tone
                btst    #2,SMPS_Track.PlaybackControl(a5)  ; is track being overridden?
                bne.s   .locret                         ; return if yes
                move.b  -1(a4),(psg_input).l            ; set tone
; locret_72E1E:
.locret:
                rts
; ===========================================================================
; loc_72E20:
cfDisableModulation:
                bclr    #3,SMPS_Track.PlaybackControl(a5)  ; disable modulation
                rts
; ===========================================================================
; loc_72E26:
cfSetPSGTone:
                move.b  (a4)+,SMPS_Track.VoiceIndex(a5)  ; set current PSG tone
                rts
; ===========================================================================
; loc_72E2C:
cfJumpTo:
                move.b  (a4)+,d0                        ; high byte of offset
                lsl.w   #8,d0                           ; shift it into place
                move.b  (a4)+,d0                        ; low byte of offset
                adda.w  d0,a4                           ; add to current position
                subq.w  #1,a4                           ; put back one byte
                rts
; ===========================================================================
; loc_72E38:
cfRepeatAtPos:
                moveq   #0,d0
                move.b  (a4)+,d0                        ; loop index
                move.b  (a4)+,d1                        ; repeat count
                tst.b   SMPS_Track.LoopCounters(a5,d0.w)  ; has this loop already started?
                bne.s   .loopexists                     ; branch if yes
                move.b  d1,SMPS_Track.LoopCounters(a5,d0.w)  ; initialize repeat count
; loc_72E48:
.loopexists:
                subq.b  #1,SMPS_Track.LoopCounters(a5,d0.w)  ; decrease loop's repeat count
                bne.s   cfJumpTo                        ; if nonzero, branch to target
                addq.w  #2,a4                           ; skip target address
                rts
; ===========================================================================
; loc_72E52:
cfJumpToGosub:
                moveq   #0,d0
                move.b  SMPS_Track.StackPointer(a5),d0  ; current stack pointer
                subq.b  #4,d0                           ; add space for another target
                move.l  a4,(a5,d0.w)                    ; put in current address (*before* target for jump!)
                move.b  d0,SMPS_Track.StackPointer(a5)  ; store new stack pointer
                bra.s   cfJumpTo
; ===========================================================================
; loc_72E64:
cfOpF9:
                move.b  #$88,d0                         ; D1L/RR of Operator 3
                move.b  #$F,d1                          ; loaded with fixed value (max RR, 1TL)
                jsr     WriteFMI(pc)
                move.b  #$8C,d0                         ; D1L/RR of Operator 4
                move.b  #$F,d1                          ; loaded with fixed value (max RR, 1TL)
                bra.w   WriteFMI
; ===========================================================================
; ---------------------------------------------------------------------------
; DAC driver (Kosinski-compressed)
; ---------------------------------------------------------------------------
; Kos_Z80:
