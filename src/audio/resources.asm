DACDriver:   include "src/audio/z80.asm"

; ---------------------------------------------------------------------------
; Music data
; ---------------------------------------------------------------------------
Music81:   binclude "sound/music/music81.smps"
                even
Music82:   binclude "sound/music/music82.smps"
                even
Music83:   binclude "sound/music/music83.smps"
                even
Music84:   binclude "sound/music/music84.smps"
                even
Music85:   binclude "sound/music/music85.smps"
                even
Music86:   binclude "sound/music/music86.smps"
                even
Music87:   binclude "sound/music/music87.smps"
                even
Music88:   binclude "sound/music/music88.smps"
                even
Music89:   binclude "sound/music/music89.smps"
                even
Music8A:   binclude "sound/music/music8a.smps"
                even
Music8B:   binclude "sound/music/music8b.smps"
                even
Music8C:   binclude "sound/music/music8c.smps"
                even
Music8D:   binclude "sound/music/music8d.smps"
                even
Music8E:   binclude "sound/music/music8e.smps"
                even
Music8F:   binclude "sound/music/music8f.smps"
                even
Music90:   binclude "sound/music/music90.smps"
                even
Music91:   binclude "sound/music/music91.smps"
                even
Music92:   binclude "sound/music/music92.smps"
                even
Music93:   binclude "sound/music/music93.smps"
                even

; ---------------------------------------------------------------------------
; Sound effect pointers
; ---------------------------------------------------------------------------
SoundIndex:
ptr_sndA0:   dc.l    SoundA0
ptr_sndA1:   dc.l    SoundA1
ptr_sndA2:   dc.l    SoundA2
ptr_sndA3:   dc.l    SoundA3
ptr_sndA4:   dc.l    SoundA4
ptr_sndA5:   dc.l    SoundA5
ptr_sndA6:   dc.l    SoundA6
ptr_sndA7:   dc.l    SoundA7
ptr_sndA8:   dc.l    SoundA8
ptr_sndA9:   dc.l    SoundA9
ptr_sndAA:   dc.l    SoundAA
ptr_sndAB:   dc.l    SoundAB
ptr_sndAC:   dc.l    SoundAC
ptr_sndAD:   dc.l    SoundAD
ptr_sndAE:   dc.l    SoundAE
ptr_sndAF:   dc.l    SoundAF
ptr_sndB0:   dc.l    SoundB0
ptr_sndB1:   dc.l    SoundB1
ptr_sndB2:   dc.l    SoundB2
ptr_sndB3:   dc.l    SoundB3
ptr_sndB4:   dc.l    SoundB4
ptr_sndB5:   dc.l    SoundB5
ptr_sndB6:   dc.l    SoundB6
ptr_sndB7:   dc.l    SoundB7
ptr_sndB8:   dc.l    SoundB8
ptr_sndB9:   dc.l    SoundB9
ptr_sndBA:   dc.l    SoundBA
ptr_sndBB:   dc.l    SoundBB
ptr_sndBC:   dc.l    SoundBC
ptr_sndBD:   dc.l    SoundBD
ptr_sndBE:   dc.l    SoundBE
ptr_sndBF:   dc.l    SoundBF
ptr_sndC0:   dc.l    SoundC0
ptr_sndC1:   dc.l    SoundC1
ptr_sndC2:   dc.l    SoundC2
ptr_sndC3:   dc.l    SoundC3
ptr_sndC4:   dc.l    SoundC4
ptr_sndC5:   dc.l    SoundC5
ptr_sndC6:   dc.l    SoundC6
ptr_sndC7:   dc.l    SoundC7
ptr_sndC8:   dc.l    SoundC8
ptr_sndC9:   dc.l    SoundC9
ptr_sndCA:   dc.l    SoundCA
ptr_sndCB:   dc.l    SoundCB
ptr_sndCC:   dc.l    SoundCC
ptr_sndCD:   dc.l    SoundCD
ptr_sndCE:   dc.l    SoundCE
ptr_sndCF:   dc.l    SoundCF
ptr_sndend

; ---------------------------------------------------------------------------
; Special sound effect pointers
; ---------------------------------------------------------------------------
SpecSoundIndex:
ptr_sndD0:   dc.l    SoundD0
ptr_specend

; ---------------------------------------------------------------------------
; Sound effect data
; ---------------------------------------------------------------------------
SoundA0:   binclude "sound/sfx/sounda0.smps"
                even
SoundA1:   binclude "sound/sfx/sounda1.smps"
                even
SoundA2:   binclude "sound/sfx/sounda2.smps"
                even
SoundA3:   binclude "sound/sfx/sounda3.smps"
                even
SoundA4:   binclude "sound/sfx/sounda4.smps"
                even
SoundA5:   binclude "sound/sfx/sounda5.smps"
                even
SoundA6:   binclude "sound/sfx/sounda6.smps"
                even
SoundA7:   binclude "sound/sfx/sounda7.smps"
                even
SoundA8:   binclude "sound/sfx/sounda8.smps"
                even
SoundA9:   binclude "sound/sfx/sounda9.smps"
                even
SoundAA:   binclude "sound/sfx/soundaa.smps"
                even
SoundAB:   binclude "sound/sfx/soundab.smps"
                even
SoundAC:   binclude "sound/sfx/soundac.smps"
                even
SoundAD:   binclude "sound/sfx/soundad.smps"
                even
SoundAE:   binclude "sound/sfx/soundae.smps"
                even
SoundAF:   binclude "sound/sfx/soundaf.smps"
                even
SoundB0:   binclude "sound/sfx/soundb0.smps"
                even
SoundB1:   binclude "sound/sfx/soundb1.smps"
                even
SoundB2:   binclude "sound/sfx/soundb2.smps"
                even
SoundB3:   binclude "sound/sfx/soundb3.smps"
                even
SoundB4:   binclude "sound/sfx/soundb4.smps"
                even
SoundB5:   binclude "sound/sfx/soundb5.smps"
                even
SoundB6:   binclude "sound/sfx/soundb6.smps"
                even
SoundB7:   binclude "sound/sfx/soundb7.smps"
                even
SoundB8:   binclude "sound/sfx/soundb8.smps"
                even
SoundB9:   binclude "sound/sfx/soundb9.smps"
                even
SoundBA:   binclude "sound/sfx/soundba.smps"
                even
SoundBB:   binclude "sound/sfx/soundbb.smps"
                even
SoundBC:   binclude "sound/sfx/soundbc.smps"
                even
SoundBD:   binclude "sound/sfx/soundbd.smps"
                even
SoundBE:   binclude "sound/sfx/soundbe.smps"
                even
SoundBF:   binclude "sound/sfx/soundbf.smps"
                even
SoundC0:   binclude "sound/sfx/soundc0.smps"
                even
SoundC1:   binclude "sound/sfx/soundc1.smps"
                even
SoundC2:   binclude "sound/sfx/soundc2.smps"
                even
SoundC3:   binclude "sound/sfx/soundc3.smps"
                even
SoundC4:   binclude "sound/sfx/soundc4.smps"
                even
SoundC5:   binclude "sound/sfx/soundc5.smps"
                even
SoundC6:   binclude "sound/sfx/soundc6.smps"
                even
SoundC7:   binclude "sound/sfx/soundc7.smps"
                even
SoundC8:   binclude "sound/sfx/soundc8.smps"
                even
SoundC9:   binclude "sound/sfx/soundc9.smps"
                even
SoundCA:   binclude "sound/sfx/soundca.smps"
                even
SoundCB:   binclude "sound/sfx/soundcb.smps"
                even
SoundCC:   binclude "sound/sfx/soundcc.smps"
                even
SoundCD:   binclude "sound/sfx/soundcd.smps"
                even
SoundCE:   binclude "sound/sfx/soundce.smps"
                even
SoundCF:   binclude "sound/sfx/soundcf.smps"
                even

; ---------------------------------------------------------------------------
; Special sound effect data
; ---------------------------------------------------------------------------
SoundD0:   binclude "sound/sfx/soundd0.smps"
                even

; ---------------------------------------------------------------------------
; 'Sega' chant PCM sample
; ---------------------------------------------------------------------------
; Don't let Sega sample cross $8000-byte boundary
; (DAC driver doesn't switch banks automatically)
                if      ((*)&$7FFF)+Size_of_SegaPCM>$8000
                align   $8000
                endif
SegaPCM:   include "src/audio/dac/pcm/sega.asm"
                even

                if      SegaPCM.size>$8000
                fatal   "Sega sound must fit within $8000 bytes, but you have a $\{SegaPCM.size} byte Sega sound."
                endif
                if      SegaPCM.size>Size_of_SegaPCM
                fatal   "Size_of_SegaPCM = $\{Size_of_SegaPCM}, but you have a $\{SegaPCM.size} byte Sega sound."
                endif
