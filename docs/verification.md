# Preservation verification

Run the complete supported-host gate with your own accepted dumps:

```sh
make release-check ROM_DIR="path/to/dumps"
```

The fail-fast sequence is lint, tool tests, legal inputs, output cleanup,
extraction, canonical builds and byte identity for every profile, symbolic
pointers and fixed-region checks, all relocated builds, six sequential MAME
checks, documentation/manifest/history audit and finally a clean Git tree. The
ROM-independent `make test` command skips only explicitly optional private input
integration tests. A release gate never skips a missing ROM or runtime row.

The default is REV01, but the aggregate gate always checks REV00, REV01 and
REVXB. Identity compares lengths and every byte before validating SHA-1 and
SHA-256. The relocation gate uses the same source and toolchain while moving
terminal return sites. Runtime checks compare exact registered RAM bytes against
original-ROM traces; they do not use tolerances, RAM patches or screenshots.
Every profile directly covers attract and ending scenarios. The ending uses
original controller shortcuts on the supplementary Japanese NTSC machine; the
primary attract check uses `genesis`.

`make release-audit` checks release fields, document links, evidence references,
profile/artifact facts, actual source landmarks, runtime reports and Git
history. It rejects missing or stale identity/relocation/runtime evidence, empty
commits, wrong attribution, non-English new text, private payloads and a dirty
tree. The future release tag is an owner action; it must not already exist when
the pre-tag gate is run. This repository has no configured publishing remote.

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
