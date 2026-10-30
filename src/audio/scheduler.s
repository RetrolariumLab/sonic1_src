UpdateMusic:
                stopZ80
                nop
                nop
                nop
; loc_71B5A:
.updateloop:
                btst    #0,(z80_bus_request).l          ; is the z80 busy?
                bne.s   .updateloop                     ; if so, wait

                btst    #7,(z80_ram+zDAC_Status).l      ; is DAC accepting new samples?
                beq.s   .driverinput                    ; branch if yes
                startZ80
                nop
                nop
                nop
                nop
                nop
                bra.s   UpdateMusic
; ===========================================================================

; loc_71B82:
.driverinput:
                lea     (v_snddriver_ram&$FFFFFF).l,a6
                clr.b   SMPS_RAM.f_voice_selector(a6)
                tst.b   SMPS_RAM.f_pausemusic(a6)       ; is music paused?
                bne.w   PauseMusic                      ; if yes, branch
                subq.b  #1,SMPS_RAM.v_main_tempo_timeout(a6)  ; has main tempo timer expired?
                bne.s   .skipdelay
                jsr     TempoWait(pc)
; loc_71B9E:
.skipdelay:
                move.b  SMPS_RAM.v_fadeout_counter(a6),d0
                beq.s   .skipfadeout
                jsr     DoFadeOut(pc)
; loc_71BA8:
.skipfadeout:
                tst.b   SMPS_RAM.f_fadein_flag(a6)
                beq.s   .skipfadein
                jsr     DoFadeIn(pc)
; loc_71BB2:
.skipfadein:
; DANGER! The following line only checks v_soundqueue0 and v_soundqueue1, breaking v_soundqueue2
                tst.w   SMPS_RAM.v_soundqueue0(a6)      ; is a music or sound queued for playing?
                beq.s   .nosndinput                     ; if not, branch
                jsr     CycleSoundQueue(pc)
; loc_71BBC:
.nosndinput:
                cmpi.b  #$80,SMPS_RAM.v_sound_id(a6)    ; is song queue set for silence (empty)?
                beq.s   .nonewsound                     ; if yes, branch
                jsr     PlaySoundID(pc)
; loc_71BC8:
.nonewsound:
                lea     SMPS_RAM.v_music_dac_track(a6),a5
                tst.b   SMPS_Track.PlaybackControl(a5)  ; is DAC track playing?
                bpl.s   .dacdone                        ; branch if not
                jsr     DACUpdateTrack(pc)
; loc_71BD4:
.dacdone:
                clr.b   SMPS_RAM.f_updating_dac(a6)
                moveq   #SMPS_MUSIC_FM_TRACK_COUNT-1,d7  ; 6 FM tracks
; loc_71BDA:
.bgmfmloop:
                adda.w  #SMPS_Track.len,a5
                tst.b   SMPS_Track.PlaybackControl(a5)  ; is track playing?
                bpl.s   .bgmfmnext                      ; branch if not
                jsr     FMUpdateTrack(pc)
; loc_71BE6:
.bgmfmnext:
                dbf     d7,.bgmfmloop

                moveq   #SMPS_MUSIC_PSG_TRACK_COUNT-1,d7  ; 3 PSG tracks
; loc_71BEC:
.bgmpsgloop:
                adda.w  #SMPS_Track.len,a5
                tst.b   SMPS_Track.PlaybackControl(a5)  ; is track playing?
                bpl.s   .bgmpsgnext                     ; branch if not
                jsr     PSGUpdateTrack(pc)
; loc_71BF8:
.bgmpsgnext:
                dbf     d7,.bgmpsgloop

                move.b  #$80,SMPS_RAM.f_voice_selector(a6)  ; now at SFX tracks
                moveq   #SMPS_SFX_FM_TRACK_COUNT-1,d7   ; 3 FM tracks (SFX)
; loc_71C04:
.sfxfmloop:
                adda.w  #SMPS_Track.len,a5
                tst.b   SMPS_Track.PlaybackControl(a5)  ; is track playing?
                bpl.s   .sfxfmnext                      ; branch if not
                jsr     FMUpdateTrack(pc)
; loc_71C10:
.sfxfmnext:
                dbf     d7,.sfxfmloop

                moveq   #SMPS_SFX_PSG_TRACK_COUNT-1,d7  ; 3 PSG tracks (SFX)
; loc_71C16:
.sfxpsgloop:
                adda.w  #SMPS_Track.len,a5
                tst.b   SMPS_Track.PlaybackControl(a5)  ; is track playing?
                bpl.s   .sfxpsgnext                     ; branch if not
                jsr     PSGUpdateTrack(pc)
; loc_71C22:
.sfxpsgnext:
                dbf     d7,.sfxpsgloop

                move.b  #$40,SMPS_RAM.f_voice_selector(a6)  ; now at special SFX tracks
                adda.w  #SMPS_Track.len,a5
                tst.b   SMPS_Track.PlaybackControl(a5)  ; is track playing?
                bpl.s   .specfmdone                     ; branch if not
                jsr     FMUpdateTrack(pc)
; loc_71C38:
.specfmdone:
                adda.w  #SMPS_Track.len,a5
                tst.b   SMPS_Track.PlaybackControl(a5)  ; is track playing
                bpl.s   DoStartZ80                      ; branch if not
                jsr     PSGUpdateTrack(pc)
; loc_71C44:
DoStartZ80:
                startZ80
                rts
; End of function UpdateMusic
; ===========================================================================

; sub_71C4E: UpdateDAC:
