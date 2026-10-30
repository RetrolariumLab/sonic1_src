WaitForVBlank:
                enable_ints                             ; enable interrupts so vertical interrupts can occur

.wait:
                tst.b   (v_vblank_routine).w            ; has VBlank routine finished?
                bne.s   .wait                           ; if not, loop until it has
                rts                                     ; resume normal operation
; End of function WaitForVBlank

; ===========================================================================
; >>> Subroutines for generic calculations
                include "src/system/math/random.asm"
                include "src/system/math/sine.asm"
                if      Revision=0
                include "src/system/math/square_root.asm"  ; Only in REV00, and even there it was never used
                endif
                include "src/system/math/angle.asm"

; ===========================================================================
; ---------------------------------------------------------------------------
; Sega screen
; ---------------------------------------------------------------------------

; SegaScreen:
