# Runtime evidence

Runtime uses pinned MAME 0.289 and the public `rltool movie golden` and
`rltool movie check` commands. `config/toolchain.json` records the executable
SHA-256 and upstream source commit. `scenarios/runtime_matrix.json` owns the
profile/scenario matrix, required states and setup declarations.

Each accepted image has direct coverage, with its own original-ROM golden
values. No profile inherits another profile's runtime result.

## Attract mode

The `genesis` machine runs 15000 frames from power-on without controller input.
Every sixty frames the scenario reads the game mode, zone, act, camera and Sonic
positions, rings, score, lives, in-game frame counter, demo flag and credits
index. Acceptance requires normal GHZ, MZ and SYZ demos and a special stage.

## Ending and credits demos

A supplementary 18000-frame scenario uses the same cartridge on Japanese NTSC
hardware, MAME's `megadrij` machine. Recorded title inputs enable the original
level-select and hidden credits shortcuts, then play sound-test entry 9F.
Japanese hardware is needed for that original shortcut. The main attract
coverage remains on `genesis` for every revision.

The setup is recorded controller input, declared in the matrix. It reaches the
original ending, credits pages and all eight ending demos through the game's own
code. Checks require their zone/act pairs and credits indices with ending demo
flag 8001. The additional RAM cells prove the original shortcut flags and menu
selection. Checkpoints compare exact bytes, with no positional tolerance.

## Explicit Special Stage transition

The 8000-frame `special-stage` scenario uses original title inputs on `megadrij`
to enable level select and choose its Special Stage row. Idle play then reaches
the results path and returns to Green Hill. Ordered checkpoints must observe
mode 16, the Green Hill title-card mode 140, then mode 12 with demo flag zero.
Each revision owns its original golden and its direct relocated comparison.
`make runtime-golden SCENARIO=special-stage` records only this route when the
original dumps are supplied through `ROM_DIR`.

## Capturing and checking

```sh
make runtime-golden ROM_DIR="path/to/dumps"
make build-relocated-all
make runtime-check
```

Golden generation verifies the user input by both hashes before launching it.
Only the original ROM supplies expected values. A check binds the golden to the
accepted image, movie bytes and pinned emulator, and the relocated artifact to
its current source and pipeline fingerprints. Missing checkpoints, missing RAM
cells, added tolerances, altered input or an unreached required state fail.

All emulator runs are sequential. The runner refuses to start with another MAME
process active and checks for remaining processes afterward; an owned leftover
is terminated and fails the run. Logs, timestamps and artifact-bound check
reports are written only under `build/runtime/`. Temporary movie files are
confined to `build/tmp/`. Text golden values and controller recordings are the
reviewable, tracked evidence; screenshots are not part of the comparison.

[Relocation](relocation.md) explains the moved code and timing constraints.

The checked emulator executable is copied to `build/emulator/`. Each invocation
clears only the generated contents beside that copy, so MAME configuration,
NVRAM and save-state defaults start clean and remain inside the project build
root. The configured external executable is read and hash-checked, then kept out
of the execution path. Golden metadata records this environment boundary.

The runner waits up to one hour for an already active MAME process before
starting a check. It never terminates another task's process to obtain the slot.
A busy timeout is a failed gate; it is not a skipped scenario or successful
runtime result. Every owned process is checked again after each run.
