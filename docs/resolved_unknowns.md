# Resolved implementation questions

## Build transport and audio extraction

All three accepted profiles assemble exactly with the pinned Kit AS and p2bin.
No bundled historical assembler is needed. The DAC driver is assembled from Z80
source, then compressed authentically; the extracted compressed container is
used only to recover private DPCM samples. Direct PCM and decoded sample bounds
are checked against their owning manifests.

Music/effects and embedded voices are private bytecode inputs. PSG envelopes are
also extracted, rather than retained as assembler content. Header and branch
word interpretation is established by the source driver/macros and by parsing
all accepted streams. This does not prove every musical or game-semantic name.

## Source relocation

The sound-bank tail and ROM length must stay stable during the probe so the
original checksum loop keeps its iteration count. Growth is absorbed only inside
a bounded original padding region. Other declared moves keep signed branch reach
without adding execution cycles; jump-table slots keep their width. All three
moved profiles pass their direct original-input runtime scenarios.

## Content representation

The complete Enigma PCCVH mask has five flags. The project codec is checked
against the original game procedure for all accepted streams and multiple base
values. A synthetic palette-bit stream exposes the pinned Core decoder's
unsupported subset without distributing game data.

Conveyor object groups are count-prefixed records, not normal object placements.
Sonic locomotion animations use fixed six-slot sequences. Several invisible
mapping frames borrow zero bytes from another record; they require shared-byte
constraints. Sprite pieces outside imported frame-end markers remain explicit
unreferenced geometry rather than being silently added to a live frame.

These resolutions do not close remaining questions about imported semantic
names, unobserved gameplay, post-terminal animation bytes or the reason the
original ending layout declares an extra row. Those belong in the unknowns
registry with their source owner and next evidence.

## DATA-001: content formats

The original preservation-stage format gap is resolved by the profile-bound
registry, headless record/stream models and per-owner decode/encode checks.
`make check-content-zero-edit` validates every owner independently and rebuilds
every accepted ROM from a fresh private export. Historical compressor token
choices and general edited-ROM composition remain separately bounded in
[data formats](data_formats.md) and [unknowns](unknowns.md).
