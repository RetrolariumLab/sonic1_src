# Engine architecture

`src/main.asm` records cartridge include order. The generated profile wrapper
supplies only manifest-owned `Revision`; all accepted images share one engine.
Directory boundaries follow consumers and state ownership, while include order
preserves original byte layout. [Source layout](source_layout.md) explains the
exclusive per-profile range registry and documented size exceptions.

| Subsystem           | Owners                                                        | Responsibility                                                                                                                        |
| ------------------- | ------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| System and hardware | `src/system/`, `src/memory/`                                  | Vectors/header, startup/TMSS, exceptions, interrupts, controller polling, frame synchronization, hardware aliases and RAM interfaces. |
| World               | `src/game/world/`, `src/game/collision/`, `src/game/physics/` | Level lifetime/loading, camera and zone events, collision scans and object motion.                                                    |
| Player and objects  | `src/game/player/`, `src/game/objects/`                       | Sonic state/movement/animation and the enemy, boss, item and environmental object families.                                           |
| Special stage       | `src/game/special_stage/`                                     | Rotating-grid mode, player control, collision and private stage layouts.                                                              |
| Rendering           | `src/rendering/`                                              | VDP setup/transfers, pattern queues, palette operations, sprite lists, mapping/DPLC and animation content.                            |
| Screens             | `src/ui/`                                                     | Sega/title, level select, continue, HUD, ending, credits and result-screen flow and objects.                                          |
| Audio               | `src/audio/`                                                  | 68000 scheduler/FM/PSG commands, shared channel RAM, Z80 DAC playback and private resource includes.                                  |
| Demo content        | `src/game/demos/`                                             | Original controller-state/duration tables, distinct from verification movies in `scenarios/`.                                         |

Data includes live beside their owning subsystem. Private art and tilemaps are
indexed by rendering, world/layout and object placement data by game modules,
and songs/effects/envelopes/samples by audio. Compiled mapping and animation
families retain their original global names. Code/data boundaries do not depend
on a filename extension alone.

ROM and decoded Z80 addresses are distinct. The executable DAC program remains
assembler source, including its engine-owned DPCM delta table. Its samples are
private decoded subranges. Pinned p2bin compression stores the assembled driver;
the extracted original compressed container is used only to recover samples. The
short boot Z80 program embedded in startup is also source instructions.

`assets/manifest.json` owns direct cartridge extraction and hashes.
`config/build/derived_assets.json` owns decoded sample ranges.
`config/reconstruction/source_layout.json` owns source regions.
`config/authoring/data_formats.json` binds content views to those authorities
without becoming a second extraction-offset ledger. The title-card mapping
family has an explicit shared child view; source ranges remain exclusive.

The build updates ROM-end and checksum fields after flattening. Byte identity,
source ownership, symbolic pointers, relocated probes, bounded content encoding
and original-input runtime observations are independent controls. See
[relocation](relocation.md), [data formats](data_formats.md) and
[runtime](runtime.md) for their actual guarantees. Imported semantic names and
unobserved gameplay remain in [unknowns](unknowns.md).
