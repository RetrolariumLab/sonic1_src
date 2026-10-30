; =========================================================================
; |           Sonic the Hedgehog Disassembly for Sega Mega Drive            |
; =========================================================================
;
; Disassembly created by Hivebrain
; thanks to drx, Stealth and Esrael L.G. Neto
; ---------------------------------------------------------------------------
; NOTE:
; Set your editor's tab width to 8 characters wide for viewing this file

; ===========================================================================
; Preservation revision is supplied by config/revision_profiles.json

ZoneCount   =       6
; | Used for the "zonewarning" macro. Do not change, unless more zones get added
; | Discrete zones are: GHZ, LZ, MZ, SLZ, SYZ, and SBZ

; ===========================================================================
; AS-specific macros and assembler settings
                cpu     68000
                include "src/system/assembler.inc"

; ===========================================================================
; Simplifying macros and functions
                include "src/system/macros.inc"

; ===========================================================================
; Equates section - Names for constants
                include "src/memory/constants.inc"

; ===========================================================================
; Equates section - Names for variables
                include "src/memory/ram.inc"

; ===========================================================================
; Expressing sprite mappings and DPLCs in a portable and human-readable form
SonicMappingsVer   =       1
SonicDplcVer   =       1
                include "src/rendering/mappings/map_macros.inc"

; ===========================================================================
; start of ROM
