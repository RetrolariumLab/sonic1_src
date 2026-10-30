AddPLC:
                movem.l a1-a2,-(sp)                     ; store register data
                lea     (ArtLoadCues).l,a1              ; load PLC list address
                add.w   d0,d0                           ; double for word-based indexing
                move.w  (a1,d0.w),d0                    ; load correct relative add address
                lea     (a1,d0.w),a1                    ; add and load actual address of list
                lea     (v_plc_buffer).w,a2             ; load PLC process list

.findspace:
                tst.l   (a2)                            ; is this slot taken?
                beq.s   .copytoRAM                      ; if not, branch
                addq.w  #plc_slot_size,a2               ; advance to next slot
                bra.s   .findspace                      ; recheck
; ===========================================================================

.copytoRAM:
                move.w  (a1)+,d0                        ; load size of list
                bmi.s   .return                         ; if there is no list, branch

.loop:
                move.l  (a1)+,(a2)+                     ; copy Nemesis art address
                move.w  (a1)+,(a2)+                     ; copy VRAM location to dump to
                dbf     d0,.loop                        ; repeat for all entries

.return:
                movem.l (sp)+,a1-a2                     ; restore register data
                rts                                     ; return
; End of function AddPLC

; ===========================================================================
; ---------------------------------------------------------------------------
; Identical to AddPLC, but also stops the current PLC process, and loads
; a brand new queue. (The same 16th entry warning as above applies!)
; ---------------------------------------------------------------------------

; LoadPLC2:
NewPLC:
                movem.l a1-a2,-(sp)                     ; store register data
                lea     (ArtLoadCues).l,a1              ; load PLC list address
                add.w   d0,d0                           ; double for word-based indexing
                move.w  (a1,d0.w),d0                    ; load correct relative add address
                lea     (a1,d0.w),a1                    ; add and load actual address of list
                bsr.s   ClearPLC                        ; clear the current PLC entries first
                lea     (v_plc_buffer).w,a2             ; load PLC process list
                move.w  (a1)+,d0                        ; load size of list
                bmi.s   .return                         ; if there is no list, branch

.loop:
                move.l  (a1)+,(a2)+                     ; copy Nemesis art address
                move.w  (a1)+,(a2)+                     ; copy VRAM location to dump to
                dbf     d0,.loop                        ; repeat for all entries

.return:
                movem.l (sp)+,a1-a2                     ; restore register data
                rts                                     ; return
; End of function NewPLC

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to clear the pattern load cues
; Clear the pattern load queue ($FFF680 - $FFF700)
; ---------------------------------------------------------------------------

ClearPLC:
                lea     (v_plc_buffer).w,a2             ; load PLC process list
                moveq   #(v_plc_buffer_end-v_plc_buffer)/4-1,d0  ; set size of list

.loop:
                clr.l   (a2)+                           ; clear PLC process list
                dbf     d0,.loop                        ; repeat until entire list is cleared
                rts                                     ; return
; End of function ClearPLC

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to check the PLC buffer and begin decompression if it contains
; anything. ProcessPLC handles the actual decompression during VBlank
; ---------------------------------------------------------------------------

RunPLC:
                tst.l   (v_plc_buffer).w                ; are there any PLC entries left to process?
                beq.s   .return                         ; if not, branch
                tst.w   (v_plc_patternsleft).w          ; is a section counter already set (is art already being decompressed)?
                bne.s   .return                         ; if so, branch

                movea.l (v_plc_buffer).w,a0             ; load address of first entry's art
                lea     (NemPCD_WriteRowToVDP).l,a3     ; load address of dumping routine to use (VDP variant)
                lea     (v_ngfx_buffer).w,a1            ; load RLE huffman buffer
                move.w  (a0)+,d2                        ; load number of sections to decompress (Each section is $20 bytes)
                bpl.s   .skipXor                        ; if this data doesn't use XOR variant, branch
                adda.w  #NemPCD_WriteRowToVDP_XOR-NemPCD_WriteRowToVDP,a3  ; advance to XOR variant
; loc_160E:
.skipXor:
                andi.w  #$7FFF,d2                       ; clear XOR flag

; Relocated to bugfix below
                move.w  d2,(v_plc_patternsleft).w       ; save section counter
                bsr.w   NemDec_BuildCodeTable           ; decompress the huffman tree RLE table
                move.b  (a0)+,d5                        ; load lookup field
                asl.w   #8,d5                           ; ''
                move.b  (a0)+,d5                        ; ''
                moveq   #$10,d6                         ; prepare bit shift counter (shifting up to a word in size)
                moveq   #0,d0                           ; clear d0
                move.l  a0,(v_plc_buffer).w             ; store current entry address
                move.l  a3,(v_plc_ptrnemcode).w         ; store dumping routine (XOR/Non-XOR)
                move.l  d0,(v_plc_repeatcount).w        ; clear RLE dump counter
                move.l  d0,(v_plc_paletteindex).w       ; clear RLE dump nybble
                move.l  d0,(v_plc_previousrow).w        ; clear previous XOR dump
                move.l  d5,(v_plc_dataword).w           ; store lookup field
                move.l  d6,(v_plc_shiftvalue).w         ; store bit shift counter

.return:
                rts                                     ; return
; End of function RunPLC

; ===========================================================================
; ---------------------------------------------------------------------------
; Subroutine to decompress and dump a specified number of Nemesis-compressed
; PLC tiles from the PLC process list to VRAM. These are called from VBlank,
; probably done to smooth out level loading because of how slow Nemesis is
; (Note: Process"D"PLC is an old misnomer!)
; ---------------------------------------------------------------------------

; sub_1642: ProcessDPLC_9Tiles:
ProcessPLC_9Tiles:
                tst.w   (v_plc_patternsleft).w          ; is a section counter set (is art being decompressed)?
                beq.w   ProcessPLC_Return               ; if not, branch (nothing to decompress)

                move.w  #9,(v_plc_framepatternsleft).w  ; set tile counter to 9 (number of tiles to decompress in a frame)
                moveq   #0,d0                           ; clear d0
                move.w  (v_plc_buffer_dest).w,d0        ; load VRAM address for this frame
                addi.w  #9*tile_size,(v_plc_buffer_dest).w  ; increase address for next frame
                bra.s   ProcessPLC                      ; continue
; ===========================================================================

; sub_165E: ProcessDPLC2: ProcessPLC_3Tiles:
ProcessPLC_3Tiles:
                tst.w   (v_plc_patternsleft).w          ; is a section counter set (is art being decompressed)?
                beq.s   ProcessPLC_Return               ; if not, branch (nothing to decompress)

                move.w  #3,(v_plc_framepatternsleft).w  ; set tile counter to 3 (number of tiles to decompress in a frame)
                moveq   #0,d0                           ; clear d0
                move.w  (v_plc_buffer_dest).w,d0        ; load VRAM address for this frame
                addi.w  #3*tile_size,(v_plc_buffer_dest).w  ; increase address for next frame
; fall-through to ProcessPLC
; ---------------------------------------------------------------------------

; loc_1676: ProcessPLC:
ProcessPLC:
                lea     (vdp_control_port).l,a4         ; load VDP control port address
                lsl.l   #2,d0                           ; get address MSB bits and send to LSB of long-word
                lsr.w   #2,d0                           ; send rest back
                ori.w   #$4000,d0                       ; set mode bits
                swap    d0                              ; align for VDP port
                move.l  d0,(a4)                         ; set VDP address/mode
                subq.w  #4,a4                           ; move a4 down to VDP data port
                movea.l (v_plc_buffer).w,a0             ; load current entry address
                movea.l (v_plc_ptrnemcode).w,a3         ; load dumping routine to use (XOR/Non-XOR)
                move.l  (v_plc_repeatcount).w,d0        ; load RLE dump counter
                move.l  (v_plc_paletteindex).w,d1       ; load RLE dump nybble
                move.l  (v_plc_previousrow).w,d2        ; load previous XOR dump
                move.l  (v_plc_dataword).w,d5           ; load lookup field
                move.l  (v_plc_shiftvalue).w,d6         ; load bit shift counter
                lea     (v_ngfx_buffer).w,a1            ; load RLE huffman buffer

; loc_16AA:
.loop:
                movea.w #8,a5                           ; set size of data to decompress (20 bytes, 1 tile)
                bsr.w   NemPCD_NewRow                   ; continue the decompression
                subq.w  #1,(v_plc_patternsleft).w       ; decrease section count by 1
                beq.s   ProcessPLC_ShiftCue             ; if decompression is finished, branch
                subq.w  #1,(v_plc_framepatternsleft).w  ; decrease tile counter
                bne.s   .loop                           ; if still running, branch to decompress another tile

                move.l  a0,(v_plc_buffer).w             ; store current entry address
                move.l  a3,(v_plc_ptrnemcode).w         ; store dumping routine to use (XOR/Non-XOR)
                move.l  d0,(v_plc_repeatcount).w        ; store RLE dump counter
                move.l  d1,(v_plc_paletteindex).w       ; store RLE dump nybble
                move.l  d2,(v_plc_previousrow).w        ; store previous XOR dump
                move.l  d5,(v_plc_dataword).w           ; store lookup field
                move.l  d6,(v_plc_shiftvalue).w         ; store bit shift counter

ProcessPLC_Return:
                rts                                     ; return
; ===========================================================================

; loc_16DC:
ProcessPLC_ShiftCue:
                lea     (v_plc_buffer).w,a0             ; load PLC process list
                moveq   #(v_plc_buffer_only_end-v_plc_buffer-plc_slot_size)/4-1,d0  ; set size of list

; loc_16E2:
.loop:
                move.l  plc_slot_size(a0),(a0)+         ; shift contents of PLC buffer up 6 bytes
                dbf     d0,.loop                        ; repeat til done

                rts                                     ; return
; End of function ProcessPLC

; ===========================================================================
; ---------------------------------------------------------------------------
; Like AddPLC, but instead of adding entries to a queue to be processed later,
; this will decompress and transfer all entries of the given PLC ID's list
; immediately, blocking until it is done. Does not use or affect the queue
; ---------------------------------------------------------------------------

QuickPLC:
                lea     (ArtLoadCues).l,a1              ; load PLC list address
                add.w   d0,d0                           ; double for word-based indexing
                move.w  (a1,d0.w),d0                    ; load correct relative add address
                lea     (a1,d0.w),a1                    ; add and load actual address of list
                move.w  (a1)+,d1                        ; load size of list

.loop:
                movea.l (a1)+,a0                        ; load Nemesis art address
                moveq   #0,d0                           ; clear d0
                move.w  (a1)+,d0                        ; load VRAM dump address
                lsl.l   #2,d0                           ; get address MSB bits and send to LSB of long-word
                lsr.w   #2,d0                           ; send rest back
                ori.w   #$4000,d0                       ; set mode bits
                swap    d0                              ; align for VDP port
                move.l  d0,(vdp_control_port).l         ; set VDP address/mode
                bsr.w   NemDec                          ; decompress the entire entry
                dbf     d1,.loop                        ; repeat for all entries in the list
                rts                                     ; return
; End of function QuickPLC

; ===========================================================================
; >>> Other decompression algorithms
                include "src/system/compression/Enigma Decompression.asm"
                include "src/system/compression/Kosinski Decompression.asm"

; ===========================================================================
; >>> Palette logic routines
                include "src/rendering/world/PaletteCycle.asm"
                include "src/rendering/world/Palette Fading.asm"  ; includes "PaletteFadeIn", "PaletteFadeOut", "PaletteWhiteIn", and "PaletteWhiteOut"

; ===========================================================================
; ---------------------------------------------------------------------------
; Palette cycling routine - Sega logo
; ---------------------------------------------------------------------------
