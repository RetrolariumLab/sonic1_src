Art_BigRing:   binclude "artunc/Giant Ring.unc"
Art_BigRing_size:   equ     *-Art_BigRing
                even

; ---------------------------------------------------------------------------

; ObjPos_Index starts at $6B000 in all revisions, which amounts
; to $9C bytes of padding for rev00 and $DC for rev01/rev02
; From a technical standpoint, this padding serves no purpose
                align   $100

; ---------------------------------------------------------------------------
; Sprite locations index
; ---------------------------------------------------------------------------
