FMNoteOn:
                btst    #1,SMPS_Track.PlaybackControl(a5)  ; is track resting?
                bne.s   .locret                         ; return if so
                btst    #2,SMPS_Track.PlaybackControl(a5)  ; is track being overridden?
                bne.s   .locret                         ; return if so
                moveq   #$28,d0                         ; note on/off register
                move.b  SMPS_Track.VoiceControl(a5),d1  ; get channel bits
                ori.b   #$F0,d1                         ; note on on all operators
                bra.w   WriteFMI
; ===========================================================================
; locret_726FC:
.locret:
                rts
; ===========================================================================

; sub_726FE:
FMNoteOff:
                btst    #4,SMPS_Track.PlaybackControl(a5)  ; is 'do not attack next note' set?
                bne.s   FMNoteOff_Return                ; return if yes
                btst    #2,SMPS_Track.PlaybackControl(a5)  ; is SFX overriding?
                bne.s   FMNoteOff_Return                ; return if yes
; loc_7270A:
SendFMNoteOff:
                moveq   #$28,d0                         ; note on/off register
                move.b  SMPS_Track.VoiceControl(a5),d1  ; note off to this channel
                bra.w   WriteFMI
; ===========================================================================

FMNoteOff_Return:
                rts
; End of function FMNoteOff

; ===========================================================================
; loc_72716:
WriteFMIorIIMain:
                btst    #2,SMPS_Track.PlaybackControl(a5)  ; is track being overridden by sfx?
                bne.s   .locret                         ; return if yes
                bra.w   WriteFMIorII
; ===========================================================================
; locret_72720:
.locret:
                rts
; ===========================================================================

; sub_72722:
WriteFMIorII:
                btst    #2,SMPS_Track.VoiceControl(a5)  ; is this bound for part I or II?
                bne.s   WriteFMIIPart                   ; branch if for part II
                add.b   SMPS_Track.VoiceControl(a5),d0  ; add in voice control bits
; End of function WriteFMIorII
; ===========================================================================

; Strangely, despite this driver being SMPS 68k Type 1b,
; WriteFMI and WriteFMII are the Type 1a versions
; In Sonic 1's prototype, they were the Type 1b versions
; I wonder why they were changed?

; sub_7272E:
WriteFMI:
                move.b  (ym2612_a0).l,d2
                btst    #7,d2                           ; is FM busy?
                bne.s   WriteFMI                        ; loop if so
                move.b  d0,(ym2612_a0).l
                nop
                nop
                nop
; loc_72746:
.waitloop:
                move.b  (ym2612_a0).l,d2
                btst    #7,d2                           ; is FM busy?
                bne.s   .waitloop                       ; loop if so

                move.b  d1,(ym2612_d0).l
                rts
; End of function WriteFMI

; ===========================================================================
; loc_7275A:
WriteFMIIPart:
                move.b  SMPS_Track.VoiceControl(a5),d2  ; get voice control bits
                bclr    #2,d2                           ; clear chip toggle
                add.b   d2,d0                           ; add in to destination register
; ===========================================================================

; sub_72764:
WriteFMII:
                move.b  (ym2612_a0).l,d2
                btst    #7,d2                           ; is FM busy?
                bne.s   WriteFMII                       ; loop if so
                move.b  d0,(ym2612_a1).l
                nop
                nop
                nop
; loc_7277C:
.waitloop:
                move.b  (ym2612_a0).l,d2
                btst    #7,d2                           ; is FM busy?
                bne.s   .waitloop                       ; loop if so

                move.b  d1,(ym2612_d1).l
                rts
; End of function WriteFMII

; ===========================================================================
; ---------------------------------------------------------------------------
; FM Note Values: b-0 to a#8
;
; Each row is an octave, starting with B and ending with A-sharp/B-flat
; Notably, this differs from the PSG frequency table, which starts with C and
; ends with B. This is caused by 'FMSetFreq' subtracting $80 from the note
; instead of $81, meaning that the first frequency in the table ironically
; corresponds to the 'rest' note. The only way to use this frequency in a
; real note is to transpose the channel to a lower semitone
;
; Rather than use a complete lookup table, other SMPS drivers such as
; Sonic 3's compute the octave, and only store a single octave's worth of
; notes in the table
;
; Invalid transposition values will cause this table to be overflowed,
; resulting in garbage data being used as frequency values. In drivers that
; compute the octave instead, invalid transposition values merely cause the
; notes to wrap-around (the note below the lowest note will be the highest
; note). It's important to keep this in mind when porting buggy songs
; ---------------------------------------------------------------------------
MakeFMFrequency   function frequency,roundFloatToInteger(frequency*1024*1024*2/FM_Sample_Rate)
MakeFMFrequenciesOctave   macro   octave
; Frequencies for the base octave. The first frequency is B, the last frequency is B-flat
                    irp     op, 15.39, 16.35, 17.34, 18.36, 19.45, 20.64, 21.84, 23.13, 24.51, 25.98, 27.53, 29.15
                    dc.w    MakeFMFrequency(op)+octave*$800
                endm
                endm

; word_72790: FM_Notes:
FMFrequencies:
                MakeFMFrequenciesOctave 0
                MakeFMFrequenciesOctave 1
                MakeFMFrequenciesOctave 2
                MakeFMFrequenciesOctave 3
                MakeFMFrequenciesOctave 4
                MakeFMFrequenciesOctave 5
                MakeFMFrequenciesOctave 6
                MakeFMFrequenciesOctave 7
; ===========================================================================

; sub_72850:
