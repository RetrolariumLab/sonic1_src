StopSFX:
                _clr.b  SMPS_RAM.v_sndprio(a6)          ; clear priority
                lea     SMPS_RAM.v_sfx_track_ram(a6),a5
                moveq   #SMPS_SFX_TRACK_COUNT-1,d7      ; 3 FM + 3 PSG tracks (SFX)
; loc_723EA:
.trackloop:
                tst.b   SMPS_Track.PlaybackControl(a5)  ; is track playing?
                bpl.w   .nexttrack                      ; branch if not
                bclr    #7,SMPS_Track.PlaybackControl(a5)  ; stop track
                moveq   #0,d3
                move.b  SMPS_Track.VoiceControl(a5),d3  ; get voice control bits
                bmi.s   .trackpsg                       ; branch if PSG
                jsr     FMNoteOff(pc)
                cmpi.b  #4,d3                           ; is this FM4?
                bne.s   .getfmpointer                   ; branch if not
                tst.b   SMPS_RAM.v_spcsfx_fm4_track.PlaybackControl(a6)  ; is special SFX playing?
                bpl.s   .getfmpointer                   ; branch if not
                lea     SMPS_RAM.v_spcsfx_fm4_track(a6),a5
                movea.l SMPS_RAM.v_special_voice_ptr(a6),a1  ; get special voice pointer
                bra.s   .gotfmpointer
; ===========================================================================
; loc_72416:
.getfmpointer:
                subq.b  #2,d3                           ; SFX only has FM3 and up
                lsl.b   #2,d3
                lea     SFX_BGMChannelRAM(pc),a0
                movea.l a5,a3
                movea.l (a0,d3.w),a5
                movea.l SMPS_RAM.v_voice_ptr(a6),a1     ; get music voice pointer
; loc_72428:
.gotfmpointer:
                bclr    #2,SMPS_Track.PlaybackControl(a5)  ; clear 'SFX is overriding' bit
                bset    #1,SMPS_Track.PlaybackControl(a5)  ; set 'track at rest' bit
                move.b  SMPS_Track.VoiceIndex(a5),d0    ; current voice
                jsr     SetVoice(pc)
                movea.l a3,a5
                bra.s   .nexttrack
; ===========================================================================
; loc_7243C:
.trackpsg:
                jsr     PSGNoteOff(pc)
                lea     SMPS_RAM.v_spcsfx_psg3_track(a6),a0
                cmpi.b  #$E0,d3                         ; is this a noise channel?
                beq.s   .gotpsgpointer                  ; branch if yes
                cmpi.b  #$C0,d3                         ; is this PSG 3?
                beq.s   .gotpsgpointer                  ; branch if yes

.getchannelptr:
                lsr.b   #3,d3
                lea     SFX_BGMChannelRAM(pc),a0
                movea.l (a0,d3.w),a0
; loc_7245A:
.gotpsgpointer:
                bclr    #2,SMPS_Track.PlaybackControl(a0)  ; clear 'SFX is overriding' bit
                bset    #1,SMPS_Track.PlaybackControl(a0)  ; set 'track at rest' bit
                cmpi.b  #$E0,SMPS_Track.VoiceControl(a0)  ; is this a noise channel?
                bne.s   .nexttrack                      ; branch if not
                move.b  SMPS_Track.PSGNoise(a0),(psg_input).l  ; set noise type
; loc_72472:
.nexttrack:
                adda.w  #SMPS_Track.len,a5
                dbf     d7,.trackloop

                rts
; End of function StopSFX
; ===========================================================================

; Snd_FadeOut2: FadeOutSFX2: FadeOutSpecialSFX:
StopSpecialSFX:
                lea     SMPS_RAM.v_spcsfx_fm4_track(a6),a5
                tst.b   SMPS_Track.PlaybackControl(a5)  ; is track playing?
                bpl.s   .fadedfm                        ; branch if not
                bclr    #7,SMPS_Track.PlaybackControl(a5)  ; stop track
                btst    #2,SMPS_Track.PlaybackControl(a5)  ; is SFX overriding?
                bne.s   .fadedfm                        ; branch if not
                jsr     SendFMNoteOff(pc)
                lea     SMPS_RAM.v_music_fm4_track(a6),a5
                bclr    #2,SMPS_Track.PlaybackControl(a5)  ; clear 'SFX is overriding' bit
                bset    #1,SMPS_Track.PlaybackControl(a5)  ; set 'track at rest' bit
                tst.b   SMPS_Track.PlaybackControl(a5)  ; is track playing?
                bpl.s   .fadedfm                        ; branch if not
                movea.l SMPS_RAM.v_voice_ptr(a6),a1     ; voice pointer
                move.b  SMPS_Track.VoiceIndex(a5),d0    ; current voice
                jsr     SetVoice(pc)
; loc_724AE:
.fadedfm:
                lea     SMPS_RAM.v_spcsfx_psg3_track(a6),a5
                tst.b   SMPS_Track.PlaybackControl(a5)  ; is track playing?
                bpl.s   .fadedpsg                       ; branch if not
                bclr    #7,SMPS_Track.PlaybackControl(a5)  ; stop track
                btst    #2,SMPS_Track.PlaybackControl(a5)  ; is SFX overriding?
                bne.s   .fadedpsg                       ; return if not
                jsr     SendPSGNoteOff(pc)
                lea     SMPS_RAM.v_music_psg3_track(a6),a5
                bclr    #2,SMPS_Track.PlaybackControl(a5)  ; clear 'SFX is overriding' bit
                bset    #1,SMPS_Track.PlaybackControl(a5)  ; set 'track at rest' bit
                tst.b   SMPS_Track.PlaybackControl(a5)  ; is track playing?
                bpl.s   .fadedpsg                       ; return if not
                cmpi.b  #$E0,SMPS_Track.VoiceControl(a5)  ; is this a noise channel?
                bne.s   .fadedpsg                       ; return if not
                move.b  SMPS_Track.PSGNoise(a5),(psg_input).l  ; set noise type
; locret_724E4:
.fadedpsg:
                rts
; End of function StopSpecialSFX

; ===========================================================================
; ---------------------------------------------------------------------------
; Fade out music
; ---------------------------------------------------------------------------
; Sound_E0:
FadeOutMusic:
                jsr     StopSFX(pc)
                jsr     StopSpecialSFX(pc)
                move.b  #3,SMPS_RAM.v_fadeout_delay(a6)  ; set fadeout delay to 3
                move.b  #$28,SMPS_RAM.v_fadeout_counter(a6)  ; set fadeout counter
                clr.b   SMPS_RAM.v_music_dac_track.PlaybackControl(a6)  ; stop DAC track
                clr.b   SMPS_RAM.f_speedup(a6)          ; disable speed shoes tempo
                rts
; ===========================================================================

; sub_72504:
DoFadeOut:
                move.b  SMPS_RAM.v_fadeout_delay(a6),d0  ; has fadeout delay expired?
                beq.s   .continuefade                   ; branch if yes
                subq.b  #1,SMPS_RAM.v_fadeout_delay(a6)
                rts
; ===========================================================================
; loc_72510:
.continuefade:
                subq.b  #1,SMPS_RAM.v_fadeout_counter(a6)  ; update fade counter
                beq.w   StopAllSound                    ; branch if fade is done
                move.b  #3,SMPS_RAM.v_fadeout_delay(a6)  ; reset fade delay
                lea     SMPS_RAM.v_music_fm_tracks(a6),a5
                moveq   #SMPS_MUSIC_FM_TRACK_COUNT-1,d7  ; 6 FM tracks
; loc_72524:
.fmloop:
                tst.b   SMPS_Track.PlaybackControl(a5)  ; is track playing?
                bpl.s   .nextfm                         ; branch if not
                addq.b  #1,SMPS_Track.Volume(a5)        ; increase volume attenuation
                bpl.s   .sendfmtl                       ; branch if still positive
                bclr    #7,SMPS_Track.PlaybackControl(a5)  ; stop track
                bra.s   .nextfm
; ===========================================================================
; loc_72534:
.sendfmtl:
                jsr     SendVoiceTL(pc)
; loc_72538:
.nextfm:
                adda.w  #SMPS_Track.len,a5
                dbf     d7,.fmloop

                moveq   #SMPS_MUSIC_PSG_TRACK_COUNT-1,d7  ; 3 PSG tracks
; loc_72542:
.psgloop:
                tst.b   SMPS_Track.PlaybackControl(a5)  ; is track playing?
                bpl.s   .nextpsg                        ; branch if not
                addq.b  #1,SMPS_Track.Volume(a5)        ; increase volume attenuation
                cmpi.b  #$10,SMPS_Track.Volume(a5)      ; is it greater than $F?
                blo.s   .sendpsgvol                     ; branch if not
                bclr    #7,SMPS_Track.PlaybackControl(a5)  ; stop track
                bra.s   .nextpsg
; ===========================================================================
; loc_72558:
.sendpsgvol:
                move.b  SMPS_Track.Volume(a5),d6        ; store new volume attenuation
                jsr     SetPSGVolume(pc)
; loc_72560:
.nextpsg:
                adda.w  #SMPS_Track.len,a5
                dbf     d7,.psgloop

                rts
; End of function DoFadeOut
; ===========================================================================

; sub_7256A:
FMSilenceAll:
                moveq   #2,d3                           ; 3 FM channels for each YM2612 parts
                moveq   #$28,d0                         ; FM key on/off register
; loc_7256E:
.noteoffloop:
                move.b  d3,d1
                jsr     WriteFMI(pc)
                addq.b  #4,d1                           ; move to YM2612 part 1
                jsr     WriteFMI(pc)
                dbf     d3,.noteoffloop

                moveq   #$40,d0                         ; set TL on FM channels
                moveq   #$7F,d1                         ; ... to total attenuation
                moveq   #2,d4                           ; ... for all 3 channels
; loc_72584:
.channelloop:
                moveq   #3,d3                           ; ... for all operators on each channel
; loc_72586:
.channeltlloop:
                jsr     WriteFMI(pc)                    ; ... for part 0
                jsr     WriteFMII(pc)                   ; ... and part 1
                addq.w  #4,d0                           ; next TL operator
                dbf     d3,.channeltlloop

                subi.b  #$F,d0                          ; move to TL operator 1 of next channel
                dbf     d4,.channelloop

                rts
; End of function FMSilenceAll

; ===========================================================================
; ---------------------------------------------------------------------------
; Stop music
; ---------------------------------------------------------------------------
; Sound_E4: StopSoundAndMusic:
StopAllSound:
                moveq   #$2B,d0                         ; enable/disable DAC
                move.b  #$80,d1                         ; enable DAC
                jsr     WriteFMI(pc)
                moveq   #$27,d0                         ; timers, FM3/FM6 mode
                moveq   #0,d1                           ; FM3/FM6 normal mode, disable timers
                jsr     WriteFMI(pc)
                movea.l a6,a0
; DANGER! This should be clearing all variables and track data, but misses the last $10 bytes of v_spcsfx_psg3_Track
                move.w  #((SMPS_RAM.v_1up_ram_copy-$10)/4)-1,d0  ; clear $390 bytes: all variables and most track data
; loc_725B6:
.clearramloop:
                clr.l   (a0)+
                dbf     d0,.clearramloop

                move.b  #$80,SMPS_RAM.v_sound_id(a6)    ; set music to $80 (silence)
                jsr     FMSilenceAll(pc)
                bra.w   PSGSilenceAll
; ===========================================================================

; sub_725CA:
InitMusicPlayback:
                movea.l a6,a0
; save several values
                _move.b SMPS_RAM.v_sndprio(a6),d1
                move.b  SMPS_RAM.f_1up_playing(a6),d2
                move.b  SMPS_RAM.f_speedup(a6),d3
                move.b  SMPS_RAM.v_fadein_counter(a6),d4
                move.w  SMPS_RAM.v_soundqueue0(a6),d5
                move.w  #((SMPS_RAM.v_1up_ram_end-SMPS_RAM.v_1up_ram)/4)-1,d0  ; clear $220 bytes: all variables and music track data
; loc_725E4:
.clearramloop:
                clr.l   (a0)+
                dbf     d0,.clearramloop

; restore the values saved above
                _move.b d1,SMPS_RAM.v_sndprio(a6)
                move.b  d2,SMPS_RAM.f_1up_playing(a6)
                move.b  d3,SMPS_RAM.f_speedup(a6)
                move.b  d4,SMPS_RAM.v_fadein_counter(a6)
                move.w  d5,SMPS_RAM.v_soundqueue0(a6)
                move.b  #$80,SMPS_RAM.v_sound_id(a6)    ; set music to $80 (silence)

; DANGER! This silences ALL channels, even the ones being used
; by SFX, and not music! .sendfmnoteoff does this already, and
; doesn't affect SFX channels, either
; DANGER! InitMusicPlayback, and Sound_PlayBGM for that matter,
; don't do a very good job of setting up the music tracks
; Tracks that aren't defined in a music file's header don't have
; their channels defined, meaning .sendfmnoteoff won't silence
; hardware properly. In combination with removing the above
; calls to FMSilenceAll/PSGSilenceAll, this will cause hanging
; notes
                jsr     FMSilenceAll(pc)
                bra.w   PSGSilenceAll

; End of function InitMusicPlayback
; ===========================================================================

; sub_7260C:
TempoWait:
                move.b  SMPS_RAM.v_main_tempo(a6),SMPS_RAM.v_main_tempo_timeout(a6)  ; reset main tempo timeout
                lea     SMPS_RAM.v_music_track_ram+SMPS_Track.DurationTimeout(a6),a0  ; note timeout
                moveq   #SMPS_Track.len,d0
                moveq   #SMPS_MUSIC_TRACK_COUNT-1,d1    ; 1 DAC + 6 FM + 3 PSG tracks
; loc_7261A:
.tempoloop:
                addq.b  #1,(a0)                         ; delay note by 1 frame
                adda.w  d0,a0                           ; advance to next track
                dbf     d1,.tempoloop

                rts
; End of function TempoWait

; ===========================================================================
; ---------------------------------------------------------------------------
; Speed up music
; ---------------------------------------------------------------------------
; Sound_E2:
SpeedUpMusic:
                tst.b   SMPS_RAM.f_1up_playing(a6)
                bne.s   .speedup_1up
                move.b  SMPS_RAM.v_speeduptempo(a6),SMPS_RAM.v_main_tempo(a6)
                move.b  SMPS_RAM.v_speeduptempo(a6),SMPS_RAM.v_main_tempo_timeout(a6)
                move.b  #$80,SMPS_RAM.f_speedup(a6)
                rts
; ===========================================================================
; loc_7263E:
.speedup_1up:
                move.b  SMPS_RAM.v_1up_ram_copy+SMPS_RAM.v_speeduptempo(a6),SMPS_RAM.v_1up_ram_copy+SMPS_RAM.v_main_tempo(a6)
                move.b  SMPS_RAM.v_1up_ram_copy+SMPS_RAM.v_speeduptempo(a6),SMPS_RAM.v_1up_ram_copy+SMPS_RAM.v_main_tempo_timeout(a6)
                move.b  #$80,SMPS_RAM.v_1up_ram_copy+SMPS_RAM.f_speedup(a6)
                rts
; ===========================================================================
; ---------------------------------------------------------------------------
; Change music back to normal speed
; ---------------------------------------------------------------------------
; Sound_E3:
SlowDownMusic:
                tst.b   SMPS_RAM.f_1up_playing(a6)
                bne.s   .slowdown_1up
                move.b  SMPS_RAM.v_tempo_mod(a6),SMPS_RAM.v_main_tempo(a6)
                move.b  SMPS_RAM.v_tempo_mod(a6),SMPS_RAM.v_main_tempo_timeout(a6)
                clr.b   SMPS_RAM.f_speedup(a6)
                rts
; ===========================================================================
; loc_7266A:
.slowdown_1up:
                move.b  SMPS_RAM.v_1up_ram_copy+SMPS_RAM.v_tempo_mod(a6),SMPS_RAM.v_1up_ram_copy+SMPS_RAM.v_main_tempo(a6)
                move.b  SMPS_RAM.v_1up_ram_copy+SMPS_RAM.v_tempo_mod(a6),SMPS_RAM.v_1up_ram_copy+SMPS_RAM.v_main_tempo_timeout(a6)
                clr.b   SMPS_RAM.v_1up_ram_copy+SMPS_RAM.f_speedup(a6)
                rts
; ===========================================================================

; sub_7267C:
DoFadeIn:
                tst.b   SMPS_RAM.v_fadein_delay(a6)     ; has fadein delay expired?
                beq.s   .continuefade                   ; branch if yes
                subq.b  #1,SMPS_RAM.v_fadein_delay(a6)
                rts
; ===========================================================================
; loc_72688:
.continuefade:
                tst.b   SMPS_RAM.v_fadein_counter(a6)   ; is fade done?
                beq.s   .fadedone                       ; branch if yes
                subq.b  #1,SMPS_RAM.v_fadein_counter(a6)  ; update fade counter
                move.b  #2,SMPS_RAM.v_fadein_delay(a6)  ; reset fade delay
                lea     SMPS_RAM.v_music_fm_tracks(a6),a5
                moveq   #SMPS_MUSIC_FM_TRACK_COUNT-1,d7  ; 6 FM tracks
; loc_7269E:
.fmloop:
                tst.b   SMPS_Track.PlaybackControl(a5)  ; is track playing?
                bpl.s   .nextfm                         ; branch if not
                subq.b  #1,SMPS_Track.Volume(a5)        ; reduce volume attenuation
                jsr     SendVoiceTL(pc)
; loc_726AA:
.nextfm:
                adda.w  #SMPS_Track.len,a5
                dbf     d7,.fmloop
                moveq   #SMPS_MUSIC_PSG_TRACK_COUNT-1,d7  ; 3 PSG tracks
; loc_726B4:
.psgloop:
                tst.b   SMPS_Track.PlaybackControl(a5)  ; is track playing?
                bpl.s   .nextpsg                        ; branch if not
                subq.b  #1,SMPS_Track.Volume(a5)        ; reduce volume attenuation
                move.b  SMPS_Track.Volume(a5),d6        ; get value
                cmpi.b  #$10,d6                         ; is it is < $10?
                blo.s   .sendpsgvol                     ; branch if yes
                moveq   #$F,d6                          ; limit to $F (maximum attenuation)
; loc_726C8:
.sendpsgvol:
                jsr     SetPSGVolume(pc)
; loc_726CC:
.nextpsg:
                adda.w  #SMPS_Track.len,a5
                dbf     d7,.psgloop
                rts
; ===========================================================================
; loc_726D6:
.fadedone:
                bclr    #2,SMPS_RAM.v_music_dac_track.PlaybackControl(a6)  ; clear 'SFX overriding' bit
                clr.b   SMPS_RAM.f_fadein_flag(a6)      ; stop fadein

                rts
; End of function DoFadeIn

; ===========================================================================
; loc_726E2:
