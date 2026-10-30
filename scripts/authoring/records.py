"""Bounded binary records for S1 graphics, world layouts and DAC payloads."""

TILE_FIELDS = (("tile", 11), ("xflip", 1), ("yflip", 1), ("palette", 2), ("priority", 1))
CHUNK_FIELDS = (("block", 11), ("xflip", 1), ("yflip", 1), ("solid_top", 1), ("solid_sides", 1), ("reserved", 1))
DELTAS = (0, 1, 2, 4, 8, 16, 32, 64, 128, 255, 254, 252, 248, 240, 224, 192)


def field_decode(value, fields):
    result = {}
    for name, width in fields:
        result[name] = value & ((1 << width) - 1)
        value >>= width
    return result


def field_encode(value, fields):
    result = 0
    shift = 0
    if set(value) != {name for name, _ in fields}:
        raise ValueError("Record field set differs")
    for name, width in fields:
        if not isinstance(value[name], int) or not 0 <= value[name] < 1 << width:
            raise ValueError("Record field exceeds bit capacity")
        result |= value[name] << shift
        shift += width
    return result


def decode(raw: bytes, kind: str):
    if kind in ("tile_words", "blocks16", "chunks256", "palette"):
        if len(raw) % 2:
            raise ValueError("Word data has an odd byte length")
        values = [int.from_bytes(raw[i : i + 2], "big") for i in range(0, len(raw), 2)]
        if kind == "palette":
            return [dict(red=(v >> 1) & 7, green=(v >> 5) & 7, blue=(v >> 9) & 7, reserved=v & 0xF111) for v in values]
        fields = CHUNK_FIELDS if kind == "chunks256" else TILE_FIELDS
        values = [field_decode(value, fields) for value in values]
        count = {"tile_words": 1, "blocks16": 4, "chunks256": 256}[kind]
        if len(values) % count:
            raise ValueError("Incomplete metatile record")
        return [values[i : i + count] for i in range(0, len(values), count)]
    if kind == "tiles4bpp":
        if len(raw) % 32:
            raise ValueError("Incomplete 8x8 tile")
        pixels = [pixel for value in raw for pixel in (value >> 4, value & 15)]
        return [pixels[i : i + 64] for i in range(0, len(pixels), 64)]
    if kind == "layout":
        if len(raw) < 2:
            raise ValueError("Layout header truncated")
        width, height = raw[0] + 1, raw[1] + 1
        end = 2 + width * height
        if width > 64 or height > 8 or not end <= len(raw) <= end + 1:
            raise ValueError("Layout dimensions exceed S1 plane capacity")
        return dict(
            width=width,
            height=height,
            rows=[list(raw[2 + i * width : 2 + (i + 1) * width]) for i in range(height)],
            padding=list(raw[end:]),
        )
    if kind == "ending_layout":
        if len(raw) != 32 or raw[:2] != bytes((14, 2)):
            raise ValueError("Unknown shortened ending-layout boundary")
        return dict(width=15, declared_height=3, stored_rows=[list(raw[2:17]), list(raw[17:32])], read_beyond_owner=15)
    if kind == "palette_cycle":
        if len(raw) < 2:
            raise ValueError("Palette cycle header truncated")
        count = int.from_bytes(raw[:2], "big") + 1
        if len(raw) != 2 + 6 * count:
            raise ValueError("Palette cycle count crosses its owner")
        rows = [
            dict(
                frames=raw[i] + 1,
                colours=raw[i + 1],
                source=int.from_bytes(raw[i + 2 : i + 4], "big"),
                destination=int.from_bytes(raw[i + 4 : i + 6], "big"),
            )
            for i in range(2, len(raw), 6)
        ]
        if any(not 1 <= row["colours"] <= 16 for row in rows):
            raise ValueError("Palette cycle colour count exceeds one palette line")
        return rows
    if kind == "platform_group":
        if len(raw) < 2:
            raise ValueError("Platform group header truncated")
        count = int.from_bytes(raw[:2], "big") + 1
        end = 2 + count * 6
        if not end <= len(raw) <= end + 6:
            raise ValueError("Platform group count exceeds its owner")
        records = [
            dict(
                x=int.from_bytes(raw[i : i + 2], "big"),
                y=int.from_bytes(raw[i + 2 : i + 4], "big"),
                subtype=int.from_bytes(raw[i + 4 : i + 6], "big"),
            )
            for i in range(2, end, 6)
        ]
        return dict(records=records, trailing=list(raw[end:]))
    if kind == "objects":
        records = []
        offset = 0
        while offset + 2 <= len(raw):
            x = int.from_bytes(raw[offset : offset + 2], "big")
            if x == 65535:
                if len(raw) - offset not in (2, 6):
                    raise ValueError("Object terminator has an unexpected tail")
                return dict(records=records, terminator=list(raw[offset:]))
            if offset + 6 > len(raw):
                raise ValueError("Object record truncated")
            y = int.from_bytes(raw[offset + 2 : offset + 4], "big")
            identity = raw[offset + 4]
            records.append(
                dict(
                    x=x,
                    y=y & 0xFFF,
                    reserved=(y >> 12) & 3,
                    xflip=(y >> 14) & 1,
                    yflip=(y >> 15) & 1,
                    object=identity & 127,
                    remember=identity >> 7,
                    subtype=raw[offset + 5],
                )
            )
            offset += 6
        raise ValueError("Object placement terminator missing")
    if kind == "title_items":
        if len(raw) % 4:
            raise ValueError("Title element record truncated")
        return [
            dict(y=int.from_bytes(raw[i : i + 2], "big"), routine=raw[i + 2], frame=raw[i + 3])
            for i in range(0, len(raw), 4)
        ]
    if kind == "title_positions":
        if len(raw) % 16:
            raise ValueError("Title zone positioning record truncated")
        return [
            [
                dict(
                    start=int.from_bytes(raw[i + j : i + j + 2], "big", signed=True),
                    target=int.from_bytes(raw[i + j + 2 : i + j + 4], "big", signed=True),
                )
                for j in range(0, 16, 4)
            ]
            for i in range(0, len(raw), 16)
        ]
    if kind == "start_position":
        if len(raw) != 4:
            raise ValueError("Start position requires two words")
        return dict(x=int.from_bytes(raw[:2], "big"), y=int.from_bytes(raw[2:], "big"))
    if kind == "collision_heights":
        if len(raw) % 16:
            raise ValueError("Collision height column incomplete")
        return [[value if value < 128 else value - 256 for value in raw[i : i + 16]] for i in range(0, len(raw), 16)]
    if kind == "demo":
        if len(raw) % 2:
            raise ValueError("Demo input pair incomplete")
        return [dict(buttons=raw[i], frames=raw[i + 1] + 1) for i in range(0, len(raw), 2)]
    if kind == "dpcm":
        result = []
        accumulator = 128
        for value in raw:
            for nibble in (value >> 4, value & 15):
                accumulator = (accumulator + DELTAS[nibble]) & 255
                result.append(accumulator)
        return result
    if kind == "psg_envelope":
        if not raw or raw[-1] != 128 or any(value >= 128 for value in raw[:-1]):
            raise ValueError("S1 PSG envelope must end with hold command80")
        return dict(attenuation=list(raw[:-1]), hold=128)
    if kind in ("pcm", "angles", "collision_index", "special_blocks"):
        if kind == "special_blocks" and len(raw) != 4096:
            raise ValueError("Special stage must contain64x64cells")
        return list(raw)
    raise ValueError("Unknown S1 record format")


def encode(model, kind: str, *, capacity: int) -> bytes:
    def byte(value):
        if not isinstance(value, int) or not 0 <= value <= 255:
            raise ValueError("Byte outside capacity")
        return value

    def word(value):
        if not isinstance(value, int) or not 0 <= value <= 65535:
            raise ValueError("Word outside capacity")
        return value.to_bytes(2, "big")

    if kind == "palette":
        result = bytearray()
        for item in model:
            if any(not 0 <= item[key] <= 7 for key in ("red", "green", "blue")) or item["reserved"] & ~0xF111:
                raise ValueError("Palette component outside capacity")
            result.extend(word(item["reserved"] | item["red"] << 1 | item["green"] << 5 | item["blue"] << 9))
        raw = bytes(result)
    elif kind in ("tile_words", "blocks16", "chunks256"):
        count = {"tile_words": 1, "blocks16": 4, "chunks256": 256}[kind]
        fields = CHUNK_FIELDS if kind == "chunks256" else TILE_FIELDS
        if any(len(group) != count for group in model):
            raise ValueError("Metatile shape differs")
        raw = b"".join(word(field_encode(item, fields)) for group in model for item in group)
    elif kind == "tiles4bpp":
        if any(len(tile) != 64 or any(not 0 <= pixel <= 15 for pixel in tile) for tile in model):
            raise ValueError("Tile shape or pixel outside4bppcapacity")
        raw = bytes(tile[i] << 4 | tile[i + 1] for tile in model for i in range(0, 64, 2))
    elif kind == "layout":
        width, height = model["width"], model["height"]
        if (
            not 1 <= width <= 64
            or not 1 <= height <= 8
            or len(model["rows"]) != height
            or any(len(row) != width for row in model["rows"])
        ):
            raise ValueError("Layout shape exceeds plane capacity")
        if len(model["padding"]) > 1:
            raise ValueError("Layout padding exceeds alignment")
        raw = bytes(
            [
                width - 1,
                height - 1,
                *[byte(v) for row in model["rows"] for v in row],
                *[byte(v) for v in model["padding"]],
            ]
        )
    elif kind == "ending_layout":
        if (
            model["width"] != 15
            or model["declared_height"] != 3
            or model["read_beyond_owner"] != 15
            or len(model["stored_rows"]) != 2
            or any(len(row) != 15 for row in model["stored_rows"])
        ):
            raise ValueError("Changing shortened layout dimensions would cross its owner")
        raw = bytes([14, 2, *[byte(v) for row in model["stored_rows"] for v in row]])
    elif kind == "palette_cycle":
        if not 1 <= len(model) <= 65536 or any(
            not 1 <= row["frames"] <= 256 or not 1 <= row["colours"] <= 16 for row in model
        ):
            raise ValueError("Palette cycle fields exceed their ABI")
        raw = word(len(model) - 1) + b"".join(
            bytes([row["frames"] - 1, row["colours"]]) + word(row["source"]) + word(row["destination"]) for row in model
        )
    elif kind == "platform_group":
        if not 1 <= len(model["records"]) <= 65536 or len(model["trailing"]) > 6:
            raise ValueError("Platform count or tail outside capacity")
        raw = (
            word(len(model["records"]) - 1)
            + b"".join(word(row["x"]) + word(row["y"]) + word(row["subtype"]) for row in model["records"])
            + bytes(model["trailing"])
        )
    elif kind == "objects":
        result = bytearray()
        for item in model["records"]:
            if (
                not 0 <= item["x"] < 65535
                or not 0 <= item["y"] <= 4095
                or not 0 <= item["reserved"] <= 3
                or item["xflip"] not in (0, 1)
                or item["yflip"] not in (0, 1)
                or not 0 <= item["object"] <= 127
                or item["remember"] not in (0, 1)
            ):
                raise ValueError("Object field outside capacity")
            result.extend(
                word(item["x"])
                + word(item["y"] | item["reserved"] << 12 | item["xflip"] << 14 | item["yflip"] << 15)
                + bytes([item["object"] | item["remember"] << 7, byte(item["subtype"])])
            )
        raw = bytes(result) + bytes(model["terminator"])
    elif kind == "title_items":
        raw = b"".join(word(item["y"]) + bytes([byte(item["routine"]), byte(item["frame"])]) for item in model)
    elif kind == "title_positions":
        if any(len(row) != 4 for row in model) or any(
            not -32768 <= item[key] <= 32767 for row in model for item in row for key in ("start", "target")
        ):
            raise ValueError("Title zone shape or signed position outside capacity")
        raw = b"".join(word(item["start"] & 65535) + word(item["target"] & 65535) for row in model for item in row)
    elif kind == "start_position":
        raw = word(model["x"]) + word(model["y"])
    elif kind == "collision_heights":
        if any(len(row) != 16 or any(not -16 <= v <= 16 for v in row) for row in model):
            raise ValueError("Collision height outside16-pixelblock")
        raw = bytes(v & 255 for row in model for v in row)
    elif kind == "demo":
        if any(not 1 <= row["frames"] <= 256 for row in model):
            raise ValueError("Demo duration outside byte capacity")
        raw = bytes(v for row in model for v in (byte(row["buttons"]), row["frames"] - 1))
    elif kind == "dpcm":
        if len(model) % 2:
            raise ValueError("DPCM output needs two samples per byte")
        reverse = {v: i for i, v in enumerate(DELTAS)}
        nibbles = []
        accumulator = 128
        for sample in model:
            value = byte(sample)
            delta = (value - accumulator) & 255
            if delta not in reverse:
                raise ValueError("Waveform step is not representable by S1 DPCM")
            nibbles.append(reverse[delta])
            accumulator = value
        raw = bytes(nibbles[i] << 4 | nibbles[i + 1] for i in range(0, len(nibbles), 2))
    elif kind == "psg_envelope":
        if model["hold"] != 128 or any(not 0 <= v < 128 for v in model["attenuation"]):
            raise ValueError("PSG envelope command outside S1 ABI")
        raw = bytes([*model["attenuation"], 128])
    elif kind in ("pcm", "angles", "collision_index", "special_blocks"):
        raw = bytes(byte(v) for v in model)
    else:
        raise ValueError("Unknown S1 record format")
    if len(raw) > capacity:
        raise ValueError("Encoded content exceeds its owned slot")
    decode(raw, kind)
    return raw
