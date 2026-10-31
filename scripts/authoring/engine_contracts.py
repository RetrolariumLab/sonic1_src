"""Check edited world data against canonical RAM and retained retail ordering."""

KINDS = {"objects", "chunks256", "layout", "ending_layout"}


def capacities(symbols):
    def slots(first, last, width):
        size = symbols[last] - symbols[first]
        if size <= 0 or size % width:
            raise ValueError("Invalid canonical engine allocation: " + first)
        return size // width

    chunk_size = symbols["chunk_size"]
    if chunk_size != 512:
        raise ValueError("Chunk ABI differs from its 256 block references")
    return dict(
        respawn=slots("v_objstate", "v_objstate_end", 1) - 3,
        blocks=slots("v_16x16", "v_sgfx_buffer", 8),
        chunks=slots("v_256x256", "v_256x256_end", chunk_size),
    )


def validate(model, kind, context, original):
    if kind not in KINDS:
        return
    limits = context.get("engine_capacities")
    if not limits or any(
        type(limits.get(key)) is not int or limits[key] <= 0 for key in ("respawn", "blocks", "chunks")
    ):
        raise ValueError("World content requires canonical engine capacities")
    if kind == "objects":
        rows = model["records"]
        if sum(row["remember"] for row in rows) > min(limits["respawn"], 255):
            raise ValueError("Remember flags exceed the engine respawn allocation")

        def inversions(records):
            return {
                (index, records[index - 1]["x"], row["x"])
                for index, row in enumerate(records)
                if index and row["x"] < records[index - 1]["x"]
            }

        # Verified retail data contains a few descending pairs. Preserve only
        # the exact original pair at its original position; never sort silently.
        if not inversions(rows) <= inversions(original["records"]):
            raise ValueError("Object edit introduces a descending X pair")
    elif kind == "chunks256":
        if any(entry["block"] >= limits["blocks"] for chunk in model for entry in chunk):
            raise ValueError("Chunk block reference exceeds the engine block allocation")
    else:
        rows = model["rows"] if kind == "layout" else model["stored_rows"]

        def targets(value):
            if not value:
                return ()
            normal = (value - 1) & 0x7F
            # FindNearestTile uses the next chunk behind flagged loops,
            # except $A8, whose alternate is chunk $51 (zero-based $50).
            if value & 0x80:
                return normal, 0x50 if value == 0xA8 else value & 0x7F
            return (normal,)

        if any(index >= limits["chunks"] for row in rows for value in row for index in targets(value)):
            raise ValueError("Layout chunk reference exceeds the engine chunk allocation")
