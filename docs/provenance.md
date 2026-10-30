# Provenance and rights

## Imported source

The source was imported from Sonic Retro's public
[sonicretro/s1disasm](https://github.com/sonicretro/s1disasm) repository, AS
branch, at commit `89c0e0e06b51fd9ebac44d988e4a89bd643fd031`, dated 2026-10-25.
The reference history contains 1103 commits and 49 distinct public author names.
The first project commit imports a text-only snapshot into a new history; none
of the upstream Git objects, ROMs or binary assets was imported.

Imported labels, comments, engine macros, mappings, animation, demo input and
engine tables retain their community provenance. Their presence does not mean
this project independently verified every semantic name.

## Removed material and restoration boundary

Proprietary binary graphics, compressed maps, level and object layouts,
collision data, palettes, start positions and WAV samples are not redistributed.
Music, sound effects, embedded FM voices and PSG envelopes are also private
content and are extracted from the user's accepted ROM images into the ignored
data root. The small DAC delta table is now an assembler byte declaration next
to its Z80 owner. Generated PCM and DPCM input is reconstructed from ROM bytes.

External editor projects and definitions, fixed community replacement assets,
Lua and batch build scripts, WAV converters and bundled assembler binaries were
removed. This repository describes content; editing belongs in Retrolarium.

The community switches `FixBugs`, `CheatsEnabled`, `AllOptimizations`,
`SkipChecksumCheck`, `ZeroOffsetOptimization`, `PaddingOptimization`,
`UnusedOptimization`, `EnableSRAM`, `BackupSRAM`, `AddressSRAM` and
`FixMusicAndSFXDataBugs` were specialized to preservation behavior and removed.
The optional optimized DAC compressor is also excluded. Only official revision
selection remains. To research or restore these modifications, start from the
upstream commit named above; they are outside the preservation profiles here.

## Licensing status

The imported source has no licence grant: `license_not_granted`. The upstream
README disclaimer is preserved. Sonic Retro claims no ownership or warranty; its
educational-use disclaimer is not a licence to the original game. The game code
and data remain the property of their respective rights holders. Private user
inputs have status `private_user_supplied` and are never tracked. No
project-wide licence is asserted over the reconstructed game source.

Retrolarium Kit and Core are external public dependencies; their versions and
source commits are recorded in `config/toolchain.json`. No dependency source was
modified or bundled as part of this import. Music, sound effects, embedded FM
voice definitions, PSG envelopes and SMPS2ASM content macros are excluded from
the source tree; their private streams are included through extraction records.

## Upstream contributors

All 49 public author names from the imported AS history are listed in
[CONTRIBUTORS.md](../CONTRIBUTORS.md), with their recorded spellings and
aliases. That file is the single owner of the contributor list. Original credits
in source comments remain intact.
