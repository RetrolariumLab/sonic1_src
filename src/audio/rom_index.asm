; ---------------------------------------------------------------------------

; SoundDriver starts at $71990 in all revisions, which amounts
; to $62A bytes of padding for rev00 and $63C for rev01/rev02
; It appears to be placed in such a way that the sound driver
; ends right on the $80000 mark in the ROM in all revisions
; From a technical standpoint, this padding serves no purpose
                if      Revision=0
                dcb.b   $62A,$FF
                else
                dcb.b   $63C,$FF
                endif

; ---------------------------------------------------------------------------

SoundDriver:   include "src/audio/main.asm"
                even

; ---------------------------------------------------------------------------

; end of 'ROM'
