"""Profile-bound content documents and checked storage encoding without a GUI."""

from __future__ import annotations
from dataclasses import replace
from scripts.authoring import records, tables, enigma, smps, kosinski_optimal, core_codec
from scripts.authoring.kosinski import decode as kos_decode
from scripts.build.project import profile, sha256


def unpack(raw: bytes, compression: str | None, capacity: int) -> bytes:
    if compression == "nemesis":
        plain = core_codec.decode(raw)
    elif compression == "kosinski":
        plain = kos_decode(raw, max_output=capacity).data
    elif compression == "enigma":
        plain = enigma.words(enigma.decode(raw, max_output=capacity), max_output=capacity)
    elif compression is None:
        plain = raw
    else:
        raise ValueError("Unknown compression transport")
    if len(plain) != capacity:
        raise ValueError("Decoded allocation differs from the content owner")
    return plain


def model_decode(plain: bytes, item: dict, context: dict):
    kind = item["codec"]
    owner_profile = item["profile"]
    if kind == "mapping_dplc":
        return tables.decode_mapping(plain, context["events"], profile=owner_profile)
    if kind == "animation":
        return tables.decode_animation(
            plain, profile=owner_profile, special_player=item["source"]["path"].endswith("/Sonic.asm")
        )
    if kind == "smps":
        return smps.decode(plain, kind=item["source"]["path"].split("/")[2], profile=owner_profile)
    if kind == "assembled_driver_transport":
        return dict(decoded_sha256=sha256(plain), bytes=len(plain), editable=False)
    model = records.decode(plain, kind)
    if kind == "palette_cycle":
        for row in model:
            if not any(
                start <= row["source"] and row["source"] + 2 * row["colours"] <= end
                for start, end in context["source_palettes"]
            ):
                raise ValueError("Palette cycle read crosses its source palette")
            if (
                row["source"] % 2
                or row["destination"] % 2
                or not context["palette_ram"][0] <= row["destination"] < context["palette_ram"][1]
            ):
                raise ValueError("Palette cycle destination crosses palette RAM")
    return model


def model_encode(model, item: dict, context: dict, reference: bytes) -> bytes:
    kind = item["codec"]
    capacity = item["decoded_capacity"]
    owner_profile = item["profile"]
    if kind == "mapping_dplc":
        result = tables.encode_mapping(model, profile=owner_profile, capacity=capacity)
    elif kind == "animation":
        result = tables.encode_animation(model, profile=owner_profile, capacity=capacity)
    elif kind == "smps":
        result = smps.encode(model, profile=owner_profile, capacity=capacity)
    elif kind == "assembled_driver_transport":
        if model != dict(decoded_sha256=sha256(reference), bytes=len(reference), editable=False):
            raise ValueError("Executable driver must be edited in its assembler source")
        result = reference
    else:
        result = records.encode(model, kind, capacity=capacity)
    # Fixed preservation allocations cannot shrink and expose adjacent bytes.
    if len(result) != capacity:
        raise ValueError("Content must fill its fixed decoded allocation")
    model_decode(result, item, context)
    return result


def decode(raw: bytes, item: dict, context: dict) -> dict:
    profile(item["profile"])
    plain = unpack(raw, item.get("compression"), item["decoded_capacity"])
    return dict(
        schema_version=1,
        abi=item["abi"],
        profile=item["profile"],
        owner=item["id"],
        codec=item["codec"],
        address_space=item["address_space"],
        encoded_capacity=context["slot"],
        decoded_capacity=len(plain),
        reference_sha256=sha256(raw),
        model=model_decode(plain, item, context),
    )


def literal_enigma(plain: bytes) -> bytes:
    if len(plain) % 2:
        raise ValueError("Enigma words must have an even length")
    values = [int.from_bytes(plain[i : i + 2], "big") for i in range(0, len(plain), 2)]
    inline = lambda value: enigma.Inline(tuple((value >> shift) & 1 for shift in (15, 14, 13, 12, 11)), value & 2047)
    packets = tuple(
        enigma.Packet(7, len(values[i : i + 15]) - 1, tuple(inline(v) for v in values[i : i + 15]))
        for i in range(0, len(values), 15)
    )
    bits = 7 + sum(7 + 16 * len(packet.values) for packet in packets)
    doc = enigma.Document(11, 31, 0, 0, packets, (0,) * ((-bits) % 16), b"")
    return enigma.encode(doc)


def encode(document: dict, raw: bytes, item: dict, context: dict, *, destination_profile: str) -> tuple[bytes, dict]:
    profile(destination_profile)
    baseline = decode(raw, item, context)
    if (
        destination_profile != item["profile"]
        or set(document) != set(baseline)
        or any(document[key] != baseline[key] for key in baseline if key != "model")
    ):
        raise ValueError("Content destination ABI/profile/owner/capacity/reference differs")
    original = unpack(raw, item.get("compression"), item["decoded_capacity"])
    plain = model_encode(document["model"], item, context, original)
    compression = item.get("compression")
    if compression == "nemesis":
        packed = core_codec.encode(plain, raw)
    elif compression == "kosinski":
        packed = kosinski_optimal.encode(plain)
    elif compression == "enigma":
        packed = enigma.encode(enigma.decode(raw)) if plain == original else literal_enigma(plain)
    else:
        packed = plain
    if unpack(packed, compression, len(plain)) != plain:
        raise ValueError("Encoder failed semantic re-decoding")
    unchanged = plain == original
    # Genuine re-encoding is proven before choosing original unchanged storage.
    storage = raw if unchanged else packed
    if len(storage) > context["slot"]:
        raise ValueError("Encoded edit exceeds its owned storage slot")
    if not unchanged and len(storage) < context["slot"]:
        if compression is None:
            raise ValueError("Uncompressed edit shrank its fixed allocation")
        storage += raw[len(storage) :]  # Explicit unread slot tail, never a neighbour.
    return storage, dict(
        unchanged=unchanged,
        byte_exact=storage == raw,
        semantic=True,
        genuine_encoded_size=len(packed),
        genuine_encoded_sha256=sha256(packed),
        genuine_encoding_exact=packed == raw,
        decoded_sha256=sha256(plain),
        retained_original=unchanged and packed != raw,
    )
