# Building the preservation profiles

The accepted images are REV00, REV01 and the Sonic Mega Collection REVXB.
`assets/manifest.json` owns their filenames, sizes and hashes.
`config/revision_profiles.json` owns their assembler defines and the default
profile. The default is REV01. All three share `src/main.s`.

Install Python 3.11 or later, GNU Make and Retrolarium Kit with build-tool
release 2026.10.11. This checkout currently pins the Windows x86_64 assembler
and p2bin executables. Retrolarium Core's Python package must be importable by
the selected Python interpreter; a source installation can supply its `python/`
directory through `PYTHONPATH`. `make verify-toolchain` verifies their SHA-256
before assembly; unsupported hosts fail explicitly rather than use an unpinned
tool.

Place your legally obtained dumps under their manifest filenames in the project
root, or pass `ROM_DIR` pointing to their folder:

```sh
make split ROM_DIR="path/to/dumps"
make verify-all ROM_DIR="path/to/dumps"
make test
make audit-private
```

Bare `make` shows help. `make verify` checks the default profile;
`make verify PROFILE=rev00` selects another accepted image. Each verification
checks both input hashes, builds independently and compares every output byte
with the input before checking both output hashes.

## Extraction and assembly

`make split` calls `rltool assets split` for the ROM ranges declared by the
manifest. Each profile has its own subtree under the ignored `data/` root. The
DAC container is then decoded as Kosinski; its decompressed hash and every
sample's bounds and hash are checked before the DPCM files are written. SEGA PCM
is a direct ROM slice. No WAV conversion is needed.

AS resolves binary includes through the selected `data/<profile>/` include root.
Text includes resolve through the source root. A small generated entry supplies
manifest-owned defines, then includes the shared source. Every object, listing,
error log and ROM is under `build/artifacts/<profile>/`.

The pipeline is AS, p2bin with authentic Kosinski compression, then the ROM end
address and checksum update. The Z80 DAC driver remains assembler source. Its
16-byte delta table is a `db` declaration because AS uses the Z80 data dialect
inside that module. Sample sizes are computed from their included byte ranges.

`make check-assets` verifies every extracted payload hash. `make clean` removes
only checked artifact, relocation and runtime directories under `build/`, and
leaves original inputs and extracted assets alone. All temporary files and
reports are ignored. Nothing in the build requires a previous output.

## Aggregate validation

`make release-check ROM_DIR="path/to/dumps"` runs the complete preservation
gate, including clean extraction/builds, all runtime checks and a clean tracked
tree. See [verification](verification.md) for order and evidence. The candidate
must be committed before the clean-clone and tag-ready checks can succeed.

## Kit style integration

Kit's AS linter selects `.s` and `.inc` files. The project uses `.s` for 68000
code and emitted tables, `.inc` for shared definitions, and `.asm` for the Z80
driver and its DPCM sample wrappers. The validation adapter selects every
tracked source named by `config/lint.json`, stages protected copies under
`build/lint-stage/` and calls `rltool lint` on those copies. Z80 `.asm` copies
receive the `.s` suffix only within that disposable stage. Only an explicit
format operation copies formatting back. General tracked text and code use
`rltool lint` and `rltool format` directly. No copy is a build input and no Kit
or Core source is changed.

The same projection protects AS column-zero declaration fields (assignments,
functions, structs and local labels) that the current Kit formatter does not
recognise. Disposable explicit labels make the CLI preserve their field role;
the exact original declaration tokens are restored before copying formatting
back. Byte identity remains a separate mandatory check after formatting.

`make lint` checks assembly, text, code and private-data policy without changing
tracked files. `make format` applies formatting and always follows with lint; a
second invocation is required to leave the tracked tree unchanged.
`.git-blame-ignore-revs` names the isolated mechanical formatting commit.

Content round trips additionally require the hash-pinned Core CLI described in
[authoring toolchain](authoring_toolchain.md). `make scaffold-check` does not
need ROMs or that executable. Full `make source-2-check` requires all accepted
inputs, the CLI, the pinned assembler suite and MAME; it never skips a
dependency.
