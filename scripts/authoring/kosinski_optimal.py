"""Kosinski optimal token parsing over bounded LZ match candidates."""

from collections import defaultdict, deque
from itertools import islice


def encode(plain: bytes, *, capacity: int | None = None) -> bytes:
    if len(plain) > 65536:
        raise ValueError("Kosinski content exceeds one64KiBdestination")
    size = len(plain)
    long_length = [0] * size
    long_distance = [0] * size
    short_length = [0] * size
    short_distance = [0] * size
    positions = defaultdict(deque)
    for at in range(size - 1):
        candidates = positions[plain[at : at + 2]]
        while candidates and candidates[0] < at - 8192:
            candidates.popleft()
        maximum = min(256, size - at)
        for previous in islice(reversed(candidates), 256):
            distance = at - previous
            length = 2
            while length < maximum and plain[previous + length] == plain[at + length]:
                length += 1
            if length > long_length[at]:
                long_length[at] = length
                long_distance[at] = distance
            if distance <= 256 and min(length, 5) > short_length[at]:
                short_length[at] = min(length, 5)
                short_distance[at] = distance
            if long_length[at] == maximum and short_length[at] == min(5, maximum):
                break
        candidates.append(at)
    costs = [0] * (size + 1)
    costs[size] = 26
    tokens = [None] * size
    for at in range(size - 1, -1, -1):
        cost = 9 + costs[at + 1]
        choice = ("literal", 0, 1)
        for count in range(2, short_length[at] + 1):
            value = 12 + costs[at + count]
            if value < cost:
                cost = value
                choice = ("short", short_distance[at], count)
        for count in range(3, long_length[at] + 1):
            value = (18 if count <= 9 else 26) + costs[at + count]
            if value < cost:
                cost = value
                choice = ("long", long_distance[at], count)
        costs[at] = cost
        tokens[at] = choice
    out = bytearray(2)
    descriptor = 0
    bit = 0

    def flag(value):
        nonlocal descriptor, bit
        if value:
            out[descriptor + bit // 8] |= 1 << (bit % 8)
        bit += 1
        if bit == 16:
            descriptor = len(out)
            out.extend(b"\0\0")
            bit = 0

    at = 0
    while at < size:
        kind, distance, count = tokens[at]
        if kind == "literal":
            flag(1)
            out.append(plain[at])
        else:
            flag(0)
            if kind == "short":
                flag(0)
                length = count - 2
                flag((length >> 1) & 1)
                flag(length & 1)
                out.append((-distance) & 255)
            else:
                flag(1)
                offset = 8192 - distance
                high = (offset >> 5) & 248
                if count <= 9:
                    high |= count - 2
                out.extend((offset & 255, high))
                if count >= 10:
                    out.append(count - 1)
        at += count
    flag(0)
    flag(1)
    out.extend(b"\0\0\0")
    if capacity is not None and len(out) > capacity:
        raise ValueError("Encoded Kosinski content exceeds its owned compressed slot")
    return bytes(out)
