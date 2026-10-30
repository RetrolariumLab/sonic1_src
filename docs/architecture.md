# Engine architecture

The shared preservation entry is `sonic.asm`. The profile wrapper supplies only
`Revision`; engine code is shared by REV00, REV01 and REVXB. Include order is
part of the binary layout. The current imported module names remain visible
until the semantic source-layout stage.

| Subsystem              | Source owners                                                | Responsibility and boundary                                                                                                                                                                                     |
| ---------------------- | ------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Startup and exceptions | `sonic.asm`, `MacroSetup.asm`, `Macros.asm`                  | Vectors, cartridge header, TMSS setup, RAM/VDP initialization, checksum and error handling. The short embedded boot Z80 program is instructions in the startup source.                                          |
| Memory and hardware    | `_Constants.asm`, `_Variables.asm`, `s1.sounddriver.ram.asm` | Hardware aliases, work-RAM allocation, object fields and audio channel state; declarations do not emit opaque executable blobs.                                                                                 |
| Frame scheduling       | `sonic.asm`                                                  | Main mode dispatch, VBlank/HBlank, joypad polling, DMA and frame synchronization.                                                                                                                               |
| Modes and world        | `sonic.asm`, `_inc/`                                         | Sega/title, normal levels and demos, special stages, ending/credits, level loading, scrolling, collision and decompression.                                                                                     |
| Objects and player     | `_incObj/`                                                   | Sonic's state machine, enemies, bosses, collectables, environmental objects and shared object services.                                                                                                         |
| Rendering content      | `_maps/`, `_anim/`, included private data                    | Symbolic mapping/DPLC macros and animation tables accompany object consumers; graphics and compressed map payloads come from the user's ROM.                                                                    |
| Demo input             | `demodata/`                                                  | Assembler tables of controller states and durations used by the original game. These are separate from the verification movies in `scenarios/`.                                                                 |
| Audio                  | `s1.sounddriver.asm`, `sound/z80.asm`, `sound/dac/`          | 68000 SMPS scheduling/FM/PSG commands and Z80 DAC playback. Songs, effects, voices, PSG envelopes and samples are private includes. Register order, frequency and command dispatch tables remain engine source. |

The final part of `sonic.asm` lays out private graphics, collision,
special-stage, level and object payloads before the sound driver. The driver
includes the compressed Z80 program and its private DPCM samples, the private
song/effect streams and the SEGA PCM bank. `p2bin` authentic compression stores
the assembled Z80 program; the executable driver is never replaced by the
extracted container.

`assets/manifest.json` describes direct cartridge slices. The DAC container is
read only to recover sample data; `config/build/derived_assets.json` describes
that transformed address space. Text engine tables retain their imported names
and provenance. Their names are evidence from the community source, rather than
proof of every interpretation; see [unknowns](unknowns.md).

The build applies the ROM-end and checksum fields after flattening. Canonical
identity, symbolic-address checks, a moved-source probe and runtime observations
are independent controls. [Relocation](relocation.md) explains the probe's
branch reach and sample-bank constraints; [runtime](runtime.md) states its
observed paths.
