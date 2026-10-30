"""Fixed-layout S1 SMPS headers, control-flow commands, FM voices and residual spans."""

COMMAND_BYTES = {
    0xE0: 1,
    0xE1: 1,
    0xE2: 1,
    0xE3: 0,
    0xE4: 0,
    0xE5: 1,
    0xE6: 1,
    0xE7: 0,
    0xE8: 1,
    0xE9: 1,
    0xEA: 1,
    0xEB: 1,
    0xEC: 1,
    0xED: 0,
    0xEE: 0,
    0xEF: 1,
    0xF0: 4,
    0xF1: 0,
    0xF2: 0,
    0xF3: 1,
    0xF4: 0,
    0xF5: 1,
    0xF6: 2,
    0xF7: 4,
    0xF8: 2,
    0xF9: 0,
}
VOICE_GROUPS = ("detune_multiple", "rate_attack", "am_decay", "sustain_rate", "sustain_release", "total_level")


def decode(raw: bytes, *, kind: str, profile: str) -> dict:
    if not isinstance(profile, str) or not profile or kind not in ("music", "sfx") or len(raw) < 4:
        raise ValueError("Unsupported SMPS profile, kind or header")

    def word(offset):
        if offset < 0 or offset + 2 > len(raw):
            raise ValueError("SMPS word outside input")
        return int.from_bytes(raw[offset : offset + 2], "big")

    voice_offset = word(0)
    tracks = []
    if kind == "music":
        if len(raw) < 6 or not 1 <= raw[2] <= 7 or not 0 <= raw[3] <= 3:
            raise ValueError("Invalid S1 music channel count")
        header = dict(voice_offset=voice_offset, fm_count=raw[2], psg_count=raw[3], tempo_divider=raw[4], tempo=raw[5])
        cursor = 6
        for index in range(raw[2] + raw[3]):
            psg = index >= raw[2]
            length = 6 if psg else 4
            if cursor + length > len(raw):
                raise ValueError("SMPS channel header truncated")
            tracks.append(
                dict(
                    kind="psg" if psg else ("dac" if index == 0 else "fm"),
                    offset=word(cursor),
                    parameters=list(raw[cursor + 2 : cursor + length]),
                )
            )
            cursor += length
    else:
        if not 1 <= raw[3] <= 7:
            raise ValueError("Invalid S1 effect channel count")
        header = dict(voice_offset=voice_offset, tempo_divider=raw[2], count=raw[3])
        cursor = 4
        for _ in range(raw[3]):
            if cursor + 6 > len(raw):
                raise ValueError("SMPS effect header truncated")
            tracks.append(
                dict(
                    playback=raw[cursor],
                    channel=raw[cursor + 1],
                    offset=word(cursor + 2),
                    parameters=list(raw[cursor + 4 : cursor + 6]),
                )
            )
            cursor += 6
    covered = set(range(cursor))
    nodes = {}
    pending = [item["offset"] for item in tracks]
    while pending:
        offset = pending.pop()
        while offset not in nodes:
            if not cursor <= offset < len(raw):
                raise ValueError(f"SMPS track target outside its stream: {offset}")
            if voice_offset and offset >= voice_offset:
                raise ValueError("SMPS code enters its voice bank")
            opcode = raw[offset]
            if opcode < 0x80:
                size = 1
                name = "duration"
            elif opcode < 0xE0:
                size = 1
                name = "note_or_sample"
            elif opcode in COMMAND_BYTES:
                size = 1 + COMMAND_BYTES[opcode]
                name = "command"
            else:
                raise ValueError(f"Unsupported S1 coordination flag: {opcode:02X}")
            if offset + size > len(raw):
                raise ValueError("SMPS command truncated")
            occupied = set(range(offset, offset + size))
            if covered & occupied:
                raise ValueError("SMPS command overlaps another field")
            covered |= occupied
            node = dict(offset=offset, kind=name, opcode=opcode, arguments=list(raw[offset + 1 : offset + size]))
            if opcode in (0xF6, 0xF7, 0xF8):
                target = offset + size - 1 + int.from_bytes(raw[offset + size - 2 : offset + size], "big", signed=True)
                node["target"] = target
                pending.append(target)
            nodes[offset] = node
            if opcode in (0xE3, 0xE4, 0xEE, 0xF2, 0xF6):
                break
            offset += size
    voices = []
    if voice_offset:
        if not cursor <= voice_offset <= len(raw):
            raise ValueError("SMPS voice bank outside its stream")
        while voice_offset + 25 <= len(raw):
            occupied = set(range(voice_offset, voice_offset + 25))
            if covered & occupied:
                raise ValueError("SMPS voice overlaps track data")
            covered |= occupied
            entry = dict(offset=voice_offset, algorithm_feedback=raw[voice_offset])
            for index, group in enumerate(VOICE_GROUPS):
                entry[group] = list(raw[voice_offset + 1 + index * 4 : voice_offset + 5 + index * 4])
            voices.append(entry)
            voice_offset += 25
    gaps = []
    start = None
    for offset in range(len(raw) + 1):
        if offset < len(raw) and offset not in covered:
            if start is None:
                start = offset
        elif start is not None:
            gaps.append(dict(offset=start, bytes=list(raw[start:offset])))
            start = None
    return dict(
        abi="smps-m68k-type1b",
        profile=profile,
        kind=kind,
        capacity=len(raw),
        header=header,
        tracks=tracks,
        nodes=sorted(nodes.values(), key=lambda x: x["offset"]),
        voices=voices,
        residual_spans=gaps,
    )


def encode(model: dict, *, profile: str, capacity: int) -> bytes:
    if (
        not isinstance(profile, str)
        or not profile
        or model["profile"] != profile
        or model["abi"] != "smps-m68k-type1b"
        or model["capacity"] != capacity
    ):
        raise ValueError("SMPS destination profile/ABI/capacity mismatch")
    out = bytearray(capacity)
    occupied = set()

    def write(offset, values):
        values = bytes(values)
        region = set(range(offset, offset + len(values)))
        if offset < 0 or offset + len(values) > capacity or occupied & region:
            raise ValueError("SMPS write exceeds or overlaps its owner")
        occupied.update(region)
        out[offset : offset + len(values)] = values

    def word(value):
        if not 0 <= value <= 65535:
            raise ValueError("SMPS word exceeds capacity")
        return value.to_bytes(2, "big")

    header = model["header"]
    write(0, word(header["voice_offset"]))
    if model["kind"] == "music":
        write(2, [header["fm_count"], header["psg_count"], header["tempo_divider"], header["tempo"]])
        cursor = 6
        for track in model["tracks"]:
            write(cursor, word(track["offset"]) + bytes(track["parameters"]))
            cursor += 2 + len(track["parameters"])
    elif model["kind"] == "sfx":
        write(2, [header["tempo_divider"], header["count"]])
        cursor = 4
        for track in model["tracks"]:
            write(
                cursor,
                bytes([track["playback"], track["channel"]]) + word(track["offset"]) + bytes(track["parameters"]),
            )
            cursor += 6
    else:
        raise ValueError("Unsupported SMPS stream kind")
    for node in model["nodes"]:
        values = bytes([node["opcode"], *node["arguments"]])
        if node["opcode"] in (0xF6, 0xF7, 0xF8):
            value = node["target"] - (node["offset"] + len(values) - 1)
            if not -32768 <= value <= 32767:
                raise ValueError("SMPS branch exceeds signed word reach")
            values = values[:-2] + value.to_bytes(2, "big", signed=True)
        write(node["offset"], values)
    for voice in model["voices"]:
        write(voice["offset"], [voice["algorithm_feedback"], *(v for group in VOICE_GROUPS for v in voice[group])])
    for span in model["residual_spans"]:
        write(span["offset"], span["bytes"])
    if len(occupied) != capacity:
        raise ValueError("SMPS model does not cover its full owner")
    raw = bytes(out)
    decode(raw, kind=model["kind"], profile=profile)
    return raw
