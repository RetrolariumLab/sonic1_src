# Source ownership and include order

The canonical entry is `src/main.s`. It shows preservation include order and
delegates implementations to semantic owners. A generated wrapper supplies
revision defines; profiles do not copy the engine.

`config/reconstruction/source_layout.json` is the range authority. Each record
names a path, responsibility, source provenance, content kind, profile ranges
and any size exception. A module that only defines constants/macros has no ROM
bytes; a structural include index owns only its own emitted intervals. Child
include intervals are subtracted before checking that every byte has one owner.

ROM addresses and Z80 addresses are separate domains. The assembled DAC module
owns decoded Z80 code, while its samples have decoded subranges. Its Kosinski
carrier occupies a declared ROM span with explicit transport padding. Bootstrap
Z80 instructions embedded in startup have their own secondary-CPU interpretation
inside the startup ROM range. They are instructions, not an opaque imported
blob.

| Area                      | Responsibility                                                                                                       |
| ------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| `src/system/`             | Startup, exception/interrupt flow, controller and frame synchronization, assembler support and compression routines. |
| `src/memory/`             | Hardware aliases, shared constants and work-RAM allocation.                                                          |
| `src/game/player/`        | Player dispatch, ground/air/rolling movement, slopes, collision response, hurt/death and animation/loading.          |
| `src/game/world/`         | Level lifetime, loading, layout indices and zone-event control.                                                      |
| `src/game/objects/`       | Enemies, bosses, items, environment and shared object services.                                                      |
| `src/game/special_stage/` | Rotating-grid mode, player movement/collision and layout ownership.                                                  |
| `src/rendering/`          | VDP work, pattern queues, palettes, world drawing, mapping and animation data.                                       |
| `src/audio/`              | 68000 scheduling/channel/command logic, Z80 playback, RAM interfaces and private resource includes.                  |
| `src/ui/`                 | Sega/title, level select, continue, ending, credits and result-screen flow.                                          |

The semantic layout retains every instruction, table, conditional and emitted
byte. File boundaries fall at complete global procedures or balanced include
regions. Mechanical path changes are separate from behavior changes. The
registry's 431 source records cover the complete ROM and decoded Z80 spaces in
all three profiles; production acceptance must recompute that evidence.

The 68000 sound driver is split into scheduling, track playback, sound queue,
track initialization, transitions, FM register writes, PSG playback,
coordination commands/voices, transport commands and resources. The player is
split along state, movement, landing and animation responsibilities. Large
final/Star Light bosses and REV01 drawing code are also split at their actual
subsystem boundary.

Six retained files exceed 700 lines: the compile-time constant ledger, REV01
parallax renderer, zone-event scheduler, REV00 world renderer, and the complete
Marble/Spring Yard boss families. Each stays below 900 lines. Their registry
entries must state their concrete semantic cohesion. Tiny include indices, fixed
tails and data declarations are classified separately from executable modules;
they are not padded with comments to meet a line threshold.

The rename registry is exactly `config/reconstruction/label_renames.json`.
Imported global names are retained except for explicitly registered semantic
renames. Six address-generated audio return labels now name their owning FM,
PSG, panning and voice operations. Each rename records its old/new names,
current owner and behavioral reason; newly added boundaries remain additions.
`make audit-symbol-names` rejects active address-generated names, requires each
renamed symbol to have one definition in its declared owner and rejects stale
references to old names. This check also runs inside `make audit-symbolic` and
the ROM-independent source-layout scaffold. Historical names in comments and
string data are allowed. Imported symbol names are community evidence, not an
assertion that every interpretation was independently proved. The provenance
document names the source snapshot.

The final audit binds `preservation_baseline_commit` to the accepted predecessor
and checks every origin's file hash and line interval against that actual Git
snapshot. Drafts leave the binding empty until the preservation gate is
accepted; a prepared path map is not a substitute for this provenance check.

Each origin declares `preserved_span`, `generated_include_index` or `composite`.
A preserved span has an actual inclusive source-line interval. A generated index
has no invented original interval: it is checked as registered child includes
only, emits no exclusive bytes, and still binds the complete original owner's
hash. A composite origin lists ordered preserved fragments, each with its own
original path, interval and hash. Empty, nested, generated, duplicate or
overlapping fragments are rejected; the final audit checks every fragment
against the accepted preservation commit. The seven structural wrappers declare
`generated_include_index`. The HUD pattern wrapper instead records the exact
four original lines that were moved.

## Consolidated small owners

The general numerical services share `src/system/math.s`, preserving their
original order and the REV00-only square-root conditional. The boundary table is
inside its level setup owner; the level-order table is inside the end-of-act
card owner. Their labels, address positions and content contracts remain intact.
Unused small, item and fiery explosions share one adjacent object family. These
four groups reduce the source count by six without changing bytes. Sprites, HUD,
their shared helpers and independently owned graphics/animation declarations
retain their existing boundaries.

## Source filename convention

Source basenames use lowercase snake_case without numeric object-ID prefixes,
spaces or punctuation. Basenames use at most three words, rely on directory
context and name the primary entity rather than listing every child object.
Object IDs remain in the symbolic dispatch table and source comments. Imported
global assembly labels follow the rename registry described above.

The `.s` suffix identifies 68000 source and emitted content declarations; `.inc`
identifies shared constants, RAM declarations, macros and assembler setup. The
Z80 driver and its DPCM include wrappers retain `.asm`. The PCM logo sample
belongs to the 68000 source. These are project naming conventions, not processor
restrictions imposed by the assembler. Preservation origins continue to name the
original files at the accepted predecessor commit.

## Owner subdirectories

Environment objects are grouped under `src/game/objects/environment/` by `ghz`,
`lz`, `mz`, `slz`, `syz` and `sbz`. Cross-zone implementations belong to
`common`; preserved unused implementations belong to `unused`.

Mappings under `src/rendering/mappings/` use `player`, `enemies`, `bosses`,
`items`, `environment`, `special_stage`, `ui` and `unused` owner groups. The
environment group has the same zone/common split; mapping macros remain at the
mappings root. A descriptive imported filename alone is not proof of exclusive
zone ownership: the swinging-platform mapping named `ghz` also serves Marble and
therefore belongs to `environment/common`.

Animation declarations under `src/rendering/animation/` use corresponding owner
groups. The fireball script shared by boss and environment consumers belongs to
`shared`. Player animations retain their primary player owner even when other
engine paths read their frame definitions. Debug-mode references do not turn
enemy and environment mappings into UI-owned data.

Recorded inputs under `src/game/demos/` separate `attract` and `ending`. The
preserved unused demo remains at that root. These directory changes do not
change include order, data sharing, source origins or profile ranges. The
largest immediate source directory contains 17 files in this layout.
