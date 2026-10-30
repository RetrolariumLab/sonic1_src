; AngleMap starts at $62900 in all revisions, which amounts
; to $104 bytes of padding for rev00 and $40 for rev01/rev02
; From a technical standpoint, this padding serves no purpose
                if      Revision=0
                dcb.b   $104,$FF
                else
                dcb.b   $40,$FF
                endif

; ---------------------------------------------------------------------------
; Collision data
; ---------------------------------------------------------------------------
AngleMap:   binclude "collide/Angle Map.bin"
                even
CollArray1:   binclude "collide/Collision Array (Normal).bin"
                even
CollArray2:   binclude "collide/Collision Array (Rotated).bin"
                even
Col_GHZ:   binclude "collide/GHZ.bin"          ; GHZ index
                even
Col_LZ:   binclude "collide/LZ.bin"           ; LZ index
                even
Col_MZ:   binclude "collide/MZ.bin"           ; MZ index
                even
Col_SLZ:   binclude "collide/SLZ.bin"          ; SLZ index
                even
Col_SYZ:   binclude "collide/SYZ.bin"          ; SYZ index
                even
Col_SBZ:   binclude "collide/SBZ.bin"          ; SBZ index
                even

; ---------------------------------------------------------------------------
; Special Stage layouts
; ---------------------------------------------------------------------------
