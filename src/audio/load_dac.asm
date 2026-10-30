DACDriverLoad:
                nop                                     ; delay
                stopZ80                                 ; request Z80 stop on
                deassertZ80Reset                        ; request Z80 reset off
                lea     (DACDriver).l,a0                ; load compressed DAC driver address as source
                lea     (z80_ram).l,a1                  ; set Z80 RAM address as target
                bsr.w   KosDec                          ; decompress the DAC driver into Z80 RAM
                assertZ80Reset                          ; request Z80 reset on
                nop                                     ; delay (while the Z80 resets)
                nop                                     ; ''
                nop                                     ; ''
                nop                                     ; ''
                deassertZ80Reset                        ; request Z80 reset off
                startZ80                                ; request Z80 stop off
                rts                                     ; return
; End of function DACDriverLoad

; ===========================================================================
; >>> Subroutines to queue sound commands to be executed by the sound driver during VBlank
; includes QueueSound1, QueueSound2, QueueSound3
; (formerly called PlaySound, PlaySound_Special, PlaySound_Unknown)
                include "src/game/world/Queue Sound Routines.asm"

; ===========================================================================
; >>> Subroutine to allow pausing the game
                include "src/game/world/PauseGame.asm"

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to copy a tile map from RAM to VRAM namespace

; input:
; a1 = tile map address
; d0 = VRAM address
; d1 = width (cells)
; d2 = height (cells)
; ---------------------------------------------------------------------------
