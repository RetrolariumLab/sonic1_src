# Sonic the Hedgehog preservation source

This repository reconstructs the original Mega Drive game from assembler source
and private data extracted from your legally obtained cartridge images. It
supports REV00, REV01 and the collection REVXB, with REV01 as the default.
Canonical builds are byte-identical; moved-source builds are checked against
original-ROM attract and ending RAM traces. The 1.0 release candidate is checked
by the aggregate gate; release tags belong to the owner. Semantic source layout
and comprehensive content authoring belong to the following stage.

Supply the three dumps named in `assets/manifest.json`. No ROM, extracted
payload, music, sound effect or sample is distributed here. Install Python
3.11+, GNU Make and the pinned Retrolarium Kit build tools and MAME on Windows
x86_64; [build instructions](docs/build.md) describe version and hash checks.

```sh
make split ROM_DIR="path/to/dumps"
make verify-all ROM_DIR="path/to/dumps"
make test
```

The one command for full preservation verification is:

```sh
make release-check ROM_DIR="path/to/dumps"
```

Bare `make` shows commands. Extracted payloads live in ignored `data/`; all
outputs and temporary files live in ignored `build/`. Start with the
[documentation index](docs/index.md), [known limits](docs/unknowns.md) and
[provenance and licensing](docs/provenance.md). The upstream disclaimer follows
unchanged; the project supplies no licence to the game or imported annotations.

# DISCLAIMER

Any and all content presented in this repository is presented for informational
and educational purposes only. Commercial usage is expressly prohibited. Sonic
Retro claims no ownership of any code in these repositories. You assume any and
all responsibility for using this content responsibly. Sonic Retro claims no
responsibility or warranty.
