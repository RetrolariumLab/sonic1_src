VDPSetupGame:
                lea     (vdp_control_port).l,a0         ; load VDP control port
                lea     (vdp_data_port).l,a1            ; load VDP data port
                lea     (VDPSetupArray).l,a2            ; load address of register values
                moveq   #(VDPSetupArray_End-VDPSetupArray)/2-1,d7  ; set repeat times
.setreg:
                move.w  (a2)+,(a0)                      ; save register value to VDP
                dbf     d7,.setreg                      ; repeat until all register values have been sent

                move.w  (VDPSetupArray+2).l,d0          ; get second entry of VDPSetupArray
                move.w  d0,(v_vdp_buffer1).w            ; buffer register $81 (used for enabling/disabling display)

                move.w  #vreg_hintrate|223,(v_hblank_hreg).w  ; HBlank every 224th scanline

                moveq   #cBlack,d0                      ; set d0 to 0 (black)
                move.l  #$C0000000,(vdp_control_port).l  ; set VDP to CRAM write
                move.w  #($80)/2-1,d7                   ; set repeat times to cover full CRAM
.clrCRAM:
                move.w  d0,(a1)                         ; clear colours
                dbf     d7,.clrCRAM                     ; repeat until the entire palette is clear (black)

                clr.l   (v_scrposy_vdp).w               ; clear single vertical scroll buffer
                clr.l   (v_scrposx_vdp).w               ; clear single horizontal scroll buffer
                move.l  d1,-(sp)                        ; store d1 data in the stack for now
                fillVRAM 0,0,$10000                     ; clear the entirety of VRAM
                move.l  (sp)+,d1                        ; reload d1 data back out of the stack
                rts                                     ; return
; End of function VDPSetupGame

; ---------------------------------------------------------------------------
; VDP register settings to use for the game. Do note that a handful of these
; are getting rewritten for every game mode change, though the majority
; will stay at their initial settings defined in this array
; ---------------------------------------------------------------------------
; See here for details on VDP registers:
; https://segaretro.org/Sega_Mega_Drive/VDP_registers
; ---------------------------------------------------------------------------

VDPSetupArray:
                dc.w    vreg_mode1|%000100              ; 8-color mode
                dc.w    vreg_mode2|%00110100            ; vertical interrupts, DMA, Mega Drive display
                dc.w    vreg_fgvram|(vram_fg>>10)       ; foreground nametable address
                dc.w    vreg_winvram|(vram_win>>10)     ; window nametable address
                dc.w    vreg_bgvram|(vram_bg>>13)       ; background nametable address
                dc.w    vreg_spritevram|(vram_sprites>>9)  ; sprite table address
                dc.w    $8600                           ; (unused, only relevant for 128KB VRAM mode)
                dc.w    vreg_bgcolor|0<<4|0             ; background colour (palette line 0, entry 0)
                dc.w    $8800                           ; (unused, only relevant for Master System)
                dc.w    $8900                           ; (unused, only relevant for Master System)
                dc.w    vreg_hintrate|$00               ; horizontal interrupt register
                dc.w    vreg_mode3|%0000                ; full-screen vertical scrolling
                dc.w    vreg_mode4|%10000001            ; 40-cell display mode
                dc.w    vreg_hscrollvram|(vram_hscroll>>10)  ; background H-scroll address
                dc.w    $8E00                           ; (unused, only relevant for 128KB VRAM mode)
                dc.w    vreg_autoinc|2                  ; VDP auto-increment size (2)
                dc.w    vreg_planesize|%000001          ; 64-cell H-scroll size
                dc.w    vreg_winxpos|0                  ; window horizontal position
                dc.w    vreg_winypos|0                  ; window vertical position
VDPSetupArray_End:

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to clear the screen (plane mappings, sprites, and scroll data)
; ---------------------------------------------------------------------------

ClearScreen:
                fillVRAM 0, vram_fg, vram_fg+plane_size_64x32  ; clear foreground namespace
                fillVRAM 0, vram_bg, vram_bg+plane_size_64x32  ; clear background namespace

                if      Revision=0
                move.l  #0,(v_scrposy_vdp).w            ; clear single vertical scroll buffer
                move.l  #0,(v_scrposx_vdp).w            ; clear single horizontal scroll buffer
                else
; REV01 changed this from moving 0 to clears, but functionally identical
                clr.l   (v_scrposy_vdp).w               ; clear single vertical scroll buffer
                clr.l   (v_scrposx_vdp).w               ; clear single horizontal scroll buffer
                endif

; Both of these clear loops clear one more longwords than they should
; This will clear the first 4 bytes of v_palette_water and v_objspace, respectively
                clearRAM v_spritetablebuffer,v_spritetablebuffer_end+4  ; clear sprite table buffer
                clearRAM v_hscrolltablebuffer,v_hscrolltablebuffer_end_padded+4  ; clear H-Scroll table buffer

                rts                                     ; return
; End of function ClearScreen

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to load the DAC driver
; ---------------------------------------------------------------------------

; SoundDriverLoad: <-- old misnomer
