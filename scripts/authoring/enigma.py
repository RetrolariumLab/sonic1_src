"""Lossless S1 Enigma packets, translated from the original EniDec bit contract."""

from dataclasses import dataclass


@dataclass(frozen=True)
class Inline:
    attributes: tuple[int, ...]
    tile: int


@dataclass(frozen=True)
class Packet:
    mode: int
    repeat: int
    values: tuple[Inline, ...]


@dataclass(frozen=True)
class Document:
    tile_bits: int
    flags: int
    increment: int
    common: int
    packets: tuple[Packet, ...]
    padding: tuple[int, ...]
    trailing: bytes


class Bits:
    def __init__(self, data: bytes, position: int = 0):
        self.data = data
        self.position = position

    def read(self, count: int) -> int:
        if count < 0 or self.position + count > len(self.data) * 8:
            raise ValueError("Truncated Enigma bitstream")
        value = 0
        for _ in range(count):
            value = value * 2 + ((self.data[self.position // 8] >> (7 - self.position % 8)) & 1)
            self.position += 1
        return value


def decode(data: bytes, *, max_output: int = 65536) -> Document:
    if len(data) < 8 or not 1 <= data[0] <= 16 or data[1] & ~31:
        raise ValueError("Invalid Enigma header")
    bits = Bits(data, 48)
    width, flags = data[:2]
    packets = []
    count = 0

    def inline() -> Inline:
        return Inline(tuple(bits.read(1) for shift in range(4, -1, -1) if flags & (1 << shift)), bits.read(width))

    while True:
        mode = bits.read(1)
        mode = bits.read(1) if mode == 0 else 4 + bits.read(2)
        repeat = bits.read(4)
        if mode == 7 and repeat == 15:
            break
        count += 2 * (repeat + 1)
        if count > max_output:
            raise ValueError("Enigma decoded content exceeds capacity")
        values = tuple(inline() for _ in range(repeat + 1 if mode == 7 else 1)) if mode >= 4 else ()
        packets.append(Packet(mode, repeat, values))
    aligned = ((bits.position + 15) // 16) * 16
    padding = tuple(bits.read(1) for _ in range(aligned - bits.position))
    return Document(
        width,
        flags,
        int.from_bytes(data[2:4], "big"),
        int.from_bytes(data[4:6], "big"),
        tuple(packets),
        padding,
        data[aligned // 8 :],
    )


def encode(doc: Document) -> bytes:
    if (
        not 1 <= doc.tile_bits <= 16
        or not 0 <= doc.flags <= 31
        or not 0 <= doc.increment <= 65535
        or not 0 <= doc.common <= 65535
    ):
        raise ValueError("Enigma header outside its bit fields")
    bits = []

    def put(value: int, width: int):
        if not 0 <= value < 1 << width:
            raise ValueError("Enigma field outside capacity")
        bits.extend((value >> shift) & 1 for shift in range(width - 1, -1, -1))

    total = 0
    for packet in doc.packets:
        if packet.mode not in (0, 1, 4, 5, 6, 7) or not 0 <= packet.repeat <= (14 if packet.mode == 7 else 15):
            raise ValueError("Invalid Enigma packet")
        total += 2 * (packet.repeat + 1)
        if total > 65536:
            raise ValueError("Enigma output exceeds its address space")
        put(packet.mode, 2 if packet.mode < 4 else 3)
        put(packet.repeat, 4)
        count = packet.repeat + 1 if packet.mode == 7 else (1 if packet.mode >= 4 else 0)
        if len(packet.values) != count:
            raise ValueError("Enigma packet inline count differs")
        for inline in packet.values:
            if len(inline.attributes) != doc.flags.bit_count():
                raise ValueError("Enigma attribute count differs")
            for flag in inline.attributes:
                put(flag, 1)
            put(inline.tile, doc.tile_bits)
    put(0x7F, 7)
    padding_count = (-len(bits)) % 16
    if len(doc.padding) != padding_count:
        raise ValueError("Enigma alignment does not match packet lengths")
    for bit in doc.padding:
        put(bit, 1)
    body = bytes(sum(bits[index + shift] << (7 - shift) for shift in range(8)) for index in range(0, len(bits), 8))
    return (
        bytes((doc.tile_bits, doc.flags))
        + doc.increment.to_bytes(2, "big")
        + doc.common.to_bytes(2, "big")
        + body
        + doc.trailing
    )


def words(doc: Document, *, base_tile: int = 0, max_output: int = 65536) -> bytes:
    if not 0 <= base_tile <= 65535:
        raise ValueError("Base tile outside 16-bit capacity")
    out = bytearray()
    increment = (doc.increment + base_tile) & 65535
    common = (doc.common + base_tile) & 65535

    def inline(item: Inline):
        value = base_tile
        index = 0
        for shift, mask in ((4, 0x8000), (3, 0x4000), (2, 0x2000), (1, 0x1000), (0, 0x800)):
            if doc.flags & (1 << shift):
                flag = item.attributes[index]
                index += 1
                if flag:
                    value = value + mask if shift in (3, 2) else value | mask
        return (value + item.tile) & 65535

    for packet in doc.packets:
        count = packet.repeat + 1
        if len(out) + count * 2 > max_output:
            raise ValueError("Enigma output exceeds destination capacity")
        if packet.mode == 0:
            values = [(increment + index) & 65535 for index in range(count)]
            increment = (increment + count) & 65535
        elif packet.mode == 1:
            values = [common] * count
        elif packet.mode == 7:
            values = [inline(item) for item in packet.values]
        else:
            first = inline(packet.values[0])
            step = {4: 0, 5: 1, 6: -1}[packet.mode]
            values = [(first + step * index) & 65535 for index in range(count)]
        for value in values:
            out.extend(value.to_bytes(2, "big"))
    return bytes(out)
