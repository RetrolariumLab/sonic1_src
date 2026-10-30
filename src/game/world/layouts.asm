Level_Index:
; GHZ
                dc.w    Level_GHZ1-Level_Index, Level_GHZbg-Level_Index, Level_GHZ1Unk-Level_Index
                dc.w    Level_GHZ2-Level_Index, Level_GHZbg-Level_Index, Level_GHZ2Unk-Level_Index
                dc.w    Level_GHZ3-Level_Index, Level_GHZbg-Level_Index, Level_GHZ3Unk-Level_Index
                dc.w    Level_GHZ4Unk-Level_Index, Level_GHZ4Unk-Level_Index, Level_GHZ4Unk-Level_Index
; LZ
                dc.w    Level_LZ1-Level_Index, Level_LZbg-Level_Index, Level_LZ1Unk-Level_Index
                dc.w    Level_LZ2-Level_Index, Level_LZbg-Level_Index, Level_LZ2Unk-Level_Index
                dc.w    Level_LZ3-Level_Index, Level_LZbg-Level_Index, Level_LZ3Unk-Level_Index
                dc.w    Level_SBZ3-Level_Index, Level_LZbg-Level_Index, Level_SBZ3Unk-Level_Index
; MZ
                dc.w    Level_MZ1-Level_Index, Level_MZ1bg-Level_Index, Level_MZ1-Level_Index
                dc.w    Level_MZ2-Level_Index, Level_MZ2bg-Level_Index, Level_MZ2Unk-Level_Index
                dc.w    Level_MZ3-Level_Index, Level_MZ3bg-Level_Index, Level_MZ3Unk-Level_Index
                dc.w    Level_MZ4Unk-Level_Index, Level_MZ4Unk-Level_Index, Level_MZ4Unk-Level_Index
; SLZ
                dc.w    Level_SLZ1-Level_Index, Level_SLZbg-Level_Index, Level_SLZ1Unk-Level_Index
                dc.w    Level_SLZ2-Level_Index, Level_SLZbg-Level_Index, Level_SLZ1Unk-Level_Index
                dc.w    Level_SLZ3-Level_Index, Level_SLZbg-Level_Index, Level_SLZ1Unk-Level_Index
                dc.w    Level_SLZ1Unk-Level_Index, Level_SLZ1Unk-Level_Index, Level_SLZ1Unk-Level_Index
; SYZ
                dc.w    Level_SYZ1-Level_Index, Level_SYZbg-Level_Index, Level_SYZ1Unk-Level_Index
                dc.w    Level_SYZ2-Level_Index, Level_SYZbg-Level_Index, Level_SYZ2Unk-Level_Index
                dc.w    Level_SYZ3-Level_Index, Level_SYZbg-Level_Index, Level_SYZ3Unk-Level_Index
                dc.w    Level_SYZ4Unk-Level_Index, Level_SYZ4Unk-Level_Index, Level_SYZ4Unk-Level_Index
; SBZ
                dc.w    Level_SBZ1-Level_Index, Level_SBZ1bg-Level_Index, Level_SBZ1bg-Level_Index
                dc.w    Level_SBZ2-Level_Index, Level_SBZ2bg-Level_Index, Level_SBZ2bg-Level_Index
                dc.w    Level_SBZ2-Level_Index, Level_SBZ2bg-Level_Index, Level_SBZ2Unk-Level_Index
                dc.w    Level_SBZ4Unk-Level_Index, Level_SBZ4Unk-Level_Index, Level_SBZ4Unk-Level_Index
                zonewarning Level_Index,24
; Ending
                dc.w    Level_End-Level_Index, Level_GHZbg-Level_Index, Level_EndUnk-Level_Index
                dc.w    Level_End-Level_Index, Level_GHZbg-Level_Index, Level_EndUnk-Level_Index
                dc.w    Level_EndUnk-Level_Index, Level_EndUnk-Level_Index, Level_EndUnk-Level_Index
                dc.w    Level_EndUnk-Level_Index, Level_EndUnk-Level_Index, Level_EndUnk-Level_Index

Level_GHZ1:   binclude "levels/ghz1.bin"
                even
Level_GHZ1Unk:   dc.l    0
Level_GHZ2:   binclude "levels/ghz2.bin"
                even
Level_GHZ2Unk:   dc.l    0
Level_GHZ3:   binclude "levels/ghz3.bin"
                even
Level_GHZbg:   binclude "levels/ghzbg.bin"
                even
Level_GHZ3Unk:   dc.l    0
Level_GHZ4Unk:   dc.l    0

Level_LZ1:   binclude "levels/lz1.bin"
                even
Level_LZbg:   binclude "levels/lzbg.bin"
                even
Level_LZ1Unk:   dc.l    0
Level_LZ2:   binclude "levels/lz2.bin"
                even
Level_LZ2Unk:   dc.l    0
Level_LZ3:   binclude "levels/lz3.bin"
                even
Level_LZ3Unk:   dc.l    0
Level_SBZ3:   binclude "levels/sbz3.bin"
                even
Level_SBZ3Unk:   dc.l    0

Level_MZ1:   binclude "levels/mz1.bin"
                even
Level_MZ1bg:   binclude "levels/mz1bg.bin"
                even
Level_MZ2:   binclude "levels/mz2.bin"
                even
Level_MZ2bg:   binclude "levels/mz2bg.bin"
                even
Level_MZ2Unk:   dc.l    0
Level_MZ3:   binclude "levels/mz3.bin"
                even
Level_MZ3bg:   binclude "levels/mz3bg.bin"
                even
Level_MZ3Unk:   dc.l    0
Level_MZ4Unk:   dc.l    0

Level_SLZ1:   binclude "levels/slz1.bin"
                even
Level_SLZbg:   binclude "levels/slzbg.bin"
                even
Level_SLZ2:   binclude "levels/slz2.bin"
                even
Level_SLZ3:   binclude "levels/slz3.bin"
                even
Level_SLZ1Unk:   dc.l    0

Level_SYZ1:   binclude "levels/syz1.bin"
                even
Level_SYZbg:
                if      Revision=0
                binclude "levels/syzbg (REV00).bin"
                else
                binclude "levels/syzbg (REV01).bin"
                endif
                even
Level_SYZ1Unk:   dc.l    0
Level_SYZ2:   binclude "levels/syz2.bin"
                even
Level_SYZ2Unk:   dc.l    0
Level_SYZ3:   binclude "levels/syz3.bin"
                even
Level_SYZ3Unk:   dc.l    0
Level_SYZ4Unk:   dc.l    0

Level_SBZ1:   binclude "levels/sbz1.bin"
                even
Level_SBZ1bg:   binclude "levels/sbz1bg.bin"
                even
Level_SBZ2:   binclude "levels/sbz2.bin"
                even
Level_SBZ2bg:   binclude "levels/sbz2bg.bin"
                even
Level_SBZ2Unk:   dc.l    0
Level_SBZ4Unk:   dc.l    0
Level_End:   binclude "levels/ending.bin"
                even
Level_EndUnk:   dc.l    0

; ---------------------------------------------------------------------------
; Uncompressed graphics - Giant Rings
; ---------------------------------------------------------------------------
