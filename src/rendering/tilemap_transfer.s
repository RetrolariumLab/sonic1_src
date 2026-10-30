TilemapToVRAM:
                lea     (vdp_data_port).l,a6            ; load VDP data port address
                move.l  #$800000,d4                     ; prepare plane width size for VDP address advancing (row)

Tilemap_Line:
                move.l  d0,4(a6)                        ; set the VDP the VRAM write mode with address
                move.w  d1,d3                           ; load width of rectangle

Tilemap_Cell:
                move.w  (a1)+,(a6)                      ; copy tile map to VRAM plane space
                dbf     d3,Tilemap_Cell                 ; repeat for the entire width
                add.l   d4,d0                           ; advance VDP value address to the next row
                dbf     d2,Tilemap_Line                 ; repeat for the entire height
                rts                                     ; return
; End of function TilemapToVRAM

; ===========================================================================
; >>> Nemesis decompression algorithm, primarily (but not exclusively) used for PLCs
                include "src/system/compression/nemesis_decompression.s"

; ---------------------------------------------------------------------------
; Subroutine to add entries from a given Pattern Load Cue list ID to the
; PLC decompression queue (decompressed later during VBlank)
; ---------------------------------------------------------------------------
; ARGUMENTS
; d0 = index of PLC list
; ---------------------------------------------------------------------------
; NOTICE: This subroutine does not check for buffer overruns. The programmer
; (or hacker) is responsible for making sure that no more than
; 16 load requests are copied into the buffer
; _________DO NOT PUT MORE THAN 16 LOAD REQUESTS IN A LIST!__________
; (or if you change the size of Plc_Buffer, the limit becomes (Plc_Buffer_Only_End-Plc_Buffer)/plc_slot_size)
; ---------------------------------------------------------------------------

; LoadPLC:
