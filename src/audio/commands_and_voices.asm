CoordFlag:
                subi.w  #$E0,d5
                lsl.w   #2,d5
                jmp     coordflagLookup(pc,d5.w)
; End of function CoordFlag

; ===========================================================================
; loc_72A64:
coordflagLookup:
                bra.w   cfPanningAMSFMS                 ; $E0
; ===========================================================================
                bra.w   cfDetune                        ; $E1
; ===========================================================================
                bra.w   cfSetCommunication              ; $E2
; ===========================================================================
                bra.w   cfJumpReturn                    ; $E3
; ===========================================================================
                bra.w   cfFadeInToPrevious              ; $E4
; ===========================================================================
                bra.w   cfSetTempoDivider               ; $E5
; ===========================================================================
                bra.w   cfChangeFMVolume                ; $E6
; ===========================================================================
                bra.w   cfHoldNote                      ; $E7
; ===========================================================================
                bra.w   cfNoteTimeout                   ; $E8
; ===========================================================================
                bra.w   cfChangeTransposition           ; $E9
; ===========================================================================
                bra.w   cfSetTempo                      ; $EA
; ===========================================================================
                bra.w   cfSetTempoDividerAll            ; $EB
; ===========================================================================
                bra.w   cfChangePSGVolume               ; $EC
; ===========================================================================
                bra.w   cfClearPush                     ; $ED
; ===========================================================================
                bra.w   cfStopSpecialFM4                ; $EE
; ===========================================================================
                bra.w   cfSetVoice                      ; $EF
; ===========================================================================
                bra.w   cfModulation                    ; $F0
; ===========================================================================
                bra.w   cfEnableModulation              ; $F1
; ===========================================================================
                bra.w   cfStopTrack                     ; $F2
; ===========================================================================
                bra.w   cfSetPSGNoise                   ; $F3
; ===========================================================================
                bra.w   cfDisableModulation             ; $F4
; ===========================================================================
                bra.w   cfSetPSGTone                    ; $F5
; ===========================================================================
                bra.w   cfJumpTo                        ; $F6
; ===========================================================================
                bra.w   cfRepeatAtPos                   ; $F7
; ===========================================================================
                bra.w   cfJumpToGosub                   ; $F8
; ===========================================================================
                bra.w   cfOpF9                          ; $F9
; ===========================================================================
; loc_72ACC:
cfPanningAMSFMS:
                move.b  (a4)+,d1                        ; new AMS/FMS/panning value
                tst.b   SMPS_Track.VoiceControl(a5)     ; is this a PSG track?
                bmi.s   locret_72AEA                    ; return if yes
                move.b  SMPS_Track.AMSFMSPan(a5),d0     ; get current AMS/FMS/panning
                andi.b  #$37,d0                         ; retain bits 0-2, 3-4 if set
                or.b    d0,d1                           ; mask in new value
                move.b  d1,SMPS_Track.AMSFMSPan(a5)     ; store value
                move.b  #$B4,d0                         ; command to set AMS/FMS/panning
                bra.w   WriteFMIorIIMain
; ===========================================================================

locret_72AEA:
                rts
; ===========================================================================
; loc_72AEC: cfAlterNotes:
cfDetune:
                move.b  (a4)+,SMPS_Track.Detune(a5)     ; set detune value
                rts
; ===========================================================================
; loc_72AF2: cfUnknown1:
cfSetCommunication:
                move.b  (a4)+,SMPS_RAM.v_communication_byte(a6)  ; set otherwise unused communication byte to parameter
                rts
; ===========================================================================
; loc_72AF8:
cfJumpReturn:
                moveq   #0,d0
                move.b  SMPS_Track.StackPointer(a5),d0  ; track stack pointer
                movea.l (a5,d0.w),a4                    ; set track return address
                move.l  #0,(a5,d0.w)                    ; set 'popped' value to zero
                addq.w  #2,a4                           ; skip jump target address from gosub flag
                addq.b  #4,d0                           ; actually 'pop' value
                move.b  d0,SMPS_Track.StackPointer(a5)  ; set new stack pointer
                rts
; ===========================================================================
; loc_72B14:
cfFadeInToPrevious:
                movea.l a6,a0
                lea     SMPS_RAM.v_1up_ram_copy(a6),a1
                move.w  #((SMPS_RAM.v_1up_ram_end-SMPS_RAM.v_1up_ram)/4)-1,d0  ; $220 bytes to restore: all variables and music track data
; loc_72B1E:
.restoreramloop:
                move.l  (a1)+,(a0)+
                dbf     d0,.restoreramloop

                bset    #2,SMPS_RAM.v_music_dac_track.PlaybackControl(a6)  ; set 'SFX overriding' bit
                movea.l a5,a3
                move.b  #$28,d6
                sub.b   SMPS_RAM.v_fadein_counter(a6),d6  ; if fade already in progress, this adjusts track volume accordingly
                moveq   #SMPS_MUSIC_FM_TRACK_COUNT-1,d7  ; 6 FM tracks
                lea     SMPS_RAM.v_music_fm_tracks(a6),a5
; loc_72B3A:
.fmloop:
                btst    #7,SMPS_Track.PlaybackControl(a5)  ; is track playing?
                beq.s   .nextfm                         ; branch if not
                bset    #1,SMPS_Track.PlaybackControl(a5)  ; set 'track at rest' bit
                add.b   d6,SMPS_Track.Volume(a5)        ; apply current volume fade-in
                btst    #2,SMPS_Track.PlaybackControl(a5)  ; is SFX overriding?
                bne.s   .nextfm                         ; branch if yes
                moveq   #0,d0
                move.b  SMPS_Track.VoiceIndex(a5),d0    ; get voice
                movea.l SMPS_RAM.v_voice_ptr(a6),a1     ; voice pointer
                jsr     SetVoice(pc)
; loc_72B5C:
.nextfm:
                adda.w  #SMPS_Track.len,a5
                dbf     d7,.fmloop

                moveq   #SMPS_MUSIC_PSG_TRACK_COUNT-1,d7  ; 3 PSG tracks
; loc_72B66:
.psgloop:
                btst    #7,SMPS_Track.PlaybackControl(a5)  ; is track playing?
                beq.s   .nextpsg                        ; branch if not
                bset    #1,SMPS_Track.PlaybackControl(a5)  ; set 'track at rest' bit
                jsr     PSGNoteOff(pc)
                add.b   d6,SMPS_Track.Volume(a5)        ; apply current volume fade-in
; loc_72B78:
.nextpsg:
                adda.w  #SMPS_Track.len,a5
                dbf     d7,.psgloop

                movea.l a3,a5
                move.b  #$80,SMPS_RAM.f_fadein_flag(a6)  ; trigger fade-in
                move.b  #$28,SMPS_RAM.v_fadein_counter(a6)  ; fade-in delay
                clr.b   SMPS_RAM.f_1up_playing(a6)
                startZ80
                addq.w  #8,sp                           ; tamper return value so we don't return to caller
                rts
; ===========================================================================
; loc_72B9E:
cfSetTempoDivider:
                move.b  (a4)+,SMPS_Track.TempoDivider(a5)  ; set tempo divider on current track
                rts
; ===========================================================================
; loc_72BA4: cfSetVolume:
cfChangeFMVolume:
                move.b  (a4)+,d0                        ; get parameter
                add.b   d0,SMPS_Track.Volume(a5)        ; add to current volume
                bra.w   SendVoiceTL
; ===========================================================================
; loc_72BAE: cfPreventAttack:
cfHoldNote:
                bset    #4,SMPS_Track.PlaybackControl(a5)  ; set 'do not attack next note' bit
                rts
; ===========================================================================
; loc_72BB4: cfNoteFill
cfNoteTimeout:
                move.b  (a4),SMPS_Track.NoteTimeout(a5)  ; note fill timeout
                move.b  (a4)+,SMPS_Track.NoteTimeoutMaster(a5)  ; note fill master
                rts
; ===========================================================================
; loc_72BBE: cfAddKey:
cfChangeTransposition:
                move.b  (a4)+,d0                        ; get parameter
                add.b   d0,SMPS_Track.Transpose(a5)     ; add to transpose value
                rts
; ===========================================================================
; loc_72BC6:
cfSetTempo:
                move.b  (a4),SMPS_RAM.v_main_tempo(a6)  ; set main tempo
                move.b  (a4)+,SMPS_RAM.v_main_tempo_timeout(a6)  ; and reset timeout (!)
                rts
; ===========================================================================
; loc_72BD0: cfSetTempoMod:
cfSetTempoDividerAll:
                lea     SMPS_RAM.v_music_track_ram(a6),a0
                move.b  (a4)+,d0                        ; get new tempo divider
                moveq   #SMPS_Track.len,d1
                moveq   #SMPS_MUSIC_TRACK_COUNT-1,d2    ; 1 DAC + 6 FM + 3 PSG tracks
; loc_72BDA:
.trackloop:
                move.b  d0,SMPS_Track.TempoDivider(a0)  ; set track's tempo divider
                adda.w  d1,a0
                dbf     d2,.trackloop

                rts
; ===========================================================================
; loc_72BE6: cfChangeVolume:
cfChangePSGVolume:
                move.b  (a4)+,d0                        ; get volume change
                add.b   d0,SMPS_Track.Volume(a5)        ; apply it
                rts
; ===========================================================================
; loc_72BEE:
cfClearPush:
                clr.b   SMPS_RAM.f_push_playing(a6)     ; allow push sound to be played once more
                rts
; ===========================================================================
; loc_72BF4:
cfStopSpecialFM4:
                bclr    #7,SMPS_Track.PlaybackControl(a5)  ; stop track
                bclr    #4,SMPS_Track.PlaybackControl(a5)  ; clear 'do not attack next note' bit
                jsr     FMNoteOff(pc)
                tst.b   SMPS_RAM.v_sfx_fm4_track.PlaybackControl(a6)  ; is SFX using FM4?
                bmi.s   .locexit                        ; branch if yes
                movea.l a5,a3
                lea     SMPS_RAM.v_music_fm4_track(a6),a5
                movea.l SMPS_RAM.v_voice_ptr(a6),a1     ; voice pointer
                bclr    #2,SMPS_Track.PlaybackControl(a5)  ; clear 'SFX is overriding' bit
                bset    #1,SMPS_Track.PlaybackControl(a5)  ; set 'track at rest' bit
                move.b  SMPS_Track.VoiceIndex(a5),d0    ; current voice
                jsr     SetVoice(pc)
                movea.l a3,a5
; loc_72C22:
.locexit:
                addq.w  #8,sp                           ; tamper with return value so we don't return to caller
                rts
; ===========================================================================
; loc_72C26:
cfSetVoice:
                moveq   #0,d0
                move.b  (a4)+,d0                        ; get new voice
                move.b  d0,SMPS_Track.VoiceIndex(a5)    ; store it
                btst    #2,SMPS_Track.PlaybackControl(a5)  ; is SFX overriding this track?
                bne.w   locret_72CAA                    ; return if yes
                movea.l SMPS_RAM.v_voice_ptr(a6),a1     ; music voice pointer
                tst.b   SMPS_RAM.f_voice_selector(a6)   ; are we updating a music track?
                beq.s   SetVoice                        ; if yes, branch
                movea.l SMPS_Track.VoicePtr(a5),a1      ; sFX track voice pointer
                tst.b   SMPS_RAM.f_voice_selector(a6)   ; are we updating a SFX track?
                bmi.s   SetVoice                        ; if yes, branch
                movea.l SMPS_RAM.v_special_voice_ptr(a6),a1  ; special SFX voice pointer
; ===========================================================================

; sub_72C4E:
SetVoice:
                subq.w  #1,d0
                bmi.s   .havevoiceptr
                move.w  #25,d1
; loc_72C56:
.voicemultiply:
                adda.w  d1,a1
                dbf     d0,.voicemultiply
; loc_72C5C:
.havevoiceptr:
                move.b  (a1)+,d1                        ; feedback/algorithm
                move.b  d1,SMPS_Track.FeedbackAlgo(a5)  ; save it to track RAM
                move.b  d1,d4
                move.b  #$B0,d0                         ; command to write feedback/algorithm
                jsr     WriteFMIorII(pc)
                lea     FMInstrumentOperatorTable(pc),a2
                moveq   #(FMInstrumentOperatorTable_End-FMInstrumentOperatorTable)-1,d3  ; don't want to send TL yet
; loc_72C72:
.sendvoiceloop:
                move.b  (a2)+,d0
                move.b  (a1)+,d1
                jsr     WriteFMIorII(pc)
                dbf     d3,.sendvoiceloop

                moveq   #(FMInstrumentTLTable_End-FMInstrumentTLTable)-1,d5
                andi.w  #7,d4                           ; get algorithm
                move.b  FMSlotMask(pc,d4.w),d4          ; get slot mask for algorithm
                move.b  SMPS_Track.Volume(a5),d3        ; track volume attenuation
; loc_72C8C:
.sendtlloop:
                move.b  (a2)+,d0
                move.b  (a1)+,d1
                lsr.b   #1,d4                           ; is bit set for this operator in the mask?
                bcc.s   .sendtl                         ; branch if not
                add.b   d3,d1                           ; include additional attenuation
; loc_72C96:
.sendtl:
                jsr     WriteFMIorII(pc)
                dbf     d5,.sendtlloop

                move.b  #$B4,d0                         ; register for AMS/FMS/Panning
                move.b  SMPS_Track.AMSFMSPan(a5),d1     ; value to send
                jsr     WriteFMIorII(pc)                ; (It would be better if this were a jmp)

locret_72CAA:
                rts
; End of function SetVoice

; ===========================================================================
; byte_72CAC:
FMSlotMask:   dc.b    8, 8, 8, 8, $A, $E, $E, $F
; ===========================================================================

; sub_72CB4:
SendVoiceTL:
                btst    #2,SMPS_Track.PlaybackControl(a5)  ; is SFX overriding?
                bne.s   .locret                         ; return if so
                moveq   #0,d0
                move.b  SMPS_Track.VoiceIndex(a5),d0    ; current voice
                movea.l SMPS_RAM.v_voice_ptr(a6),a1     ; voice pointer
                tst.b   SMPS_RAM.f_voice_selector(a6)
                beq.s   .gotvoiceptr
; DANGER! This uploads the wrong voice! It should have been a5 instead of a6!
; In Sonic 1's prototype, TrackVoicePtr was a global variable instead of a
; per-track variable, explaining why this uses a6 instead of a5
                movea.l SMPS_Track.VoicePtr(a6),a1
                tst.b   SMPS_RAM.f_voice_selector(a6)
                bmi.s   .gotvoiceptr
                movea.l SMPS_RAM.v_special_voice_ptr(a6),a1
; loc_72CD8:
.gotvoiceptr:
                subq.w  #1,d0
                bmi.s   .gotvoice
                move.w  #25,d1
; loc_72CE0:
.voicemultiply:
                adda.w  d1,a1
                dbf     d0,.voicemultiply
; loc_72CE6:
.gotvoice:
                adda.w  #21,a1                          ; want TL
                lea     FMInstrumentTLTable(pc),a2
                move.b  SMPS_Track.FeedbackAlgo(a5),d0  ; get feedback/algorithm
                andi.w  #7,d0                           ; want only algorithm
                move.b  FMSlotMask(pc,d0.w),d4          ; get slot mask
                move.b  SMPS_Track.Volume(a5),d3        ; get track volume attenuation
                bmi.s   .locret                         ; if negative, stop
                moveq   #(FMInstrumentTLTable_End-FMInstrumentTLTable)-1,d5
; loc_72D02:
.sendtlloop:
                move.b  (a2)+,d0
                move.b  (a1)+,d1
                lsr.b   #1,d4                           ; is bit set for this operator in the mask?
                bcc.s   .senttl                         ; branch if not
                add.b   d3,d1                           ; include additional attenuation
                bcs.s   .senttl                         ; branch on overflow
                jsr     WriteFMIorII(pc)
; loc_72D12:
.senttl:
                dbf     d5,.sendtlloop
; locret_72D16:
.locret:
                rts
; End of function SendVoiceTL

; ===========================================================================
; byte_72D18:
FMInstrumentOperatorTable:
                dc.b    $30                             ; detune/multiple operator 1
                dc.b    $38                             ; detune/multiple operator 3
                dc.b    $34                             ; detune/multiple operator 2
                dc.b    $3C                             ; detune/multiple operator 4
                dc.b    $50                             ; rate scaling/attack rate operator 1
                dc.b    $58                             ; rate scaling/attack rate operator 3
                dc.b    $54                             ; rate scaling/attack rate operator 2
                dc.b    $5C                             ; rate scaling/attack rate operator 4
                dc.b    $60                             ; amplitude modulation/first decay rate operator 1
                dc.b    $68                             ; amplitude modulation/first decay rate operator 3
                dc.b    $64                             ; amplitude modulation/first decay rate operator 2
                dc.b    $6C                             ; amplitude modulation/first decay rate operator 4
                dc.b    $70                             ; secondary decay rate operator 1
                dc.b    $78                             ; secondary decay rate operator 3
                dc.b    $74                             ; secondary decay rate operator 2
                dc.b    $7C                             ; secondary decay rate operator 4
                dc.b    $80                             ; secondary amplitude/release rate operator 1
                dc.b    $88                             ; secondary amplitude/release rate operator 3
                dc.b    $84                             ; secondary amplitude/release rate operator 2
                dc.b    $8C                             ; secondary amplitude/release rate operator 4
FMInstrumentOperatorTable_End
; byte_72D2C:
FMInstrumentTLTable:
                dc.b    $40                             ; total level operator 1
                dc.b    $48                             ; total level operator 3
                dc.b    $44                             ; total level operator 2
                dc.b    $4C                             ; total level operator 4
FMInstrumentTLTable_End
; ===========================================================================
; loc_72D30:
