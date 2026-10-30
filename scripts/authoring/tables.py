"""Fixed-slot mapping/DPLC frames and animation tables, with shared-byte checks."""

from scripts.authoring.records import field_decode, field_encode, TILE_FIELDS


def residual(raw, covered):
    spans = []
    start = None
    for offset in range(len(raw) + 1):
        if offset < len(raw) and offset not in covered:
            if start is None:
                start = offset
        elif start is not None:
            spans.append(dict(offset=start, bytes=list(raw[start:offset])))
            start = None
    return spans


def decode_mapping(raw: bytes, events: list[dict], *, profile: str) -> dict:
    tables = []
    frames = []
    seen = set()
    covered = set()
    base = None

    def region(start, size):
        if start < 0 or start + size > len(raw):
            raise ValueError("Mapping field crosses its owner")
        covered.update(range(start, start + size))

    for event in events:
        offset = event["offset"]
        kind = event["kind"]
        if kind == "mappingsTable":
            base = offset
            tables.append(dict(offset=base, entries=[]))
        elif kind == "mappingsTableEntry.w":
            if base is None:
                raise ValueError("Mapping pointer has no table base")
            region(offset, 2)
            target = base + int.from_bytes(raw[offset : offset + 2], "big", signed=True)
            tables[-1]["entries"].append(dict(offset=offset, target=target))
        elif kind in ("spriteHeader", "dplcHeader"):
            if (offset, kind) in seen:
                continue
            seen.add((offset, kind))
            region(offset, 1)
            count = raw[offset]
            width = 5 if kind == "spriteHeader" else 2
            region(offset + 1, count * width)
            pieces = []
            for index in range(count):
                at = offset + 1 + index * width
                if kind == "spriteHeader":
                    y, size, high, low, x = raw[at : at + 5]
                    pieces.append(
                        dict(
                            x=x if x < 128 else x - 256,
                            y=y if y < 128 else y - 256,
                            width=((size >> 2) & 3) + 1,
                            height=(size & 3) + 1,
                            reserved=size >> 4,
                            pattern=field_decode(high * 256 + low, TILE_FIELDS),
                        )
                    )
                else:
                    value = int.from_bytes(raw[at : at + 2], "big")
                    pieces.append(dict(tiles=(value >> 12) + 1, source_tile=value & 4095))
            frames.append(dict(offset=offset, kind=kind, pieces=pieces))
    known_frames = {frame["offset"] for frame in frames}
    aliases = set()
    for table in tables:
        for entry in table["entries"]:
            target = entry["target"]
            if target in known_frames:
                continue
            if not 0 <= target < len(raw) or raw[target] != 0:
                raise ValueError("Mapping target is neither a frame nor an explicit blank-byte alias")
            aliases.add(target)
            region(target, 1)
    detached = []
    for event in events:
        offset = event["offset"]
        if event["kind"] != "spritePiece" or offset in covered:
            continue
        region(offset, 5)
        y, size, high, low, x = raw[offset : offset + 5]
        piece = dict(
            x=x if x < 128 else x - 256,
            y=y if y < 128 else y - 256,
            width=((size >> 2) & 3) + 1,
            height=(size & 3) + 1,
            reserved=size >> 4,
            pattern=field_decode(high * 256 + low, TILE_FIELDS),
        )
        detached.append(dict(offset=offset, piece=piece))
    return dict(
        abi="sonic1-mapping-v1",
        profile=profile,
        capacity=len(raw),
        tables=tables,
        frames=frames,
        blank_aliases=sorted(aliases),
        detached_pieces=detached,
        residual_spans=residual(raw, covered),
    )


def writer(capacity):
    out = bytearray(capacity)
    written = {}

    def put(offset, data):
        data = bytes(data)
        if offset < 0 or offset + len(data) > capacity:
            raise ValueError("Table write crosses owned capacity")
        for index, value in enumerate(data, offset):
            if index in written and written[index] != value:
                raise ValueError("Shared frame edits disagree on one byte")
            written[index] = value
            out[index] = value

    def finish():
        if len(written) != capacity:
            raise ValueError("Table model leaves unknown bytes unowned")
        return bytes(out)

    return put, finish


def encode_mapping(model: dict, *, profile: str, capacity: int) -> bytes:
    if (
        model["abi"] != "sonic1-mapping-v1"
        or model["profile"] != profile
        or not isinstance(profile, str)
        or not profile
        or capacity != model["capacity"]
    ):
        raise ValueError("Mapping destination ABI/profile/capacity differs")
    put, finish = writer(capacity)
    valid = {frame["offset"] for frame in model["frames"]} | set(model["blank_aliases"])
    for alias in model["blank_aliases"]:
        put(alias, [0])
    for table in model["tables"]:
        for entry in table["entries"]:
            if entry["target"] not in valid:
                raise ValueError("Mapping pointer has no declared frame or blank alias")
            distance = entry["target"] - table["offset"]
            if not -32768 <= distance <= 32767:
                raise ValueError("Mapping pointer exceeds signed16 reach")
            put(entry["offset"], distance.to_bytes(2, "big", signed=True))
    for frame in model["frames"]:
        if len(frame["pieces"]) > 255:
            raise ValueError("Mapping frame exceeds byte piece count")
        put(frame["offset"], [len(frame["pieces"])])
        cursor = frame["offset"] + 1
        for piece in frame["pieces"]:
            if frame["kind"] == "spriteHeader":
                if (
                    not -128 <= piece["x"] <= 127
                    or not -128 <= piece["y"] <= 127
                    or not 1 <= piece["width"] <= 4
                    or not 1 <= piece["height"] <= 4
                    or not 0 <= piece["reserved"] <= 15
                ):
                    raise ValueError("Sprite piece exceeds S1 fields")
                pattern = field_encode(piece["pattern"], TILE_FIELDS)
                values = [
                    piece["y"] & 255,
                    piece["reserved"] << 4 | (piece["width"] - 1) << 2 | piece["height"] - 1,
                    pattern >> 8,
                    pattern & 255,
                    piece["x"] & 255,
                ]
            elif frame["kind"] == "dplcHeader":
                if not 1 <= piece["tiles"] <= 16 or not 0 <= piece["source_tile"] <= 4095:
                    raise ValueError("DPLC entry exceeds nibble/12-bitcapacity")
                value = (piece["tiles"] - 1) << 12 | piece["source_tile"]
                values = value.to_bytes(2, "big")
            else:
                raise ValueError("Unknown mapping frame ABI")
            put(cursor, values)
            cursor += len(values)
    for entry in model["detached_pieces"]:
        piece = entry["piece"]
        if (
            not -128 <= piece["x"] <= 127
            or not -128 <= piece["y"] <= 127
            or not 1 <= piece["width"] <= 4
            or not 1 <= piece["height"] <= 4
            or not 0 <= piece["reserved"] <= 15
        ):
            raise ValueError("Detached sprite piece exceeds S1 fields")
        pattern = field_encode(piece["pattern"], TILE_FIELDS)
        put(
            entry["offset"],
            [
                piece["y"] & 255,
                piece["reserved"] << 4 | (piece["width"] - 1) << 2 | piece["height"] - 1,
                pattern >> 8,
                pattern & 255,
                piece["x"] & 255,
            ],
        )
    for span in model["residual_spans"]:
        put(span["offset"], span["bytes"])
    return finish()


def decode_animation(raw: bytes, *, profile: str, special_player: bool = False) -> dict:
    if len(raw) < 3:
        raise ValueError("Animation table truncated")
    minimum = int.from_bytes(raw[:2], "big")
    entries = []
    offset = 0
    while offset < minimum:
        if offset + 2 > len(raw):
            raise ValueError("Animation index truncated")
        target = int.from_bytes(raw[offset : offset + 2], "big")
        minimum = min(minimum, target)
        entries.append(target)
        offset += 2
    if offset != minimum or minimum < 2 or any(not minimum <= target < len(raw) for target in entries):
        raise ValueError("Animation index crosses frame data")
    frames = []
    covered = set(range(offset))
    for start in sorted(set(entries)):
        at = start + 1
        tokens = []
        if special_player and raw[start] >= 128:
            if start + 8 > len(raw) or raw[start + 7] != 255:
                raise ValueError("Player locomotion animation needs six slots and end")
            covered.update(range(start, start + 8))
            frames.append(
                dict(
                    offset=start,
                    delay=raw[start],
                    special_slots=list(raw[start + 1 : start + 7]),
                    terminal=dict(opcode=255, arguments=[]),
                )
            )
            continue
        while True:
            if at >= len(raw):
                raise ValueError("Animation script has no terminal command")
            opcode = raw[at]
            at += 1
            if opcode < 0xFA:
                tokens.append(opcode)
                continue
            arguments = []
            if opcode in (0xFD, 0xFE):
                if at >= len(raw):
                    raise ValueError("Animation command argument missing")
                arguments = [raw[at]]
                at += 1
            terminal = dict(opcode=opcode, arguments=arguments)
            break
        covered.update(range(start, at))
        frames.append(dict(offset=start, delay=raw[start], frames=tokens, terminal=terminal))
    return dict(
        abi="sonic1-animation",
        profile=profile,
        capacity=len(raw),
        entries=entries,
        scripts=frames,
        special_player=special_player,
        residual_spans=residual(raw, covered),
    )


def encode_animation(model: dict, *, profile: str, capacity: int) -> bytes:
    if (
        model["abi"] != "sonic1-animation"
        or model["profile"] != profile
        or not isinstance(profile, str)
        or not profile
        or capacity != model["capacity"]
    ):
        raise ValueError("Animation destination profile/ABI/capacity differs")
    put, finish = writer(capacity)
    valid = {script["offset"] for script in model["scripts"]}
    for index, target in enumerate(model["entries"]):
        if target not in valid:
            raise ValueError("Animation index has no declared script")
        if not 0 <= target <= 65535:
            raise ValueError("Animation pointer exceeds word capacity")
        put(index * 2, target.to_bytes(2, "big"))
    for script in model["scripts"]:
        end = script["terminal"]
        code = end["opcode"]
        if "special_slots" in script:
            if (
                not model["special_player"]
                or script["delay"] < 128
                or len(script["special_slots"]) != 6
                or end != dict(opcode=255, arguments=[])
            ):
                raise ValueError("Invalid fixed player locomotion script")
            put(script["offset"], [script["delay"], *script["special_slots"], 255])
            continue
        if (
            not 0xFA <= code <= 0xFF
            or len(end["arguments"]) != (1 if code in (0xFD, 0xFE) else 0)
            or any(not 0 <= frame < 0xFA for frame in script["frames"])
        ):
            raise ValueError("Animation command outside S1 ABI")
        if any(frame >= 128 for frame in script["frames"]):
            raise ValueError("Negative frame bytes are control flags, not display frames")
        if code == 0xFD and end["arguments"][0] >= len(model["entries"]):
            raise ValueError("Animation change targets another table allocation")
        if code == 0xFE and not 1 <= end["arguments"][0] <= len(script["frames"]):
            raise ValueError("Animation rewind crosses its script")
        put(script["offset"], [script["delay"], *script["frames"], code, *end["arguments"]])
    for span in model["residual_spans"]:
        put(span["offset"], span["bytes"])
    raw = finish()
    decode_animation(raw, profile=profile, special_player=model["special_player"])
    return raw
