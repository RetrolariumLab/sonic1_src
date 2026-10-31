# Symbolic pointers and relocation

The preservation profiles retain the original bytes. Relocation is a separate
probe of symbolic references and never replaces the canonical image.
`make build-relocated` creates the selected profile under
`build/relocated/<profile>/`; `make build-relocated-all` creates the matrix.

## What moves

The probe copies every selected assembler source and duplicates each terminal
68000 `rts` or `rte` before the next global boundary. Local continuation blocks
and instruction-table slots keep their widths. A repeated return is unreachable,
so it adds no executed instruction. The listing proves that return words were
actually emitted; the report records source hashes, pipeline hashes, generated
sites, active words and internal returns that are not procedure boundaries. The
probe does not omit complete source modules.

Every image is assembled from its own copied source root. Original source
includes cannot silently substitute for a copied file. AS outputs stay below
that root because AS treats dots in parent-directory paths as suffix markers.

## Addressing constraints

`config/relocation/probe.json` declares three layout adjustments in the copy:

- Move the shared moving-platform helper to the end of its owning module so
  SolidObject's signed word calls remain in range.
- Put DisplaySprite before the neighboring object index so REV00's ending-object
  word branch remains in range.
- Put the complete level-select table before its owner so the 68000 PC-indexed
  instruction retains an eight-bit displacement.

One unconditional SYZ boss branch changes from byte to word displacement. Both
forms take ten MC68000 cycles in the pinned MAME instruction table. Conditional
branches retain their original forms. These adjustments preserve execution time
while allowing the source ranges to move independently.

The gap before collision data is reclaimed in the probe. A first assembly
measures growth before the SEGA sample; a second assembly absorbs that growth in
the original gap before the sound driver. Bounds reject a negative, odd or
oversized adjustment. The sample's original ROM offset and the complete ROM
length must remain unchanged. Consequently the boot checksum loop visits the
same number of words. The checksum itself is recalculated.

## Static checks and limits

`make audit-symbolic` checks address-producing instructions, absolute control
transfers, pointer-bearing macros, raw ROM-valued equates and numeric longword
candidates. The explicit classifications in
`config/reconstruction/address_policy.json` explain the remaining tile-height
scalars, Nemesis row counter, decimal divisors and packed VDP command words.
Unused classifications fail the audit. The same target also checks the rename
registry and rejects active address-generated symbol families such as `loc_`,
`locret_`, `sub_`, `bra_` and `off_` followed by a hexadecimal address,
including local and Z80-prefixed forms. Comments and quoted data retain
historical names. `make audit-symbol-names` runs just this ROM-independent
name/registry check. Named fixed hardware regions are checked against each
canonical listing by `make verify-layout`.

The audit is a source-level guard. Runtime evidence remains scoped to the
recorded attract and ending scenarios. Neither those scenarios nor a source scan
establishes behavior for every possible playthrough. Remaining semantic
uncertainty belongs in [unknowns](unknowns.md).
