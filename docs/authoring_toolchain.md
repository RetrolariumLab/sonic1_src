# Authoring codec dependency

Canonical assembly uses the existing pinned Kit tool suite. Content validation
also needs Core's Python package and CLI. The Python package must be importable;
the CLI can be supplied through `RETROLARIUM_CORE`. Its source commit is
`cd5ac6974de99137214866ec72be547449235600` and its CLI version is `0.1.0`. This
version differs from the Python package version; neither is inferred from the
other.

The supported Windows build uses Visual Studio 2019, toolset v142, x64 and
Windows SDK 10.0.22621.0. Configure the unmodified Core checkout into a
directory under the project's ignored build root:

```sh
cmake -S "$CORE_SOURCE" -B build/dependencies/core -G "Visual Studio 16 2019" -A x64 -T v142 -DRETROLARIUM_CORE_BUILD_TESTS=OFF -DBUILD_TESTING=OFF -DCMAKE_SYSTEM_VERSION=10.0.22621.0 "-DCMAKE_CXX_FLAGS_RELEASE=/O2 /Ob2 /DNDEBUG /Brepro" -DCMAKE_EXE_LINKER_FLAGS=/Brepro -DCMAKE_STATIC_LINKER_FLAGS=/Brepro
cmake --build build/dependencies/core --config Release --parallel 1
```

`CORE_SOURCE` is an operator-supplied public source checkout, not a local path
stored in project configuration. The configured executable is
`build/dependencies/core/Release/rlcore.exe`. Set `RETROLARIUM_CORE` to that
path in the shell syntax of the supported host. Verify the source commit and the
executable SHA-256 before using it:

```text
71cc22cb06b4ee91946ad10471563aa37cf7e41fb2da27266aad08a0ccbce7b2
```

Two independent output directories produced this exact 66048-byte executable.
The source checkout was unchanged. A different compiler, SDK, configuration or
binary requires an explicit toolchain update and repeated codec checks; it is
not silently treated as the same dependency.

Use Core for Nemesis decoding and reference-table encoding. The full Enigma
packet codec and Kosinski codec belong to the project's current content checks.
The native decoder fixtures are separate from the original-ROM runtime goldens:
they execute the game's assembler procedures against synthesized expected
buffers and compare every decoded byte before reporting completion.

The native-decoder fixtures described here were separate local development
experiments. The public release command reproduces the registered model round
trips, independent Core Nemesis encoding/decoding and complete zero-edit export
builds; it does not silently substitute those fixture experiments for the
original-input runtime matrix.
