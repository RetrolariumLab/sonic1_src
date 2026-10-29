"""Bounded Kosinski decoding with the original descriptor refill ordering.

The 68000 decoder reloads its descriptor immediately after consuming bit 16,
before reading that token's bytes. Returned consumption excludes trailing data.
"""
from __future__ import annotations
from dataclasses import dataclass


@dataclass(frozen=True)
class DecodedStream:
    data: bytes
    consumed: int


def decode(data: bytes, *, max_output: int = 1 << 20) -> DecodedStream:
    if max_output < 0:
        raise ValueError("Output bound must be non-negative")
    position = 0

    def byte() -> int:
        nonlocal position
        if position >= len(data):
            raise ValueError("Truncated Kosinski stream")
        value = data[position]
        position += 1
        return value

    descriptor = byte() | byte() << 8
    remaining = 16

    def bit() -> int:
        nonlocal descriptor, remaining
        value = descriptor & 1
        descriptor >>= 1
        remaining -= 1
        if remaining == 0:
            descriptor = byte() | byte() << 8
            remaining = 16
        return value

    output = bytearray()
    while True:
        if bit():
            if len(output) >= max_output:
                raise ValueError("Kosinski output exceeds its capacity")
            output.append(byte())
            continue
        if bit():
            low, high = byte(), byte()
            offset = ((high & 0xF8) << 5 | low) - 0x2000
            count = high & 7
            if count:
                count += 2
            else:
                count = byte()
                if count == 0:
                    return DecodedStream(bytes(output), position)
                if count == 1:
                    continue
                count += 1
        else:
            count = (bit() << 1 | bit()) + 2
            offset = byte() - 0x100
        if -offset > len(output):
            raise ValueError("Kosinski backreference precedes output")
        if len(output) + count > max_output:
            raise ValueError("Kosinski output exceeds its capacity")
        for _ in range(count):
            output.append(output[offset])
