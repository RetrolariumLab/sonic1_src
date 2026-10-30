# Working on content and source

Begin with an accepted private image and a clean preservation build. The image
manifest owns filenames and hashes; the revision manifest owns assembler
defines. Extracted content belongs in ignored `data/`, user documents in an
ignored workspace, and all generated outputs in `build/`.

The fast loop is lint, ROM-independent tests and scaffold validation. The full
2.0 loop additionally runs the complete preservation gate, every content owner
round trip, a zero-edit container check and release/document audits. The same
public commands must be exercised from a fresh clone; an old output directory is
not an input.

A content model binds its profile, ABI, owner and destination capacity. Decode
through the registered codec. Edit only supported fields. Validate every field,
shape, pointer and shared byte before encoding; validate compressed and decoded
sizes before replacing an output. A model for another profile is rejected even
when some current bytes happen to match.

For a zero edit, re-encoding the model must reproduce the payload. Compression
may instead prove semantic equivalence through a genuine encode/decode and
retain the original stream. This exception applies only while content is
unchanged. For an edit, over-capacity output is an error. The shortened original
ending layout has immutable boundary metadata; general truncated layouts fail.

No GUI or editor project lives here. Retrolarium is the intended consumer of
these specifications and codecs. Canonical preservation builds continue to
require their accepted hashes. Editing experiments do not silently become an
accepted preservation profile or bypass the default asset checks.

Source moves update include paths, profile entrypoint, lint roots, relocation
owners/anchors, address policy, manifests, docs and tests together. Before a
move, record the accepted baseline. After each committed slice, check every
profile byte for byte. Verify the moved-source runtime again after all pipeline
changes; a source or tool hash mismatch invalidates a saved report.

Use `python scripts/run.py authoring.cli list` to find an exact owner ID, then
`decode` and `encode` as described in [data formats](data_formats.md). Documents
are private local files. Encoded edits are separate payloads, never replacements
for the accepted canonical asset store. Use `make check-content-zero-edit` to
check the complete preservation export and rebuild path.
