# Content formats and preservation

The format registry belongs at `config/authoring/data_formats.json`. It binds
resource owners to codecs, profile ABI, address space, bounds and a round-trip
claim. Extraction offsets and hashes remain owned by `assets/manifest.json`;
derived DAC sample ranges remain in `config/build/derived_assets.json`. Compiled
mappings, animations, demos and title-card tables use the checked source-layout
ranges. A format declaration never substitutes for its tests.

The accepted game ABI is the shared Mega Drive 68000 engine with the S1 type-1b
SMPS driver and Z80 DAC playback. Content documents retain their source profile
and owner. A write must name the same profile/ABI, stay inside the owned slot,
and pass field, shape and cross-reference validation before a file is replaced.
No changed data is silently truncated, quantized or written into a neighbouring
resource. Expanded layouts and cross-platform conversion are outside this scope.

## Compression and zero edits

| Transport | Decoded representation                                                                   | Encoding and preservation                                                                                                                                                                                                                               |
| --------- | ---------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nemesis   | 8x8 4bpp pattern rows; header tile count and XOR mode                                    | Core's real encoder reuses the reference code table. Re-decoding must give the same patterns. An unchanged resource retains its original compressed bytes when the encoder chooses another valid tokenization.                                          |
| Enigma    | Header, command packets and PCCVH inline fields; a derived view of big-endian tile words | The packet model preserves header choices, runs, inline fields and alignment bits and re-encodes exactly. The decoded word view is checked separately.                                                                                                  |
| Kosinski  | Literal/back-reference tokens expanding to bytes                                         | The project decoder follows immediate descriptor refill after bit 16. The bounded encoder chooses tokens over an 8 KiB LZ window. Re-decoding proves content equivalence; unchanged data retains its original stream when the new tokenization differs. |

A zero-edit export is exact even when recompression is only semantic: it first
performs a genuine encode/decode check, then retains the original stream for
unchanged content. This policy never claims the new compressed stream equals the
historical one. An edited compressed resource still has to fit its original
encoded slot and decoded destination capacity.

Nemesis uses a big-endian tile-count/XOR header, a nibble/run code table and a
bitstream. Each pattern is 32 bytes. The original game's RAM decoder has also
checked both original streams and real Core re-encodings in emulator fixtures.
The canonical build never rebuilds art with a different compressor.

Kosinski descriptors are little-endian and consumed least-significant bit first.
A literal consumes one control bit. Short copies use a signed 8-bit
back-reference and lengths 2 through 5. Long copies use a 13-bit negative
displacement and inline or extended lengths, up to 256. The extended zero count
terminates the stream. Back-references before output, truncated descriptors and
output beyond capacity are errors. Native decoder fixtures check original,
literal-reencoded and optimized streams independently.

Enigma has six header bytes: inline tile-bit width, PCCVH presence mask,
incrementing word and common word. Command prefixes select incrementing/common
runs, repeated/incrementing/decrementing inline values, or a list of inline
values. Prefix 111 with repeat nibble F terminates. Short prefixes are six bits;
other commands are seven bits. Inline fields consume enabled priority, two
palette, vertical-flip and horizontal-flip bits in that order, then the tile
field. Base-tile arithmetic follows the original 68000 procedure, including its
OR operations for priority/flips and additions for palette/tile values.

The pinned Core Enigma decoder handles only the flip subset of those flags. For
example, the synthetic stream `010400000000e1ff` represents word `2001`, but
that Core build returns `0001`. The project keeps Core unchanged and uses a full
packet codec checked against the game's actual procedure on every accepted
Enigma input and several base-tile values. This is a dependency compatibility
limit, not a reason to relax content checks.

## Patterns and level geometry

- **4bpp patterns:** each 8x8 pattern is 32 bytes, row-major, high nibble before
  low nibble. Pixels range from 0 to 15. The owner fixes the pattern count.
- **Tile words:** big-endian 16-bit values: 11-bit pattern index, X/Y flips, two
  palette bits and priority. A packed word is interpreted with its consumer's
  base tile; negative imported tile expressions can deliberately wrap before
  that base is applied.
- **16x16 blocks:** four tile words in top-left, top-right, bottom-left,
  bottom-right order. The level block buffer is 0x1800 bytes.
- **256x256 chunks:** 16x16 block references, 512 bytes per chunk. Fields retain
  the block index, X/Y flips, top and side solidity and the remaining bit.
  Rendering masks the index to 10 bits, while collision lookup uses 11; safe
  references must also fit the loaded block table. The chunk buffer holds 82
  chunks, 0xA400 bytes. Original encoded slots remain profile-specific.
- **Level/background layouts:** width-minus-one and height-minus-one bytes, then
  row-major chunk IDs. The two planes occupy alternating 0x40-byte rows with
  0x80-byte stride. Supported ordinary dimensions are at most 64x8 chunks. A
  zero chunk is empty. A final alignment byte is preserved explicitly.
- **Special stages:** Enigma expands to a 64x64 byte grid. Block IDs select
  original wall, ring, emerald and action-block definitions. The format model
  does not invent new object behavior for unused IDs.

The historical ending layout is a named boundary exception: its 32-byte owner
has a 15x3 header and two stored rows. The loader reads 15 more bytes from the
following ROM storage. The model records that dependency, preserves the header
and stored rows exactly, and rejects dimension changes that would cross its
owner. It never treats a generally truncated layout as valid. The reason for the
short original file and the gameplay relevance of the extra row remain separate
questions.

World exports require canonical engine capacities from the current profile's
checked AS listing. `Catalog.read` binds the respawn, block and chunk RAM bounds
to the export context. A block reference must fit the 0x1800-byte block buffer
(768 eight-byte entries). A layout ID is validated after the consumer's
subtract-one and seven-bit mask: zero is empty, and high-bit retail flags retain
their original meaning. Flagged chunks also require the following collision
chunk to fit RAM; flagged loop chunk A8 instead selects alternate chunk 51.
Fitting the encoded slot or the field width alone does not authorize a reference
beyond those RAM allocations. These checks establish RAM bounds; they do not
establish every level-specific art, collision or gameplay dependency.

## Placement, starts and collision

Normal object placements use six-byte records: X word; Y word with flip flags;
object ID with the remember/respawn bit; subtype byte. Y occupies 12 bits;
ignored bits are preserved. X equal to FFFF terminates, with the original
terminator tail retained. The terminator is not an object at that position.

The respawn allocation includes two counters and an unused zero index; the
current 0xC0-byte region therefore supports 189 remembered objects. Public
export derives that limit from the compiled symbols. Object X must remain
nondecreasing. Several verified retail lists already have descending pairs: zero
edits retain them, and an edit may retain only the same X pair at the same
record position. New or changed descending pairs are rejected; export never
silently sorts records or renumbers their respawn entries.

LZ/SBZ conveyor groups have a different format: a word count-minus-one followed
by X, Y and subtype words. Some groups retain a six-byte unused terminator after
the counted records. Treating these as ordinary placements is an error.

Start positions are X/Y words. Collision height arrays contain 256 columns of 16
signed bytes; angle and collision-index arrays retain byte values. The original
collision implementation supplies the orientation and solidity rules. Shape
checks and profile-specific resource bounds precede writes.

## Palettes and cycles

CRAM colors are big-endian words with three bits each of red, green and blue at
bit positions 1, 5 and 9. Other bits are explicit reserved fields. The codec
preserves them rather than normalizing an unchanged word. Cycle payloads are
color sequences using the same word format; their timing, selected subranges and
palette destinations belong to the source routines that consume them.

## Sprite mappings, DPLC and title cards

Mapping tables contain signed word displacements from each table's own base. A
S1 frame starts with a byte piece count. Each five-byte piece stores signed Y,
packed width/height-minus-one, a tile/attribute word and signed X. Width and
height range from 1 to 4 cells; coordinates range from -128 to 127. Reserved
size bits remain explicit. The format count is byte-sized; actual sprite-budget
limits are an additional engine constraint.

DPLC frames have a byte count and word entries. The upper nibble encodes
pattern-count-minus-one (1 through 16); the low 12 bits select the source
pattern. These are graphics-loading instructions, not sprite geometry.

Some blank mappings deliberately point to a zero byte inside another piece or
alignment padding. They are declared blank aliases. A shared-byte writer rejects
edits that would make an alias disagree with its owning piece. Other pieces lie
after incorrect imported frame-end markers and are not counted by the renderer;
they remain explicit detached geometry records.

Title-card storage contains four mapping tables, with shared frames used by zone
cards, Game Over, act results and special-stage results. Do not split or
duplicate those shared frames as an editing shortcut. Element setup records
contain Y, routine and frame fields. Seven zone-position rows contain four
start/target X pairs per row. The Final Zone and act-dependent frame selection
remain in the object code.

## Animation and demo input

Animation tables hold word offsets to scripts. A normal script has a delay byte,
frame IDs and a terminal action: FF loops, FE goes back, FD changes animation,
FC advances the primary routine, FB resets animation/secondary routine, and FA
advances the secondary routine. FE/FD consume one argument. Post-terminal bytes
and alignment are explicit storage, not invented commands. Sonic's
negative-delay locomotion scripts have six fixed slots plus an end byte and use
their own speed-dependent interpreter.

Demo records are controller bits plus duration-minus-one. Durations are 1 to 256
frames. Game demo data is distinct from the external verification movies;
editing one does not replace or regenerate the other's expected RAM trace.

## SMPS and DAC

Music headers hold a relative voice-bank word, FM/DAC and PSG counts, tempo
divider and tempo. The accepted engine permits up to seven FM/DAC entries
(including the DAC slot) and three PSG entries. FM/DAC channel records contain
relative track offset, transposition and volume; PSG records add modulation and
envelope selection. Effects use divider/count fields and six-byte channel
records containing playback/channel control, relative track offset, pitch and
volume.

Track bytes distinguish durations, notes/sample IDs and E0-F9 coordination
commands. The command registry owns their operand counts. Jump, loop and call
words are signed displacements from the low byte of their displacement field;
header pointers are relative to the stream header. The parsed graph checks
branch destinations, command boundaries, voice-bank separation and termination.
Unreferenced spans are retained and identified rather than executed as tracks.

FM voices occupy 25 bytes: algorithm/feedback followed by six groups of four
operator bytes (detune/multiple, rate/attack, modulation/decay, sustain rate,
sustain/release and total level). The byte order follows the driver's register
upload order, operator 1, 3, 2, 4. Reserved bits are retained. PSG envelopes are
attenuation steps ending in the original 80 hold marker.

SEGA PCM is unsigned 8-bit output. Its retained metadata says 16500 Hz; the
original playback loop computes its counter from a 16000 Hz target. These are
different facts, and no resampling is performed. DPCM starts its accumulator at
80, consumes high nibble before low nibble and adds the engine's 16-entry delta
table modulo 256. Encoding reverses those exact deltas and rejects an
unrepresentable waveform step. Kick, snare and timpani metadata retain their
original pitch targets. Derived sample ranges use decoded Z80 addresses.

The compressed DAC container is an extraction transport. Executable 68000,
bootstrap Z80 and DAC Z80 code remain assembler source. A content exporter must
not replace the assembled driver with the extracted executable blob.

## Checked documents and compiled views

`make roundtrip-formats` validates every registered owner against its accepted
profile and re-encodes every payload. `make check-content-zero-edit`
additionally exports every private resource into a new directory and rebuilds
all three ROMs using that export as the assembler's asset root. These are real
content rebuilds; the preservation asset checks remain enabled. Reports belong
to `build/authoring/` and bind current source, pipeline, codec and registry
hashes.

The public document interface is `python scripts/run.py authoring.cli`. `list`
prints owner IDs. `decode --owner ID --output build/document.json` writes a
profile-bound JSON model.
`encode --owner ID --document build/document.json --profile PROFILE --output build/edited.bin`
validates and encodes it. Output must remain below `build/` or ignored
`content/workspace/`. The encoder produces an owned payload; inserting an edited
payload into a game remains a separate integration task. Preservation builds
always require the accepted private hashes.

Compiled content views follow real AS include frames and macro expansion events.
The title-card view includes its Game Over child because it exposes a shared
mapping family; the child also has a named view. The registry records this
relationship. This does not duplicate source ownership: the source layout has
exclusive ranges, and a future composer must reconcile overlapping view edits.
The current zero-edit exporter leaves assembler content source unchanged after
proving its encoded bytes equal the emitted view.

SBZ palette-cycle scripts contain a word count-minus-one and six-byte records:
duration-minus-one, colour count, source palette word address and destination
palette RAM word address. Both act variants are modeled. A source read must fit
one registered palette resource, duration must fit a byte, colour count must fit
one line, and an aligned destination must stay in the 128-byte active palette.
The current profile's AS symbols and extraction owners supply those bounds.
Other zone cycle timing is executable code; its palette values use the palette
codec rather than a fabricated universal script format.

Changing an Enigma word view uses literal full-PCCVH packets and must fit its
original slot. Unchanged Enigma storage is reconstructed from the original
packet model. The compressed DAC driver view is intentionally read-only: code is
edited in `src/audio/z80.asm`, and its three sample owners have independent DPCM
models. A raw executable byte editor is not an authoring capability.

Every owner is decoded, validated and encoded in its own profile and boundary
context, including when another owner's original bytes are identical. Equality
of source bytes does not prove equal destination capacities or palette-read
permissions. The aggregate does not reuse another owner's model/proof to skip
those checks.
