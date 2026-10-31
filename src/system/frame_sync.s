WaitForVBlank:
                enable_ints                             ; enable interrupts so vertical interrupts can occur

.wait:
                tst.b   (v_vblank_routine).w            ; has VBlank routine finished?
                bne.s   .wait                           ; if not, loop until it has
                rts                                     ; resume normal operation
; End of function WaitForVBlank

; ===========================================================================
; >>> Subroutines for generic calculations
                include "src/system/math.s"

; ===========================================================================
; ---------------------------------------------------------------------------
; Sega screen
; ---------------------------------------------------------------------------

; SegaScreen:
