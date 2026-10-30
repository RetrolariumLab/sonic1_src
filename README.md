# Sonic the Hedgehog (SMD) Source Reconstruction

A byte-identical source reconstruction of **Sonic the Hedgehog** for the Sega
Mega Drive / Genesis, maintained as a fork of
[Sonic Retro's Sonic 1 disassembly](https://github.com/sonicretro/s1disasm). The
shared 68000 and Z80 source rebuilds REV00, REV01 and the Sonic Mega Collection
REVXB from legally obtained cartridge images.

The fork starts from the upstream AS branch at
[`89c0e0e`](https://github.com/sonicretro/s1disasm/commit/89c0e0e06b51fd9ebac44d988e4a89bd643fd031).
Its Git history begins with a text-only snapshot import; the original authors
are credited in [CONTRIBUTORS.md](CONTRIBUTORS.md).

## Status

Source Reconstruction 1.0 establishes the byte-identical build, symbolic address
checks, relocated-source probes and original-ROM runtime comparisons. Source
Reconstruction 2.0 adds:

- 437 source modules organized by subsystem and semantic owner;
- shared REV00, REV01 and REVXB profiles, with REV01 as the default;
- 25 game-data formats with bounded, profile-aware content models;
- round-trip checks for all 1834 registered content views;
- three byte-identical rebuilds from a newly encoded zero-edit export;
- direct attract and ending RAM checks in MAME for every revision.

The entry point is `src/main.s`. Data extracted from the ROM stays in ignored
`data/`; generated ROMs, listings, reports and scratch files stay in ignored
`build/`. ROM images, extracted graphics, music, effects and samples are not
distributed with this repository.

## Quick start

The supported host is Windows x64 with Python 3.11+, GNU Make, the pinned
Retrolarium Kit and Core dependencies, and MAME. Kit supplies the AS Macro
Assembler and authentic p2bin compressor. See [building](docs/build.md) for
installation and version checks, and the
[codec toolchain guide](docs/authoring_toolchain.md) for the Core CLI.

```sh
git clone https://github.com/RetrolariumLab/sonic1_src.git
cd sonic1_src

# Put your legally obtained dumps in a separate folder, using the filenames
# recorded in assets/manifest.json.
make check-inputs ROM_DIR="path/to/dumps"
make split ROM_DIR="path/to/dumps"
make verify-all ROM_DIR="path/to/dumps"
```

Each verification compares the rebuilt image byte for byte with the supplied ROM
and checks its SHA-1 and SHA-256. Supported profiles are:

| Profile | Reference image             | Selection                   |
| ------- | --------------------------- | --------------------------- |
| `rev00` | Original REV00              | `PROFILE=rev00`             |
| `rev01` | Revised REV01               | Default, or `PROFILE=rev01` |
| `revxb` | Sonic Mega Collection REVXB | `PROFILE=revxb`             |

Expected filenames, sizes and hashes belong to `assets/manifest.json`.

## Build and verify

```sh
make help                         # Show the public command catalog
make verify-toolchain             # Check the pinned assembler and p2bin
make check-assets                 # Check every extracted asset hash
make build PROFILE=rev01           # Assemble the selected revision
make verify ROM_DIR="path/to/dumps"  # Build and compare the default revision
make verify PROFILE=rev00 ROM_DIR="path/to/dumps"
make verify-all ROM_DIR="path/to/dumps"
make clean                        # Remove build results; keep extracted data
```

Outputs are written under `build/artifacts/<profile>/`. The build uses AS,
authentic Kosinski compression and the original header/checksum rules.

```sh
make format                       # Apply the project style, then lint
make lint                         # Check source, text and private-data policy
make test                         # Run the Python tooling tests
make scaffold-check               # Check repository structure without ROMs
make audit-private                # Audit reachable history for private payloads
make audit-symbolic               # Check address expressions and fixed operands
make verify-layout                # Check declared fixed regions
make source-layout-check          # Recompute source ownership for all profiles
make build-relocated-all          # Build the moved-source probes
make runtime-check                # Compare their RAM traces in MAME
```

Source-ownership and runtime checks need current builds and extracted inputs.
MAME runs are sequential. The recorded scenarios cover attract and ending paths;
they do not prove every gameplay path or every imported semantic name.

## Content models

The headless models describe tiles, palettes, blocks, chunks, layouts,
collision, objects, mappings, DPLC, animations, demo input, SMPS and DAC data.
Their profile, capacity and address-space contracts are declared in
`config/authoring/data_formats.json` and explained in
[data formats](docs/data_formats.md).

```sh
make roundtrip-formats            # Decode and encode every registered view
make check-content-zero-edit      # Export content and rebuild all three ROMs
python scripts/run.py authoring.cli --help
```

Nemesis and Kosinski encoders validate decoded equivalence and retain the
original compressed stream when content is unchanged. The 2.0 baseline covers
checked payload models and zero-edit rebuilds; a general edited-ROM composer is
outside this release. See [development](docs/development.md) and
[known limits](docs/unknowns.md).

## Release checks

The complete 2.0 command first runs the full 1.0 gate, then source ownership,
all content round trips, export rebuilds and the final source/content audit.
Pre-tag gates require a committed candidate with no active release tag and no
publishing remote. Use a disposable checkout for that workflow:

```sh
git clone --no-tags https://github.com/RetrolariumLab/sonic1_src.git sonic1-check
git -C sonic1-check remote remove origin
make -C sonic1-check source-2-check ROM_DIR="path/to/dumps"
```

After an annotated release tag is created in the checked checkout, validate it
with `make release-audit AUDIT_MODE=--post-tag` and `make source-2-audit`.
[Verification](docs/verification.md) describes the evidence, dependencies and
pre-tag/post-tag boundaries.

## Repository map

```text
assets/                 Reference image identities and extraction manifest
config/authoring/       Content formats, capacities and codec toolchain
config/reconstruction/ Source origins, ownership, symbols and fixed regions
docs/                   Architecture, formats, workflows and evidence
mk/                     Build, runtime, validation and content Make targets
scenarios/              Original-input movies, RAM checks and revision matrix
scripts/authoring/      Headless models, codecs and export interface
scripts/build/          Extraction, assembly and byte-identity checks
scripts/runtime/        MAME execution and runtime validation
scripts/validation/     Static, source-layout and release audits
src/                    Shared 68000/Z80 source, definitions and data declarations
tests/                  Tests mirroring the script package layout
data/                   Ignored private assets extracted from user ROMs
build/                  Ignored generated outputs and local evidence
```

Start with the [documentation index](docs/index.md),
[architecture](docs/architecture.md), [source layout](docs/source_layout.md) and
[memory map](docs/memory_map.md). See [CONTRIBUTING.md](CONTRIBUTING.md) for the
change and verification workflow.

## Credits

- Original game: SEGA, 1991.
- Original disassembly and community work: Sonic Retro and the
  [upstream contributors](CONTRIBUTORS.md).
- AS Macro Assembler: Alfred Arnold.
- Build and codec dependencies: Retrolarium Kit and Retrolarium Core.
- Runtime validation: MAME.

The import revision, removed optional modifications and attribution boundaries
are recorded in [provenance](docs/provenance.md).

## Copyright and licensing

Original game copyright (C) 1991 SEGA. Game code, graphics, music and other game
data remain the property of their respective rights holders.

This repository does not distribute ROM images or extracted copyrighted assets.
Users supply their own legally obtained reference images. No licence to the game
or the imported upstream annotations is granted by this project; the upstream
rights status is documented in [provenance](docs/provenance.md). The original
Sonic Retro disclaimer is retained below.

# DISCLAIMER

Any and all content presented in this repository is presented for informational
and educational purposes only. Commercial usage is expressly prohibited. Sonic
Retro claims no ownership of any code in these repositories. You assume any and
all responsibility for using this content responsibly. Sonic Retro claims no
responsibility or warranty.
