ErrorTrap:
                nop                                     ; no operation
                nop                                     ; ''
                bra.s   ErrorTrap                       ; loop forever
; ===========================================================================

; ---------------------------------------------------------------------------
; Entry point for the game on boot or soft-reset
; (This section from a standard Mega Drive devkit library)
; ---------------------------------------------------------------------------

EntryPoint:
                tst.l   (port_1_control_hi).l           ; test port A & B control registers
                bne.s   PortA_Ok                        ; if either of them are already initialized, branch
                tst.w   (expansion_control_hi).l        ; test port C control register
PortA_Ok:   bne.s   SkipSetup                   ; if any port was already initialized, skip the VDP and Z80 setup code (this is a soft-reset)

                lea     SetupValues(pc),a5              ; load setup values array address
                movem.w (a5)+,d5-d7                     ; d5 = VDP register start number; d6 = size of RAM/4; d7 = VDP register diff
                movem.l (a5)+,a0-a4                     ; a0 = start of Z80 RAM; a1 = Z80 bus request; a2 = Z80 reset; a3 = VDP data; a4 = VDP control

                move.b  -$10FF(a1),d0                   ; get hardware version (from $A10001)
                andi.b  #$F,d0                          ; only look at Mega Drive version
                beq.s   SkipSecurity                    ; if the console has no TMSS, skip the security stuff
                move.l  #'SEGA',$2F00(a1)               ; write "SEGA" to TMSS security register ($A14000)

SkipSecurity:
                move.w  (a4),d0                         ; clear write-pending flag in VDP (prevents issues if 68k was reset while writing a command to VDP)
                moveq   #0,d0                           ; clear d0
                movea.l d0,a6                           ; clear a6
                move.l  a6,usp                          ; set usp to $0

                moveq   #SetupValues_VDP_End-SetupValues_VDP-1,d1  ; write to all VDP registers
VDPInitLoop:   move.b  (a5)+,d5                    ; add $8000 to value
                move.w  d5,(a4)                         ; write value to VDP register
                add.w   d7,d5                           ; next register
                dbf     d1,VDPInitLoop                  ; loop until all registers are set up

                move.l  (a5)+,(a4)                      ; write DMA destination to VDP (VRAM 0000)
                move.w  d0,(a3)                         ; set DMA fill value to 00 (DMA starts here, clears entire VRAM)

                move.w  d7,(a1)                         ; stop the Z80
                move.w  d7,(a2)                         ; reset the Z80
WaitForZ80:   btst    d0,(a1)                     ; has the Z80 stopped?
                bne.s   WaitForZ80                      ; if not, loop until it has

                moveq   #SetupValues_Z80_End-SetupValues_Z80-1,d2  ; write all Z80 boot code
Z80InitLoop:   move.b  (a5)+,(a0)+                 ; write boot code to Z80 RAM
                dbf     d2,Z80InitLoop                  ; loop until all boot code has been written

                move.w  d0,(a2)                         ; set Z80 reset on
                move.w  d0,(a1)                         ; set Z80 stop off
                move.w  d7,(a2)                         ; set Z80 reset off

ClrRAMLoop:   move.l  d0,-(a6)                    ; clear 4 bytes of RAM
                dbf     d6,ClrRAMLoop                   ; repeat until the entire RAM is cleared

                move.l  (a5)+,(a4)                      ; set VDP display mode and increment mode

                move.l  (a5)+,(a4)                      ; set VDP to CRAM write
                moveq   #(v_palette_end-v_palette)/4-1,d3  ; set repeat times to cover full CRAM
ClrCRAMLoop:   move.l  d0,(a3)                     ; clear 2 colors
                dbf     d3,ClrCRAMLoop                  ; repeat until the entire CRAM is clear

                move.l  (a5)+,(a4)                      ; set VDP to VSRAM write
                moveq   #$14-1,d4
ClrVSRAMLoop:   move.l  d0,(a3)                     ; clear 4 bytes of VSRAM
                dbf     d4,ClrVSRAMLoop                 ; repeat until the entire VSRAM is clear

                moveq   #SetupValues_PSG_End-SetupValues_PSG-1,d5  ; write to all PSG registers
PSGInitLoop:   move.b  (a5)+,$11(a3)               ; write PSG volume values to PSG port ($C00011)
                dbf     d5,PSGInitLoop                  ; repeat for all channels

                move.w  d0,(a2)                         ; set Z80 reset on
                movem.l (a6),d0-a6                      ; clear all registers
                disable_ints                            ; disable interrupts

SkipSetup:
                bra.s   GameProgram                     ; begin actual game
; ===========================================================================

SetupValues:   dc.w    vreg_mode1                  ; VDP register start number
                dc.w    (v_ram_end-v_ram_start_def/4)-1  ; size of RAM/4 ($3FFF)
                dc.w    $100                            ; VDP register diff

                dc.l    z80_ram                         ; start of Z80 RAM
                dc.l    z80_bus_request                 ; Z80 bus request
                dc.l    z80_reset                       ; Z80 reset
                dc.l    vdp_data_port                   ; VDP data
                dc.l    vdp_control_port                ; VDP control

                SetupValues_VDP:
; Note that most of these are immediately overwritten again in VDPSetupArray
                dc.b    %000100                         ; VDP $80 - 8-colour mode
                dc.b    %00010100                       ; VDP $81 - Mega Drive mode, DMA enable
                dc.b    ($C000>>10)                     ; VDP $82 - foreground nametable address
                dc.b    ($F000>>10)                     ; VDP $83 - window nametable address
                dc.b    ($E000>>13)                     ; VDP $84 - background nametable address
                dc.b    ($D800>>9)                      ; VDP $85 - sprite table address
                dc.b    0                               ; VDP $86 - unused
                dc.b    0<<4|0                          ; VDP $87 - background colour
                dc.b    0                               ; VDP $88 - unused
                dc.b    0                               ; VDP $89 - unused
                dc.b    255                             ; VDP $8A - HBlank register
                dc.b    %0000                           ; VDP $8B - full screen scroll
                dc.b    %10000001                       ; VDP $8C - 40 cell display
                dc.b    ($DC00>>10)                     ; VDP $8D - h-scroll table address
                dc.b    0                               ; VDP $8E - unused
                dc.b    1                               ; VDP $8F - VDP increment
                dc.b    %000001                         ; VDP $90 - 64 cell h-scroll size
                dc.b    0                               ; VDP $91 - window h position
                dc.b    0                               ; VDP $92 - window v position
                dc.w    $FFFF                           ; VDP $93/94 - DMA length
                dc.w    $0000                           ; VDP $95/96 - DMA source
                dc.b    $80                             ; VDP $97 - DMA fill VRAM
                SetupValues_VDP_End:
                dc.l    $40000080                       ; DMA fill destination (VRAM 0000)

                SetupValues_Z80:
; Z80 instructions (not the sound driver; that gets loaded later)
                save
                CPU     Z80                             ; start assembling Z80 code
                phase   0                               ; pretend we're at address 0

                xor     a                               ; clear a to 0
                ld      bc,((z80_ram_end-z80_ram)-zStartupCodeEndLoc)-1  ; prepare to loop this many times
                ld      de,zStartupCodeEndLoc+1         ; initial destination address
                ld      hl,zStartupCodeEndLoc           ; initial source address
                ld      sp,hl                           ; set the address the stack starts at
                ld      (hl),a                          ; set first byte of the stack to 0
                ldir                                    ; loop to fill the stack (entire remaining available Z80 RAM) with 0
                pop     ix                              ; clear ix
                pop     iy                              ; clear iy
                ld      i,a                             ; clear i
                ld      r,a                             ; clear r
                pop     de                              ; clear de
                pop     hl                              ; clear hl
                pop     af                              ; clear af
                ex      af,af'                          ; swap af with af'
                exx                                     ; swap bc/de/hl with their shadow registers too
                pop     bc                              ; clear bc
                pop     de                              ; clear de
                pop     hl                              ; clear hl
                pop     af                              ; clear af
                ld      sp,hl                           ; clear sp
                di                                      ; clear iff1 (for interrupt handler)
                im      1                               ; interrupt handling mode = 1
                ld      (hl),0E9h                       ; replace the first instruction with a jump to itself
                jp      (hl)                            ; jump to the first instruction (to stay there forever)
                zStartupCodeEndLoc:
                dephase                                 ; stop pretending
                restore
                padding off                             ; unfortunately our flags got reset so we have to set them again
                SetupValues_Z80_End:

                dc.w    vreg_mode2|%00000100            ; VDP display mode
                dc.w    vreg_autoinc|2                  ; VDP increment
                dc.l    $C0000000                       ; CRAM write mode
                dc.l    $40000010                       ; VSRAM address 0

                SetupValues_PSG:
                dc.b    $9F, $BF, $DF, $FF              ; values for PSG channel volumes
                SetupValues_PSG_End:
; End of SetupValues

; ===========================================================================
; ---------------------------------------------------------------------------
; Proper game entry point for Sonic the Hedgehog after initialization
; ---------------------------------------------------------------------------

GameProgram:
                tst.w   (vdp_control_port).l            ; clear write-pending flag in VDP (prevents issues if 68k was reset while writing a command to VDP)
                btst    #6,(expansion_control).l        ; has port C been initialized?
                beq.s   CheckSumCheck                   ; if not, branch
                cmpi.l  #'init',(v_init).w              ; has checksum routine already run?
                beq.w   GameInit                        ; if yes, branch

CheckSumCheck:
                movea.l #EndOfHeader,a0                 ; start checking bytes after the header ($200)
                movea.l #RomEndLoc,a1                   ; stop at end of ROM
                move.l  (a1),d0                         ; retrieve long of ROM end
                moveq   #0,d1                           ; clear d1
                .loop:  add.w (a0)+,d1                  ; add next byte value of ROM word
                cmp.l   a0,d0                           ; has iterator reached end of ROM?
                bhs.s   .loop                           ; if not, loop until so

                movea.l #Checksum,a1                    ; read the checksum
                cmp.w   (a1),d1                         ; compare calculated value with checksum in ROM header
                bne.w   CheckSumError                   ; if they don't match, a checksum error has occurred

CheckSumOk:
                lea     (v_crossresetram).w,a6          ; load cross-reset RAM location
                moveq   #0,d7                           ; overwrite with 0
                move.w  #(v_ram_end-v_crossresetram)/4-1,d6  ; write to all of cross-reset RAM ($FE00-$FFFF)
.clearRAM:   move.l  d7,(a6)+                    ; clear RAM
                dbf     d6,.clearRAM                    ; loop until done

                move.b  (console_version).l,d0          ; get hardware information from console
                andi.b  #%11000000,d0                   ; filter to only overseas flag and PAL flag
                move.b  d0,(v_megadrive).w              ; store region settings

                move.l  #'init',(v_init).w              ; set flag so checksum won't run again

GameInit:
                lea     (v_ram_start).l,a6              ; load start location of RAM
                moveq   #0,d7                           ; overwrite with 0
                move.w  #(v_crossresetram-v_ram_start_def)/4-1,d6  ; write to all of RAM except cross-reset RAM ($0000-$FDFF)
.clearRAM:   move.l  d7,(a6)+                    ; clear RAM
                dbf     d6,.clearRAM                    ; loop until done

                bsr.w   VDPSetupGame                    ; initialize (proper) VDP registers
                bsr.w   DACDriverLoad                   ; initialize Z80 DAC driver
                bsr.w   JoypadInit                      ; initialize controller ports
                move.b  #id_Sega,(v_gamemode).w         ; set first Game Mode to Sega Screen

MainGameLoop:
                move.b  (v_gamemode).w,d0               ; load Game Mode
                andi.w  #$1C,d0                         ; limit Game Mode value to $1C max (change to a maximum of 7C to add more game modes)
                jsr     GameModeArray(pc,d0.w)          ; jump to apt location in ROM
                bra.s   MainGameLoop                    ; loop indefinitely

; ---------------------------------------------------------------------------
; Main game mode array
; ---------------------------------------------------------------------------

GameModeArray:

gmptr:   macro   gamemode,{INTLABEL}
__LABEL__:   label   *-GameModeArray
                    bra.w   gamemode
                endm

id_Sega:   gmptr   GM_Sega                     ; Sega Screen ($00)
id_Title:   gmptr   GM_Title                    ; Title Screen ($04)
id_Demo:   gmptr   GM_Level                    ; Demo Mode ($08)
id_Level:   gmptr   GM_Level                    ; Normal Level ($0C)
id_Special:   gmptr   GM_Special                  ; Special Stage ($10)
id_Continue:   gmptr   GM_Continue                 ; Continue Screen ($14)
id_Ending:   gmptr   GM_Ending                   ; End of game sequence ($18)
id_Credits:   gmptr   GM_Credits                  ; Credits ($1C)

                rts                                     ; redundant rts

; ===========================================================================
; ---------------------------------------------------------------------------
; Error handler
; ---------------------------------------------------------------------------
