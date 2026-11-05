# Authoring codec dependency

Canonical assembly uses the pinned Kit tool suite. Content validation also uses
Core's importable Python package and native CLI. The CLI source commit is
`cd5ac6974de99137214866ec72be547449235600` and its version is `0.1.0`.

## Reproducible preparation

Set `RETROLARIUM_CORE_SOURCE` to a public Core checkout containing that commit,
then run:

```sh
make prepare-core
make check-core
```

Preparation exports the exact Git revision into ignored
`build/dependencies/core-source/`, rejects changed or unexpected cached source
files and builds under `build/dependencies/core-prepared/`. It requires Visual
Studio 2019, toolset v142, x64 and Windows SDK 10.0.22621.0. The configured
release uses `/O2 /Ob2 /DNDEBUG /Brepro`, deterministic static/executable
linking and `/INCREMENTAL:NO`. The public source checkout supplies the Git
archive only.

The default executable is `build/dependencies/core-prepared/Release/rlcore.exe`.
Two independent output directories reproduced the same 66048-byte executable
with SHA-256 `0d77f10e328db92b816adeacc31b2b72473123a8c8fbe32d0ef315fa40fb4fe6`.
The compiler maps the checkout root to the stable virtual prefix `sonic1` using
`/pathmap`, so source and object paths do not change the executable identity.
The previous explicitly pinned executable
`71cc22cb06b4ee91946ad10471563aa37cf7e41fb2da27266aad08a0ccbce7b2` remains an
accepted legacy build of the same source revision.

`RETROLARIUM_CORE` may select an existing executable. Both its hash and CLI
version are verified before use, and its hash is rechecked after every codec
operation. No arbitrary local binary or self-issued receipt is accepted.
Preparation records the exact archive, configuration and executable hashes in
ignored `build/dependencies/core-prepared/binding.json`.

Use Core for Nemesis decoding and reference-table encoding. Enigma and Kosinski
codecs belong to the game's content checks. Unit tests exercise synthetic Core
streams. Full content acceptance checks all owners, zero-edit export rebuilds
and bounded nonzero palette edits in complete ROMs.
