ObjPos_Index:
; GHZ
                dc.w    ObjPos_GHZ1-ObjPos_Index, ObjPos_Null-ObjPos_Index
                dc.w    ObjPos_GHZ2-ObjPos_Index, ObjPos_Null-ObjPos_Index
                dc.w    ObjPos_GHZ3-ObjPos_Index, ObjPos_Null-ObjPos_Index
                dc.w    ObjPos_GHZ1-ObjPos_Index, ObjPos_Null-ObjPos_Index
; LZ
                dc.w    ObjPos_LZ1-ObjPos_Index, ObjPos_Null-ObjPos_Index
                dc.w    ObjPos_LZ2-ObjPos_Index, ObjPos_Null-ObjPos_Index
                dc.w    ObjPos_LZ3-ObjPos_Index, ObjPos_Null-ObjPos_Index
                dc.w    ObjPos_SBZ3-ObjPos_Index, ObjPos_Null-ObjPos_Index
; MZ
                dc.w    ObjPos_MZ1-ObjPos_Index, ObjPos_Null-ObjPos_Index
                dc.w    ObjPos_MZ2-ObjPos_Index, ObjPos_Null-ObjPos_Index
                dc.w    ObjPos_MZ3-ObjPos_Index, ObjPos_Null-ObjPos_Index
                dc.w    ObjPos_MZ1-ObjPos_Index, ObjPos_Null-ObjPos_Index
; SLZ
                dc.w    ObjPos_SLZ1-ObjPos_Index, ObjPos_Null-ObjPos_Index
                dc.w    ObjPos_SLZ2-ObjPos_Index, ObjPos_Null-ObjPos_Index
                dc.w    ObjPos_SLZ3-ObjPos_Index, ObjPos_Null-ObjPos_Index
                dc.w    ObjPos_SLZ1-ObjPos_Index, ObjPos_Null-ObjPos_Index
; SYZ
                dc.w    ObjPos_SYZ1-ObjPos_Index, ObjPos_Null-ObjPos_Index
                dc.w    ObjPos_SYZ2-ObjPos_Index, ObjPos_Null-ObjPos_Index
                dc.w    ObjPos_SYZ3-ObjPos_Index, ObjPos_Null-ObjPos_Index
                dc.w    ObjPos_SYZ1-ObjPos_Index, ObjPos_Null-ObjPos_Index
; SBZ
                dc.w    ObjPos_SBZ1-ObjPos_Index, ObjPos_Null-ObjPos_Index
                dc.w    ObjPos_SBZ2-ObjPos_Index, ObjPos_Null-ObjPos_Index
                dc.w    ObjPos_FZ-ObjPos_Index, ObjPos_Null-ObjPos_Index
                dc.w    ObjPos_SBZ1-ObjPos_Index, ObjPos_Null-ObjPos_Index
                zonewarning ObjPos_Index,$10
; Ending
                dc.w    ObjPos_End-ObjPos_Index, ObjPos_Null-ObjPos_Index
                dc.w    ObjPos_End-ObjPos_Index, ObjPos_Null-ObjPos_Index
                dc.w    ObjPos_End-ObjPos_Index, ObjPos_Null-ObjPos_Index
                dc.w    ObjPos_End-ObjPos_Index, ObjPos_Null-ObjPos_Index
; --- Put extra object data here. ---
ObjPosLZPlatform_Index:
                dc.w    ObjPos_LZ1pf1-ObjPos_Index, ObjPos_LZ1pf2-ObjPos_Index
                dc.w    ObjPos_LZ2pf1-ObjPos_Index, ObjPos_LZ2pf2-ObjPos_Index
                dc.w    ObjPos_LZ3pf1-ObjPos_Index, ObjPos_LZ3pf2-ObjPos_Index
                dc.w    ObjPos_LZ1pf1-ObjPos_Index, ObjPos_LZ1pf2-ObjPos_Index
ObjPosSBZPlatform_Index:
                dc.w    ObjPos_SBZ1pf1-ObjPos_Index, ObjPos_SBZ1pf2-ObjPos_Index
                dc.w    ObjPos_SBZ1pf3-ObjPos_Index, ObjPos_SBZ1pf4-ObjPos_Index
                dc.w    ObjPos_SBZ1pf5-ObjPos_Index, ObjPos_SBZ1pf6-ObjPos_Index
                dc.w    ObjPos_SBZ1pf1-ObjPos_Index, ObjPos_SBZ1pf2-ObjPos_Index
                dc.b    $FF, $FF, 0, 0, 0, 0

ObjPos_GHZ1:   binclude "objpos/ghz1.bin"
                even
ObjPos_GHZ2:   binclude "objpos/ghz2.bin"
                even
ObjPos_GHZ3:
                if      Revision=0
                binclude "objpos/ghz3 (REV00).bin"
                even
                else
                binclude "objpos/ghz3 (REV01).bin"
                even
                endif

ObjPos_LZ1:
                if      Revision=0
                binclude "objpos/lz1 (REV00).bin"
                even
                else
                binclude "objpos/lz1 (REV01).bin"
                even
                endif
ObjPos_LZ2:   binclude "objpos/lz2.bin"
                even
ObjPos_LZ3:
                if      Revision=0
                binclude "objpos/lz3 (REV00).bin"
                even
                else
                binclude "objpos/lz3 (REV01).bin"
                even
                endif
ObjPos_SBZ3:   binclude "objpos/sbz3.bin"
                even

ObjPos_LZ1pf1:   binclude "objpos/platforms/lz1pf1.bin"
                even
ObjPos_LZ1pf2:   binclude "objpos/platforms/lz1pf2.bin"
                even
ObjPos_LZ2pf1:   binclude "objpos/platforms/lz2pf1.bin"
                even
ObjPos_LZ2pf2:   binclude "objpos/platforms/lz2pf2.bin"
                even
ObjPos_LZ3pf1:   binclude "objpos/platforms/lz3pf1.bin"
                even
ObjPos_LZ3pf2:   binclude "objpos/platforms/lz3pf2.bin"
                even

ObjPos_MZ1:
                if      Revision=0
                binclude "objpos/mz1 (REV00).bin"
                even
                else
                binclude "objpos/mz1 (REV01).bin"
                even
                endif
ObjPos_MZ2:   binclude "objpos/mz2.bin"
                even
ObjPos_MZ3:   binclude "objpos/mz3.bin"
                even

ObjPos_SLZ1:   binclude "objpos/slz1.bin"
                even
ObjPos_SLZ2:   binclude "objpos/slz2.bin"
                even
ObjPos_SLZ3:   binclude "objpos/slz3.bin"
                even
ObjPos_SYZ1:   binclude "objpos/syz1.bin"
                even
ObjPos_SYZ2:   binclude "objpos/syz2.bin"
                even
ObjPos_SYZ3:
                if      Revision=0
                binclude "objpos/syz3 (REV00).bin"
                even
                else
                binclude "objpos/syz3 (REV01).bin"
                even
                endif

ObjPos_SBZ1:
                if      Revision=0
                binclude "objpos/sbz1 (REV00).bin"
                even
                else
                binclude "objpos/sbz1 (REV01).bin"
                even
                endif
ObjPos_SBZ2:   binclude "objpos/sbz2.bin"
                even
ObjPos_FZ:   binclude "objpos/fz.bin"
                even

ObjPos_SBZ1pf1:   binclude "objpos/platforms/sbz1pf1.bin"
                even
ObjPos_SBZ1pf2:   binclude "objpos/platforms/sbz1pf2.bin"
                even
ObjPos_SBZ1pf3:   binclude "objpos/platforms/sbz1pf3.bin"
                even
ObjPos_SBZ1pf4:   binclude "objpos/platforms/sbz1pf4.bin"
                even
ObjPos_SBZ1pf5:   binclude "objpos/platforms/sbz1pf5.bin"
                even
ObjPos_SBZ1pf6:   binclude "objpos/platforms/sbz1pf6.bin"
                even

ObjPos_End:   binclude "objpos/ending.bin"
                even

ObjPos_Null:   dc.b    $FF, $FF, 0, 0, 0, 0
