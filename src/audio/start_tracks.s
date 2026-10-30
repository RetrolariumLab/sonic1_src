Sound_PlayBGM:
                cmpi.b  #bgm_ExtraLife,d7               ; is the "extra life" music to be played?
                bne.s   .bgmnot1up                      ; if not, branch
                tst.b   SMPS_RAM.f_1up_playing(a6)      ; is a 1-up music playing?
                bne.w   .locdblret                      ; if yes, branch
                lea     SMPS_RAM.v_music_track_ram(a6),a5
                moveq   #SMPS_MUSIC_TRACK_COUNT-1,d0    ; 1 DAC + 6 FM + 3 PSG tracks
; loc_71FE6:
.clearsfxloop:
                bclr    #2,SMPS_Track.PlaybackControl(a5)  ; clear 'SFX is overriding' bit
                adda.w  #SMPS_Track.len,a5
                dbf     d0,.clearsfxloop

                lea     SMPS_RAM.v_sfx_track_ram(a6),a5
                moveq   #SMPS_SFX_TRACK_COUNT-1,d0      ; 3 FM + 3 PSG tracks (SFX)
; loc_71FF8:
.cleartrackplayloop:
                bclr    #7,SMPS_Track.PlaybackControl(a5)  ; clear 'track is playing' bit
                adda.w  #SMPS_Track.len,a5
                dbf     d0,.cleartrackplayloop

                _clr.b  SMPS_RAM.v_sndprio(a6)          ; clear priority
                movea.l a6,a0
                lea     SMPS_RAM.v_1up_ram_copy(a6),a1
                move.w  #((SMPS_RAM.v_1up_ram_end-SMPS_RAM.v_1up_ram)/4)-1,d0  ; backup $220 bytes: all variables and music track data
; loc_72012:
.backupramloop:
                move.l  (a0)+,(a1)+
                dbf     d0,.backupramloop

                move.b  #$80,SMPS_RAM.f_1up_playing(a6)
                _clr.b  SMPS_RAM.v_sndprio(a6)          ; clear priority again (?)
                bra.s   .bgm_loadMusic
; ===========================================================================
; loc_72024:
.bgmnot1up:
                clr.b   SMPS_RAM.f_1up_playing(a6)
                clr.b   SMPS_RAM.v_fadein_counter(a6)
; loc_7202C:
.bgm_loadMusic:
                jsr     InitMusicPlayback(pc)
                movea.l (Go_SpeedUpIndex).l,a4
                subi.b  #bgm__First,d7
                move.b  (a4,d7.w),SMPS_RAM.v_speeduptempo(a6)
                movea.l (Go_MusicIndex).l,a4
                lsl.w   #2,d7
                movea.l (a4,d7.w),a4                    ; a4 now points to (uncompressed) song data
                moveq   #0,d0
                move.w  (a4),d0                         ; load voice pointer
                add.l   a4,d0                           ; it is a relative pointer
                move.l  d0,SMPS_RAM.v_voice_ptr(a6)
                move.b  5(a4),d0                        ; load tempo
                move.b  d0,SMPS_RAM.v_tempo_mod(a6)
                tst.b   SMPS_RAM.f_speedup(a6)
                beq.s   .nospeedshoes
                move.b  SMPS_RAM.v_speeduptempo(a6),d0
; loc_72068:
.nospeedshoes:
                move.b  d0,SMPS_RAM.v_main_tempo(a6)
                move.b  d0,SMPS_RAM.v_main_tempo_timeout(a6)
                moveq   #0,d1
                movea.l a4,a3
                addq.w  #6,a4                           ; point past header
                moveq   #0,d7
                move.b  2(a3),d7                        ; load number of FM+DAC tracks
                beq.w   .bgm_fmdone                     ; branch if zero
                subq.b  #1,d7
                move.b  #$C0,d1                         ; default AMS+FMS+Panning
                move.b  4(a3),d4                        ; load tempo dividing timing
                moveq   #SMPS_Track.len,d6
                move.b  #1,d5                           ; note duration for first "note"
                lea     SMPS_RAM.v_music_fmdac_tracks(a6),a1
                lea     FMDACInitBytes(pc),a2
; loc_72098:
.bgm_fmloadloop:
                bset    #7,SMPS_Track.PlaybackControl(a1)  ; initial playback control: set 'track playing' bit
                move.b  (a2)+,SMPS_Track.VoiceControl(a1)  ; voice control bits
                move.b  d4,SMPS_Track.TempoDivider(a1)
                move.b  d6,SMPS_Track.StackPointer(a1)  ; set "gosub" (coord flag $F8) stack init value
                move.b  d1,SMPS_Track.AMSFMSPan(a1)     ; set AMS/FMS/Panning
                move.b  d5,SMPS_Track.DurationTimeout(a1)  ; set duration of first "note"
                moveq   #0,d0
                move.w  (a4)+,d0                        ; load DAC/FM pointer
                add.l   a3,d0                           ; relative pointer
                move.l  d0,SMPS_Track.DataPointer(a1)   ; store track pointer
                move.w  (a4)+,SMPS_Track.Transpose(a1)  ; load FM channel modifier
                adda.w  d6,a1
                dbf     d7,.bgm_fmloadloop

                cmpi.b  #7,2(a3)                        ; are 7 FM tracks defined?
                bne.s   .silencefm6
                moveq   #$2B,d0                         ; DAC enable/disable register
                moveq   #0,d1                           ; disable DAC
                jsr     WriteFMI(pc)
                bra.w   .bgm_fmdone
; ===========================================================================
; loc_720D8:
.silencefm6:
                moveq   #$28,d0                         ; key on/off register
                moveq   #6,d1                           ; note off on all operators of channel 6
                jsr     WriteFMI(pc)
                move.b  #$42,d0                         ; TL for operator 1 of FM6
                moveq   #$7F,d1                         ; total silence
                jsr     WriteFMII(pc)
                move.b  #$4A,d0                         ; TL for operator 3 of FM6
                moveq   #$7F,d1                         ; total silence
                jsr     WriteFMII(pc)
                move.b  #$46,d0                         ; TL for operator 2 of FM6
                moveq   #$7F,d1                         ; total silence
                jsr     WriteFMII(pc)
                move.b  #$4E,d0                         ; TL for operator 4 of FM6
                moveq   #$7F,d1                         ; total silence
                jsr     WriteFMII(pc)
                move.b  #$B6,d0                         ; AMS/FMS/panning of FM6
                move.b  #$C0,d1                         ; stereo
                jsr     WriteFMII(pc)
; loc_72114:
.bgm_fmdone:
                moveq   #0,d7
                move.b  3(a3),d7                        ; load number of PSG tracks
                beq.s   .bgm_psgdone                    ; branch if zero
                subq.b  #1,d7
                lea     SMPS_RAM.v_music_psg_tracks(a6),a1
                lea     PSGInitBytes(pc),a2
; loc_72126:
.bgm_psgloadloop:
                bset    #7,SMPS_Track.PlaybackControl(a1)  ; initial playback control: set 'track playing' bit
                move.b  (a2)+,SMPS_Track.VoiceControl(a1)  ; voice control bits
                move.b  d4,SMPS_Track.TempoDivider(a1)
                move.b  d6,SMPS_Track.StackPointer(a1)  ; set "gosub" (coord flag $F8) stack init value
                move.b  d5,SMPS_Track.DurationTimeout(a1)  ; set duration of first "note"
                moveq   #0,d0
                move.w  (a4)+,d0                        ; load PSG channel pointer
                add.l   a3,d0                           ; relative pointer
                move.l  d0,SMPS_Track.DataPointer(a1)   ; store track pointer
                move.w  (a4)+,SMPS_Track.Transpose(a1)  ; load PSG modifier
                move.b  (a4)+,d0                        ; load redundant byte
                move.b  (a4)+,SMPS_Track.VoiceIndex(a1)  ; initial PSG tone
                adda.w  d6,a1
                dbf     d7,.bgm_psgloadloop
; loc_72154:
.bgm_psgdone:
                lea     SMPS_RAM.v_sfx_track_ram(a6),a1
                moveq   #SMPS_SFX_TRACK_COUNT-1,d7      ; 6 SFX tracks
; loc_7215A:
.sfxstoploop:
                tst.b   SMPS_Track.PlaybackControl(a1)  ; is SFX playing?
                bpl.w   .sfxnext                        ; branch if not
                moveq   #0,d0
                move.b  SMPS_Track.VoiceControl(a1),d0  ; get voice control bits
                bmi.s   .sfxpsgchannel                  ; branch if this is a PSG channel
                subq.b  #2,d0                           ; sFX can't have FM1 or FM2
                lsl.b   #2,d0                           ; convert to index
                bra.s   .gotchannelindex
; ===========================================================================
; loc_7216E:
.sfxpsgchannel:
                lsr.b   #3,d0                           ; convert to index
; loc_72170:
.gotchannelindex:
                lea     SFX_BGMChannelRAM(pc),a0
                movea.l (a0,d0.w),a0
                bset    #2,SMPS_Track.PlaybackControl(a0)  ; set 'SFX is overriding' bit
; loc_7217C:
.sfxnext:
                adda.w  d6,a1
                dbf     d7,.sfxstoploop

                tst.w   SMPS_RAM.v_spcsfx_fm4_track.PlaybackControl(a6)  ; is special SFX being played?
                bpl.s   .checkspecialpsg                ; branch if not
                bset    #2,SMPS_RAM.v_music_fm4_track.PlaybackControl(a6)  ; set 'SFX is overriding' bit
; loc_7218E:
.checkspecialpsg:
                tst.w   SMPS_RAM.v_spcsfx_psg3_track.PlaybackControl(a6)  ; is special SFX being played?
                bpl.s   .sendfmnoteoff                  ; branch if not
                bset    #2,SMPS_RAM.v_music_psg3_track.PlaybackControl(a6)  ; set 'SFX is overriding' bit
; loc_7219A:
.sendfmnoteoff:
                lea     SMPS_RAM.v_music_fm_tracks(a6),a5
                moveq   #SMPS_MUSIC_FM_TRACK_COUNT-1,d4  ; 6 FM tracks
; loc_721A0:
.fmnoteoffloop:
                jsr     FMNoteOff(pc)
                adda.w  d6,a5
                dbf     d4,.fmnoteoffloop               ; run all FM tracks
                moveq   #SMPS_MUSIC_PSG_TRACK_COUNT-1,d4  ; 3 PSG tracks
; loc_721AC:
.psgnoteoffloop:
                jsr     PSGNoteOff(pc)
                adda.w  d6,a5
                dbf     d4,.psgnoteoffloop              ; run all PSG tracks
; loc_721B6:
.locdblret:
                addq.w  #4,sp                           ; tamper with return value to not return to caller
                rts
; ===========================================================================
; byte_721BA:
FMDACInitBytes:                                       ; first byte is for DAC; then notice the 0, 1, 2 then 4, 5, 6
; this is the gap between parts I and II for YM2612 port writes
                dc.b    6, 0, 1, 2, 4, 5, 6
                even
; byte_721C2:
PSGInitBytes:                                       ; specifically, these configure writes to the PSG port for each channel
                dc.b    $80, $A0, $C0
                even
; ===========================================================================
; ---------------------------------------------------------------------------
; Play normal sound effect
; ---------------------------------------------------------------------------
; Sound_A0toCF:
Sound_PlaySFX:
                tst.b   SMPS_RAM.f_1up_playing(a6)      ; is 1-up playing?
                bne.w   .clear_sndprio                  ; exit is it is
                tst.b   SMPS_RAM.v_fadeout_counter(a6)  ; is music being faded out?
                bne.w   .clear_sndprio                  ; exit if it is
                tst.b   SMPS_RAM.f_fadein_flag(a6)      ; is music being faded in?
                bne.w   .clear_sndprio                  ; exit if it is
                cmpi.b  #sfx_Ring,d7                    ; is ring sound effect played?
                bne.s   .sfx_notRing                    ; if not, branch
                tst.b   SMPS_RAM.v_ring_speaker(a6)     ; is the ring sound playing on right speaker?
                bne.s   .gotringspeaker                 ; branch if not
                move.b  #sfx_RingLeft,d7                ; play ring sound in left speaker
; loc_721EE:
.gotringspeaker:
                bchg    #0,SMPS_RAM.v_ring_speaker(a6)  ; change speaker
; Sound_notB5:
.sfx_notRing:
                cmpi.b  #sfx_Push,d7                    ; is "pushing" sound played?
                bne.s   .sfx_notPush                    ; if not, branch
                tst.b   SMPS_RAM.f_push_playing(a6)     ; is pushing sound already playing?
                bne.w   .locret                         ; return if not
                move.b  #$80,SMPS_RAM.f_push_playing(a6)  ; mark it as playing
; Sound_notA7:
.sfx_notPush:
                movea.l (Go_SoundIndex).l,a0
                subi.b  #sfx__First,d7                  ; make it 0-based
                lsl.w   #2,d7                           ; convert sfx ID into index
                movea.l (a0,d7.w),a3                    ; sFX data pointer
                movea.l a3,a1
                moveq   #0,d1
                move.w  (a1)+,d1                        ; voice pointer
                add.l   a3,d1                           ; relative pointer
                move.b  (a1)+,d5                        ; dividing timing
                move.b  (a1)+,d7                        ; number of tracks (FM + PSG)
                subq.b  #1,d7
                moveq   #SMPS_Track.len,d6
; loc_72228:
.sfx_loadloop:
                moveq   #0,d3
                move.b  1(a1),d3                        ; channel assignment bits
                move.b  d3,d4
                bmi.s   .sfxinitpsg                     ; branch if PSG
                subq.w  #2,d3                           ; SFX can only have FM3, FM4 or FM5
                lsl.w   #2,d3
                lea     SFX_BGMChannelRAM(pc),a5
                movea.l (a5,d3.w),a5
                bset    #2,SMPS_Track.PlaybackControl(a5)  ; mark music track as being overridden
                bra.s   .sfxoverridedone
; ===========================================================================
; loc_72244:
.sfxinitpsg:
                lsr.w   #3,d3
                lea     SFX_BGMChannelRAM(pc),a5
                movea.l (a5,d3.w),a5
                bset    #2,SMPS_Track.PlaybackControl(a5)  ; mark music track as being overridden
                cmpi.b  #$C0,d4                         ; is this PSG 3?
                bne.s   .sfxoverridedone                ; branch if not
                move.b  d4,d0
                ori.b   #$1F,d0                         ; command to silence PSG 3
                move.b  d0,(psg_input).l
                bchg    #5,d0                           ; command to silence noise channel
                move.b  d0,(psg_input).l
; loc_7226E:
.sfxoverridedone:
                movea.l SFX_SFXChannelRAM(pc,d3.w),a5
                movea.l a5,a2
                moveq   #(SMPS_Track.len/4)-1,d0        ; $30 bytes
; loc_72276:
.clearsfxtrackram:
                clr.l   (a2)+
                dbf     d0,.clearsfxtrackram

                move.w  (a1)+,SMPS_Track.PlaybackControl(a5)  ; initial playback control bits
                move.b  d5,SMPS_Track.TempoDivider(a5)  ; initial voice control bits
                moveq   #0,d0
                move.w  (a1)+,d0                        ; track data pointer
                add.l   a3,d0                           ; relative pointer
                move.l  d0,SMPS_Track.DataPointer(a5)   ; store track pointer
                move.w  (a1)+,SMPS_Track.Transpose(a5)  ; load FM/PSG channel modifier
                move.b  #1,SMPS_Track.DurationTimeout(a5)  ; set duration of first "note"
                move.b  d6,SMPS_Track.StackPointer(a5)  ; set "gosub" (coord flag $F8) stack init value
                tst.b   d4                              ; is this a PSG channel?
                bmi.s   .sfxpsginitdone                 ; branch if yes
                move.b  #$C0,SMPS_Track.AMSFMSPan(a5)   ; AMS/FMS/Panning
                move.l  d1,SMPS_Track.VoicePtr(a5)      ; voice pointer
; loc_722A8:
.sfxpsginitdone:
                dbf     d7,.sfx_loadloop

                tst.b   SMPS_RAM.v_sfx_fm4_track.PlaybackControl(a6)  ; is special SFX being played?
                bpl.s   .doneoverride                   ; branch if not
                bset    #2,SMPS_RAM.v_spcsfx_fm4_track.PlaybackControl(a6)  ; set 'SFX is overriding' bit
; loc_722B8:
.doneoverride:
                tst.b   SMPS_RAM.v_sfx_psg3_track.PlaybackControl(a6)  ; is SFX being played?
                bpl.s   .locret                         ; branch if not
                bset    #2,SMPS_RAM.v_spcsfx_psg3_track.PlaybackControl(a6)  ; set 'SFX is overriding' bit
; locret_722C4:
.locret:
                rts
; ===========================================================================
; loc_722C6:
.clear_sndprio:
                _clr.b  SMPS_RAM.v_sndprio(a6)          ; clear priority
                rts
; ===========================================================================
; ---------------------------------------------------------------------------
; RAM addresses for FM and PSG channel variables used by the SFX
; ---------------------------------------------------------------------------
; dword_722CC: BGMChannelRAM:
SFX_BGMChannelRAM:
                dc.l    (v_snddriver_ram.v_music_fm3_track)&$FFFFFF
                dc.l    0
                dc.l    (v_snddriver_ram.v_music_fm4_track)&$FFFFFF
                dc.l    (v_snddriver_ram.v_music_fm5_track)&$FFFFFF
                dc.l    (v_snddriver_ram.v_music_psg1_track)&$FFFFFF
                dc.l    (v_snddriver_ram.v_music_psg2_track)&$FFFFFF
                dc.l    (v_snddriver_ram.v_music_psg3_track)&$FFFFFF  ; plain PSG3
                dc.l    (v_snddriver_ram.v_music_psg3_track)&$FFFFFF  ; noise
; dword_722EC: SFXChannelRAM:
SFX_SFXChannelRAM:
                dc.l    (v_snddriver_ram.v_sfx_fm3_track)&$FFFFFF
                dc.l    0
                dc.l    (v_snddriver_ram.v_sfx_fm4_track)&$FFFFFF
                dc.l    (v_snddriver_ram.v_sfx_fm5_track)&$FFFFFF
                dc.l    (v_snddriver_ram.v_sfx_psg1_track)&$FFFFFF
                dc.l    (v_snddriver_ram.v_sfx_psg2_track)&$FFFFFF
                dc.l    (v_snddriver_ram.v_sfx_psg3_track)&$FFFFFF  ; plain PSG3
                dc.l    (v_snddriver_ram.v_sfx_psg3_track)&$FFFFFF  ; noise
; ===========================================================================
; ---------------------------------------------------------------------------
; Play GHZ waterfall sound
; ---------------------------------------------------------------------------
; Sound_D0toDF:
Sound_PlaySpecial:
                tst.b   SMPS_RAM.f_1up_playing(a6)      ; is 1-up playing?
                bne.w   .locret                         ; return if so
                tst.b   SMPS_RAM.v_fadeout_counter(a6)  ; is music being faded out?
                bne.w   .locret                         ; exit if it is
                tst.b   SMPS_RAM.f_fadein_flag(a6)      ; is music being faded in?
                bne.w   .locret                         ; exit if it is
                movea.l (Go_SpecSoundIndex).l,a0
                subi.b  #spec__First,d7                 ; make it 0-based
                lsl.w   #2,d7
                movea.l (a0,d7.w),a3
                movea.l a3,a1
                moveq   #0,d0
                move.w  (a1)+,d0                        ; voice pointer
                add.l   a3,d0                           ; relative pointer
                move.l  d0,SMPS_RAM.v_special_voice_ptr(a6)  ; store voice pointer
                move.b  (a1)+,d5                        ; dividing timing
                move.b  (a1)+,d7                        ; number of tracks (FM + PSG)
                subq.b  #1,d7
                moveq   #SMPS_Track.len,d6
; loc_72348:
.sfxloadloop:
                move.b  1(a1),d4                        ; voice control bits
                bmi.s   .sfxoverridepsg                 ; branch if PSG
                bset    #2,SMPS_RAM.v_music_fm4_track.PlaybackControl(a6)  ; set 'SFX is overriding' bit

                lea     SMPS_RAM.v_spcsfx_fm4_track(a6),a5
                bra.s   .sfxinitpsg
; ===========================================================================
; loc_7235A:
.sfxoverridepsg:
                bset    #2,SMPS_RAM.v_music_psg3_track.PlaybackControl(a6)  ; set 'SFX is overriding' bit
                lea     SMPS_RAM.v_spcsfx_psg3_track(a6),a5
; loc_72364:
.sfxinitpsg:
                movea.l a5,a2
                moveq   #(SMPS_Track.len/4)-1,d0        ; $30 bytes
; loc_72368:
.clearsfxtrackram:
                clr.l   (a2)+
                dbf     d0,.clearsfxtrackram

                move.w  (a1)+,SMPS_Track.PlaybackControl(a5)  ; initial playback control bits & voice control bits
                move.b  d5,SMPS_Track.TempoDivider(a5)
                moveq   #0,d0
                move.w  (a1)+,d0                        ; track data pointer
                add.l   a3,d0                           ; relative pointer
                move.l  d0,SMPS_Track.DataPointer(a5)   ; store track pointer
                move.w  (a1)+,SMPS_Track.Transpose(a5)  ; load FM/PSG channel modifier
                move.b  #1,SMPS_Track.DurationTimeout(a5)  ; set duration of first "note"
                move.b  d6,SMPS_Track.StackPointer(a5)  ; set "gosub" (coord flag $F8) stack init value
                tst.b   d4                              ; is this a PSG channel?
                bmi.s   .sfxpsginitdone                 ; branch if yes
                move.b  #$C0,SMPS_Track.AMSFMSPan(a5)   ; AMS/FMS/Panning
; loc_72396:
.sfxpsginitdone:
                dbf     d7,.sfxloadloop

                tst.b   SMPS_RAM.v_sfx_fm4_track.PlaybackControl(a6)  ; is track playing?
                bpl.s   .doneoverride                   ; branch if not
                bset    #2,SMPS_RAM.v_spcsfx_fm4_track.PlaybackControl(a6)  ; set 'SFX is overriding' bit
; loc_723A6:
.doneoverride:
                tst.b   SMPS_RAM.v_sfx_psg3_track.PlaybackControl(a6)  ; is track playing?
                bpl.s   .locret                         ; branch if not
                bset    #2,SMPS_RAM.v_spcsfx_psg3_track.PlaybackControl(a6)  ; set 'SFX is overriding' bit
                ori.b   #$1F,d4                         ; command to silence channel
                move.b  d4,(psg_input).l
                bchg    #5,d4                           ; command to silence noise channel
                move.b  d4,(psg_input).l
; locret_723C6:
.locret:
                rts
; End of function PlaySoundID

; ===========================================================================
; ---------------------------------------------------------------------------
; Unused RAM addresses for FM and PSG channel variables used by the Special SFX
; ---------------------------------------------------------------------------
; The first block would have been used for overriding the music tracks
; as they have a lower priority, just as they are in Sound_PlaySFX
; The third block would be used to set up the Special SFX
; The second block, however, is for the SFX tracks, which have a higher priority
; and would be checked for if they're currently playing
; If they are, then the third block would be used again, this time to mark
; the new tracks as 'currently playing'

; These were actually used in Moonwalker's driver (and other SMPS 68k Type 1a drivers)

; BGMFM4PSG3RAM:
; SpecSFX_BGMChannelRAM:
                dc.l    (v_snddriver_ram.v_music_fm4_track)&$FFFFFF
                dc.l    (v_snddriver_ram.v_music_psg3_track)&$FFFFFF
; SFXFM4PSG3RAM:
; SpecSFX_SFXChannelRAM:
                dc.l    (v_snddriver_ram.v_sfx_fm4_track)&$FFFFFF
                dc.l    (v_snddriver_ram.v_sfx_psg3_track)&$FFFFFF
; SpecialSFXFM4PSG3RAM:
; SpecSFX_SpecSFXChannelRAM:
                dc.l    (v_snddriver_ram.v_spcsfx_fm4_track)&$FFFFFF
                dc.l    (v_snddriver_ram.v_spcsfx_psg3_track)&$FFFFFF
; ===========================================================================

; Snd_FadeOut1: Snd_FadeOutSFX: FadeOutSFX:
