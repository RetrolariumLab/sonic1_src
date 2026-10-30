# Architecture decisions

The project retains one preservation engine selected by manifest-owned official
revision defines. It extracts private audio and visual content from accepted
ROMs, while executable 68000 and Z80 programs remain assembler source. This
keeps provenance and byte identity separate from content storage permissions.

The assembler's include order is the cartridge layout. Semantic files may move
in the directory tree without moving emitted bytes. The source-layout registry
records exclusive emitted intervals, compilation-only records and transformed
Z80 storage. A relocation probe separately tests symbolic pointers by moving
terminal return sites; it does not change the preservation image.

Private SMPS streams are kept as original bytecode. Their headers and control
flow use relative offsets, and their containing bank moves coherently. Songs,
effects, FM voices, PSG envelopes and samples are excluded from tracked source;
engine pointer, command and register-order tables remain symbolic/source-owned.

Compression has two contracts. The canonical engine uses pinned AS/p2bin
behavior and original private inputs to reproduce the cartridge exactly.
Authoring codecs also perform real re-encoding and semantic checks. When their
tokenization differs, an unchanged resource retains its original stream; an
edited resource must fit its declared slot. A hash alone never replaces a byte
comparison or an independent decoder check.

Core supplies Nemesis. Its pinned Enigma implementation does not cover S1's full
PCCVH mask. A project packet codec fills that compatibility gap, checked against
the game's original 68000 procedure. Core and Kit are unchanged. The Core CLI is
built outside its source checkout with deterministic MSVC settings and verified
by executable hash.

Content tools are headless models/codecs and specifications. GUI editing belongs
to Retrolarium. There is no new repository editor, copied external editor
project, opaque executable asset, sibling engine or expanded-layout ABI.

The one known shortened ending layout remains unchanged. Its declared read
crosses the private file boundary, so the model records a cross-owner read and
forbids resizing rather than inventing missing bytes. Correcting that historical
behavior would be a separate, non-preservation decision.
