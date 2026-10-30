# Accepted revisions and variants

The shared source accepts REV00, REV01 and the collection REVXB. Their exact
private filenames, lengths and hashes belong to the image manifest, and their
`Revision` defines belong to `config/revision_profiles.json`. REV01 is the
default. The profiles use one 68000/Z80 ABI and one preservation entrypoint.
Differences remain official revision branches and profile-owned private data.

Every accepted image has a byte-identity build and direct runtime evidence.
There is no inferred equivalence class standing in for an unrun revision. The
primary attract scenario uses `genesis`; the supplementary ending scenario uses
`megadrij` and original Japanese title-controller shortcuts. Both machine
choices are part of the recorded scenario, not interchangeable emulator
defaults.

Relocated probes are diagnostic builds outside the canonical image contract.
They duplicate terminal returns and apply declared timing-preserving layout
adjustments. Their size, sample-bank position, source hashes and runtime
evidence are checked independently. They are not an expanded-game release.

Prototypes, remakes, other platforms, community fixes/optimizations, the
optional larger-layout community branch and lock-on Blue Sphere software are
excluded. Other collection conversions are not implicitly accepted merely
because REVXB is supported. A future addition needs its own legal input,
shared-source or ABI decision, capacity metadata and direct runtime evidence.

The owner creates release tags. Continuing development beyond a checked
preservation point does not imply that its tag already exists. A later manifest
must bind the actual accepted predecessor commit and verify any owner-created
predecessor tag against it; it must not invent a tag or replace that evidence
with the current branch name.
