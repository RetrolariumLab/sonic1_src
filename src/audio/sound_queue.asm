PauseMusic:
                bmi.s   .unpausemusic                   ; branch if music is being unpaused
                cmpi.b  #2,SMPS_RAM.f_pausemusic(a6)
                beq.w   .unpausedallfm
                move.b  #2,SMPS_RAM.f_pausemusic(a6)
                moveq   #2,d3
                move.b  #$B4,d0                         ; command to set AMS/FMS/panning
                moveq   #0,d1                           ; no panning, AMS or FMS
; loc_71E6A:
.killpanloop:
                jsr     WriteFMI(pc)
                jsr     WriteFMII(pc)
                addq.b  #1,d0
                dbf     d3,.killpanloop

                moveq   #2,d3
                moveq   #$28,d0                         ; key on/off register
; loc_71E7C:
.noteoffloop:
                move.b  d3,d1                           ; FM1, FM2, FM3
                jsr     WriteFMI(pc)
                addq.b  #4,d1                           ; FM4, FM5, FM6
                jsr     WriteFMI(pc)
                dbf     d3,.noteoffloop

                jsr     PSGSilenceAll(pc)
                bra.w   DoStartZ80
; ===========================================================================
; loc_71E94:
.unpausemusic:
                clr.b   SMPS_RAM.f_pausemusic(a6)
                moveq   #SMPS_Track.len,d3
                lea     SMPS_RAM.v_music_fmdac_tracks(a6),a5
                moveq   #SMPS_MUSIC_FM_DAC_TRACK_COUNT-1,d4  ; 6 FM + 1 DAC tracks
; loc_71EA0:
.bgmfmloop:
                btst    #7,SMPS_Track.PlaybackControl(a5)  ; is track playing?
                beq.s   .bgmfmnext                      ; branch if not
                btst    #2,SMPS_Track.PlaybackControl(a5)  ; is track being overridden?
                bne.s   .bgmfmnext                      ; branch if yes
                move.b  #$B4,d0                         ; command to set AMS/FMS/panning
                move.b  SMPS_Track.AMSFMSPan(a5),d1     ; get value from track RAM
                jsr     WriteFMIorII(pc)
; loc_71EB8:
.bgmfmnext:
                adda.w  d3,a5
                dbf     d4,.bgmfmloop

                lea     SMPS_RAM.v_sfx_fm_tracks(a6),a5
                moveq   #SMPS_SFX_FM_TRACK_COUNT-1,d4   ; 3 FM tracks (SFX)
; loc_71EC4:
.sfxfmloop:
                btst    #7,SMPS_Track.PlaybackControl(a5)  ; is track playing?
                beq.s   .sfxfmnext                      ; branch if not
                btst    #2,SMPS_Track.PlaybackControl(a5)  ; is track being overridden?
                bne.s   .sfxfmnext                      ; branch if yes
                move.b  #$B4,d0                         ; command to set AMS/FMS/panning
                move.b  SMPS_Track.AMSFMSPan(a5),d1     ; get value from track RAM
                jsr     WriteFMIorII(pc)
; loc_71EDC:
.sfxfmnext:
                adda.w  d3,a5
                dbf     d4,.sfxfmloop

                lea     SMPS_RAM.v_spcsfx_track_ram(a6),a5
                btst    #7,SMPS_Track.PlaybackControl(a5)  ; is track playing?
                beq.s   .unpausedallfm                  ; branch if not
                btst    #2,SMPS_Track.PlaybackControl(a5)  ; is track being overridden?
                bne.s   .unpausedallfm                  ; branch if yes
                move.b  #$B4,d0                         ; command to set AMS/FMS/panning
                move.b  SMPS_Track.AMSFMSPan(a5),d1     ; get value from track RAM
                jsr     WriteFMIorII(pc)
; loc_71EFE:
.unpausedallfm:
                bra.w   DoStartZ80

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to play a sound or music track
; ---------------------------------------------------------------------------

; Sound_Play:
CycleSoundQueue:
                movea.l (Go_SoundPriorities).l,a0
                lea     SMPS_RAM.v_soundqueue0(a6),a1   ; load music track number
                _move.b SMPS_RAM.v_sndprio(a6),d3       ; get priority of currently playing SFX
                moveq   #SMPS_RAM.v_soundqueue_end-SMPS_RAM.v_soundqueue_start-1,d4
; loc_71F12:
.inputloop:
                move.b  (a1),d0                         ; move track number to d0
                move.b  d0,d1
                clr.b   (a1)+                           ; clear entry
                subi.b  #bgm__First,d0                  ; make it into 0-based index
                bcs.s   .nextinput                      ; if negative (i.e., it was $80 or lower), branch
                cmpi.b  #$80,SMPS_RAM.v_sound_id(a6)    ; is v_sound_id a $80 (silence/empty)?
                beq.s   .havesound                      ; if yes, branch
                move.b  d1,SMPS_RAM.v_soundqueue0(a6)   ; put sound into v_soundqueue0
                bra.s   .nextinput
; ===========================================================================
; loc_71F2C:
.havesound:
                andi.w  #$7F,d0                         ; clear high byte and sign bit
                move.b  (a0,d0.w),d2                    ; get sound type
                cmp.b   d3,d2                           ; is it a lower priority sound?
                blo.s   .nextinput                      ; branch if yes
                move.b  d2,d3                           ; store new priority
                move.b  d1,SMPS_RAM.v_sound_id(a6)      ; queue sound for playing
; loc_71F3E:
.nextinput:
                dbf     d4,.inputloop

                tst.b   d3                              ; we don't want to change sound priority if it is negative
                bmi.s   .locret
                _move.b d3,SMPS_RAM.v_sndprio(a6)       ; set new sound priority
; locret_71F4A:
.locret:
                rts
; End of function CycleSoundQueue
; ===========================================================================

; Sound_ChkValue:
PlaySoundID:
                moveq   #0,d7
                move.b  SMPS_RAM.v_sound_id(a6),d7
                beq.w   StopAllSound
                bpl.s   .locret                         ; if >= 0, return (not a valid sound, bgm or command)
                move.b  #$80,SMPS_RAM.v_sound_id(a6)    ; reset music flag
; DANGER! Music ends at $93, yet this checks until $9F; attempting to
; play sounds $94-$9F will cause a crash!
; See LevSel_NoCheat for more
                cmpi.b  #bgm__Last+$C,d7                ; is this music ($81-$9F)?
                bls.w   Sound_PlayBGM                   ; branch if yes
                cmpi.b  #sfx__First,d7                  ; is this after music but before sfx? (redundant check)
                blo.w   .locret                         ; return if yes
                cmpi.b  #sfx__Last,d7                   ; is this sfx ($A0-$CF)?
                bls.w   Sound_PlaySFX                   ; branch if yes
                cmpi.b  #spec__First,d7                 ; is this after sfx but before special sfx? (redundant check)
                blo.w   .locret                         ; return if yes
; DANGER! Special SFXes end at $D0, yet this checks until $DF; attempting to
; play sounds $D1-$DF will cause a crash!
                cmpi.b  #spec__Last+$10,d7              ; is this special sfx ($D0-$DF)?
                blo.w   Sound_PlaySpecial               ; branch if yes
                cmpi.b  #flg__Last,d7                   ; is this $E0-$E4?
                bls.s   Sound_E0toE4                    ; branch if yes
; locret_71F8C:
.locret:
                rts
; ===========================================================================

Sound_E0toE4:
                subi.b  #flg__First,d7
                lsl.w   #2,d7
                jmp     Sound_ExIndex(pc,d7.w)
; ===========================================================================

Sound_ExIndex:
ptr_flgE0:   bra.w   FadeOutMusic                ; $E0
ptr_flgE1:   bra.w   PlaySegaSound               ; $E1
ptr_flgE2:   bra.w   SpeedUpMusic                ; $E2
ptr_flgE3:   bra.w   SlowDownMusic               ; $E3
ptr_flgE4:   bra.w   StopAllSound                ; $E4
ptr_flgend
; ===========================================================================
; ---------------------------------------------------------------------------
; Play "Say-gaa" PCM sound
; ---------------------------------------------------------------------------
; Sound_E1: PlaySega:
PlaySegaSound:
                move.b  #$88,(z80_ram+zDAC_Sample).l    ; queue Sega PCM
                startZ80
                move.w  #$11,d1
; loc_71FC0:
.busyloop_outer:
                move.w  #-1,d0
; loc_71FC4:
.busyloop:
                nop
                dbf     d0,.busyloop

                dbf     d1,.busyloop_outer

                addq.w  #4,sp                           ; tamper return value so we don't return to caller
                rts
; ===========================================================================
; ---------------------------------------------------------------------------
; Play music track $81-$9F
; ---------------------------------------------------------------------------
; Sound_81to9F:
