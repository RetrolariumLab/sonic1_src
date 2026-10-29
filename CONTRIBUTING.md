# Contributing

Keep tracked source, comments, documentation and commit messages in English.
Never add ROMs, extracted assets, screenshots, samples or editor projects to Git.
Use the ignored `build/` directory for scratch work and generated outputs, and
`data/` for extracted private assets. Do not add GUI editors.

Run `make test`, `make audit-private` and `make verify-all` against your own
accepted inputs before committing. Mechanical formatting and source movement
belong in separate commits from behaviour changes. Every preservation profile
must remain byte-identical after each buildable commit.

The profile and asset manifests own their facts; do not duplicate filenames,
hashes or revision defines in build recipes. Record uncertain semantics as
unknowns rather than assigning unsupported names. Preserve imported attribution
and the upstream disclaimer. No licence to the game is implied by this work.
