; ---------------------------------------------------------------------------
; Modified SMPS 68k Type 1b sound driver
; The source code to a similar version of the driver can be found here:
; https://hiddenpalace.org/News/Sega_of_Japan_Sound_Documents_and_Source_Code
; ---------------------------------------------------------------------------

; Constants
SMPS_TRACK_COUNT   =       (SMPS_RAM.v_track_ram_end-SMPS_RAM.v_track_ram)/SMPS_Track.len
SMPS_MUSIC_TRACK_COUNT   =       (SMPS_RAM.v_music_track_ram_end-SMPS_RAM.v_music_track_ram)/SMPS_Track.len
SMPS_MUSIC_FM_DAC_TRACK_COUNT   =       (SMPS_RAM.v_music_fmdac_tracks_end-SMPS_RAM.v_music_fmdac_tracks)/SMPS_Track.len
SMPS_MUSIC_FM_TRACK_COUNT   =       (SMPS_RAM.v_music_fm_tracks_end-SMPS_RAM.v_music_fm_tracks)/SMPS_Track.len
SMPS_MUSIC_PSG_TRACK_COUNT   =       (SMPS_RAM.v_music_psg_tracks_end-SMPS_RAM.v_music_psg_tracks)/SMPS_Track.len
SMPS_SFX_TRACK_COUNT   =       (SMPS_RAM.v_sfx_track_ram_end-SMPS_RAM.v_sfx_track_ram)/SMPS_Track.len
SMPS_SFX_FM_TRACK_COUNT   =       (SMPS_RAM.v_sfx_fm_tracks_end-SMPS_RAM.v_sfx_fm_tracks)/SMPS_Track.len
SMPS_SFX_PSG_TRACK_COUNT   =       (SMPS_RAM.v_sfx_psg_tracks_end-SMPS_RAM.v_sfx_psg_tracks)/SMPS_Track.len
SMPS_SPECIAL_SFX_TRACK_COUNT   =       (SMPS_RAM.v_spcsfx_track_ram_end-SMPS_RAM.v_spcsfx_track_ram)/SMPS_Track.len
SMPS_SPECIAL_SFX_FM_TRACK_COUNT   =       (SMPS_RAM.v_spcsfx_fm_tracks_end-SMPS_RAM.v_spcsfx_fm_tracks)/SMPS_Track.len
SMPS_SPECIAL_SFX_PSG_TRACK_COUNT   =       (SMPS_RAM.v_spcsfx_psg_tracks_end-SMPS_RAM.v_spcsfx_psg_tracks)/SMPS_Track.len
; ---------------------------------------------------------------------------
; Macros
; turn a sample rate into a djnz loop counter
pcmLoopCounterBase   function sampleRate,baseCycles, 1+(Z80_Clock/(sampleRate)-(baseCycles)+(13/2))/13
pcmLoopCounter   function sampleRate, pcmLoopCounterBase(sampleRate,90)  ; 90 is the number of cycles zPlaySEGAPCMLoop takes to deliver one sample
dpcmLoopCounter   function sampleRate, pcmLoopCounterBase(sampleRate,301/2)  ; 301 is the number of cycles zPlayPCMLoop takes to deliver two samples
; ---------------------------------------------------------------------------

; Go_SoundTypes:
Go_SoundPriorities:   dc.l    SoundPriorities
; Go_SoundD0:
Go_SpecSoundIndex:   dc.l    SpecSoundIndex
Go_MusicIndex:   dc.l    MusicIndex
Go_SoundIndex:   dc.l    SoundIndex
; off_719A0:
Go_SpeedUpIndex:   dc.l    SpeedUpIndex
Go_PSGIndex:   dc.l    PSG_Index

; ===========================================================================
; ---------------------------------------------------------------------------
; PSG instruments used in music
; ---------------------------------------------------------------------------
PSG_Index:
                dc.l    PSG1, PSG2, PSG3
                dc.l    PSG4, PSG5, PSG6
                dc.l    PSG7, PSG8, PSG9

PSG1:   binclude "sound/psg/psg1.bin"

PSG2:   binclude "sound/psg/psg2.bin"

PSG3:   binclude "sound/psg/psg3.bin"

PSG4:   binclude "sound/psg/psg4.bin"

PSG6:   binclude "sound/psg/psg6.bin"

PSG5:   binclude "sound/psg/psg5.bin"

PSG7:   binclude "sound/psg/psg7.bin"

PSG8:   binclude "sound/psg/psg8.bin"

PSG9:   binclude "sound/psg/psg9.bin"

; ===========================================================================
; ---------------------------------------------------------------------------
; New tempos for songs during speed shoes
; ---------------------------------------------------------------------------
; DANGER! several songs will use the first few bytes of MusicIndex as their main
; tempos while speed shoes are active. If you don't want that, you should add
; their "correct" sped-up main tempos to the list
; byte_71A94:
SpeedUpIndex:
                dc.b    7                               ; GHZ
                dc.b    $72                             ; LZ
                dc.b    $73                             ; MZ
                dc.b    $26                             ; SLZ
                dc.b    $15                             ; SYZ
                dc.b    8                               ; SBZ
                dc.b    $FF                             ; Invincibility
                dc.b    5                               ; Extra Life
; dc.b ?  ; Special Stage
; dc.b ?  ; Title Screen
; dc.b ?  ; Ending
; dc.b ?  ; Boss
; dc.b ?  ; FZ
; dc.b ?  ; Sonic Got Through
; dc.b ?  ; Game Over
; dc.b ?  ; Continue Screen
; dc.b ?  ; Credits
; dc.b ?  ; Drowning
; dc.b ?  ; Get Emerald

; ===========================================================================
; ---------------------------------------------------------------------------
; Music Pointers
; ---------------------------------------------------------------------------
MusicIndex:
ptr_mus81:   dc.l    Music81
ptr_mus82:   dc.l    Music82
ptr_mus83:   dc.l    Music83
ptr_mus84:   dc.l    Music84
ptr_mus85:   dc.l    Music85
ptr_mus86:   dc.l    Music86
ptr_mus87:   dc.l    Music87
ptr_mus88:   dc.l    Music88
ptr_mus89:   dc.l    Music89
ptr_mus8A:   dc.l    Music8A
ptr_mus8B:   dc.l    Music8B
ptr_mus8C:   dc.l    Music8C
ptr_mus8D:   dc.l    Music8D
ptr_mus8E:   dc.l    Music8E
ptr_mus8F:   dc.l    Music8F
ptr_mus90:   dc.l    Music90
ptr_mus91:   dc.l    Music91
ptr_mus92:   dc.l    Music92
ptr_mus93:   dc.l    Music93
ptr_musend

; ===========================================================================
; ---------------------------------------------------------------------------
; Priority of sound. New music or SFX must have a priority higher than or equal
; to what is stored in v_sndprio or it won't play. If bit 7 of new priority is
; set ($80 and up), the new music or SFX will not set its priority -- meaning
; any music or SFX can override it (as long as it can override whatever was
; playing before). Usually, SFX will only override SFX, special SFX ($D0-$DF)
; will only override special SFX and music will only override music
; ---------------------------------------------------------------------------
; SoundTypes:
SoundPriorities:
                dc.b    $90,$90,$90,$90,$90,$90,$90,$90,$90,$90,$90,$90,$90,$90,$90  ; $81
                dc.b    $90,$90,$90,$90,$90,$90,$90,$90,$90,$90,$90,$90,$90,$90,$90,$90  ; $90
                dc.b    $80,$70,$70,$70,$70,$70,$70,$70,$70,$70,$68,$70,$70,$70,$60,$70  ; $A0
                dc.b    $70,$60,$70,$60,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$7F  ; $B0
                dc.b    $60,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70,$70  ; $C0
                dc.b    $80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80,$80  ; $D0
                dc.b    $90,$90,$90,$90,$90             ; $E0

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to update music more than once per frame
; (Called by horizontal & vert. interrupts)
; ---------------------------------------------------------------------------

; sub_71B4C:
