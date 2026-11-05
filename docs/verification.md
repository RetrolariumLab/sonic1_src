# Preservation verification

Run the complete supported-host gate with your own accepted dumps:

```sh
make release-check ROM_DIR="path/to/dumps"
```

The fail-fast sequence is lint, tool tests, legal inputs, output cleanup,
extraction, canonical builds and byte identity for every profile, symbolic
pointers, symbol names, the rename registry and fixed regions, all relocated
builds, nine sequential MAME checks, documentation/manifest/history audit and
finally a clean Git tree. The ROM-independent `make test` command skips only
explicitly optional private input integration tests. A release gate never skips
a missing ROM or runtime row.

The default is REV01, but the aggregate gate always checks REV00, REV01 and
REVXB. Identity compares lengths and every byte before validating SHA-1 and
SHA-256. The relocation gate uses the same source and toolchain while moving
terminal return sites. Runtime checks compare exact registered RAM bytes against
original-ROM traces; they do not use tolerances, RAM patches or screenshots.
Every profile directly covers attract, ending and an explicit Special Stage
entry/return scenario. The ending uses original controller shortcuts on the
supplementary Japanese NTSC machine; the primary attract check uses `genesis`.

`make release-audit` checks release fields, document links, evidence references,
profile/artifact facts, actual source landmarks, runtime reports and Git
history. It rejects missing or stale identity/relocation/runtime evidence, empty
commits, wrong attribution, non-English new text, private payloads and a dirty
tree. The active future release tag is an owner action; it must not already
exist when the pre-tag gate is run. A ready source/content manifest binds its
accepted preservation predecessor; if the owner has created that predecessor
tag, it must be annotated and point to the bound commit. The inherited
preservation gate then checks the active source/content tag. A draft does not
change this policy. Run the pre-tag gate in a disposable clone made with
`--no-tags`, then remove its clone remote before verification; the canonical
published checkout retains its publishing remote and accepted tags.

Reports stay under `build/release/`, `build/audits/`, `build/artifacts/`,
`build/relocated/` and `build/runtime/`. They are recomputed and not public
source. A passing probe and these recorded paths do not prove all gameplay
behavior or all imported semantic names. [Unknowns](unknowns.md) records those
limits.

For a clean-clone reproduction, clone this source into an empty directory,
install the pinned public tools, supply the dumps from outside the clone and run
the same command. No extracted `data/`, prior `build/`, absolute local path or
configuration from the original checkout is needed. Temporary files and an
exact-hash copy of the configured emulator remain below the clone's `build/`.

The opt-in integration contract test executes this exact Make target in a fresh
local clone when `RUN_RELEASE_SMOKE=1` and `ROM_DIR` are supplied. Its child
removes that opt-in variable to avoid recursive integration runs. It requires a
committed candidate, since a clone cannot test uncommitted source.

## Source and content candidate

`make source-2-check ROM_DIR="path/to/dumps"` first executes the complete
preservation gate above. It then runs ROM-independent `scaffold-check`, actual
`source-layout-check`, the complete `check-content-zero-edit` (including every
owner round trip and all three export rebuilds), and `source-2-audit`.
`roundtrip-formats` is the focused public round-trip command. The aggregate
checks current inputs again at the end and requires a clean Git tree.

The source layout proves disjoint and complete ownership of ROM and decoded Z80
bytes separately. Compiled content views require a current byte-identical AS
build. Content reports bind codec and manifest hashes, validate every
profile/ABI/capacity, and distinguish genuine re-encoding from unchanged
original compressed storage. The final audit checks those reports and each
export image. A missing predecessor commit or draft manifest cannot pass the
final audit.

Successful isolated identity/content checks do not replace the required
clean-clone aggregate gate or make an uncorrected reachable history releasable.

The delta maps each substantive commit since the accepted predecessor exactly
once. The current candidate commit is named `release-commit` in its own delta
row, which resolves to current HEAD during the audit and avoids a hash
self-reference. This token does not permit an empty commit or an unlisted
intermediate change.

The predecessor commit must also contain the complete preservation manifest,
including every accepted artifact identity, requirement and full gate sequence.
An arbitrary older source snapshot cannot stand in for that release boundary.
This metadata check supplements the actual inherited gate and source-origin
checks; it does not turn a declaration into proof of a past successful run.

The source/content aggregate also runs `check-memory-layout` and
`check-content-edits`. Memory grammar checks run during lint without ROMs. Built
checks compare all declared RAM fields, structure offsets and Z80 symbols with
the pre-change ABI witness, then check decoded driver bytes against their
independently extracted original. The edited-container audit revalidates exact
predicted ROMs and current authoring input fingerprints before accepting
evidence.
