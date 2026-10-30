SS_1:   binclude "sslayout/1.eni"
                even
SS_2:   binclude "sslayout/2.eni"
                even
SS_3:   binclude "sslayout/3.eni"
                even
SS_4:   binclude "sslayout/4.eni"
                even
                if      Revision=0
SS_5:   binclude "sslayout/5 (REV00).eni"
                even
SS_6:   binclude "sslayout/6 (REV00).eni"
                even
                else
; SS 5 and 6 had broken objects outside the accessible layout;
; REV01 removes those - remaining layouts stay unchanged
SS_5:   binclude "sslayout/5 (REV01).eni"
                even
SS_6:   binclude "sslayout/6 (REV01).eni"
                even
                endif

; ---------------------------------------------------------------------------
; Animated uncompressed graphics
; ---------------------------------------------------------------------------
