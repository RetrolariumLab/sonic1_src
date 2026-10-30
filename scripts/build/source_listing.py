"""AS include ownership and expanded content events without interpreting CPU bytes."""

from __future__ import annotations
from dataclasses import dataclass, field
from pathlib import Path
import re

ROW = re.compile(r"^(?:\((\d+)\))?\s*(\d+)/\s*([0-9A-F]+)\s*:(.*)$")
EVENT = re.compile(r"\b(mappingsTableEntry\.w|mappingsTable|spriteHeader|dplcHeader|spritePiece)\b")


@dataclass
class Frame:
    path: str
    depth: int
    start: int
    space: str
    children: list[dict] = field(default_factory=list)
    end: int = 0
    storage: dict | None = None


def collect(path: Path, transformed: dict[str, int]) -> dict:
    stack = [Frame("generated-entry", 0, 0, "m68000_rom")]
    frames = []
    events = []
    pending = None
    last = 0

    def close(end):
        frame = stack.pop()
        frame.end = end
        if frame.path in transformed:
            frame.storage = dict(start=frame.start, end=end)
            frame.start = 0
            frame.end = transformed[frame.path]
        frames.append(frame)
        if stack:
            storage = frame.storage or dict(start=frame.start, end=frame.end)
            stack[-1].children.append(dict(path=frame.path, space=frame.space, **storage))

    for line in path.read_text(errors="replace").splitlines():
        match = ROW.match(line)
        if not match:
            continue
        depth = int(match[1] or 0)
        pc = int(match[3], 16) & 0xFFFFFF
        body = match[4].split(";", 1)[0]
        last = pc
        if pending and depth == pending["depth"] + 1:
            space = "z80" if pending["path"] in transformed else stack[-1].space
            stack.append(Frame(pending["path"], depth, pending["start"], space))
        pending = None
        while stack[-1].depth > depth:
            close(pc)
        if stack[-1].depth != depth:
            raise ValueError("AS listing changes include depth without a declared include")
        if "(MACRO)" in body:
            event = EVENT.search(body)
            if event:
                events.append(dict(path=stack[-1].path, address=pc, kind=event[1]))
        include = re.search(r'\binclude\s+"([^"]+)"', body, re.I)
        if include:
            pending = dict(path=include[1], depth=depth, start=pc)
    while stack:
        close(last)
    return dict(frames=frames, events=events)


def exclusive(frame: Frame) -> list[dict]:
    if frame.end < frame.start:
        raise ValueError(f"Backward include region: {frame.path}")
    if frame.start == frame.end:
        return []
    cursor = frame.start
    result = []
    for child in frame.children:
        start, end = child["start"], child["end"]
        if start == end:
            continue
        if start < cursor or end > frame.end:
            raise ValueError(f"Child include crosses or overlaps owner: {frame.path}")
        if start > cursor:
            result.append(dict(address_space=frame.space, start=cursor, end=start, storage_kind="source"))
        cursor = end
    if cursor < frame.end:
        result.append(dict(address_space=frame.space, start=cursor, end=frame.end, storage_kind="source"))
    if frame.storage:
        result.append(
            dict(
                address_space="m68000_rom",
                start=frame.storage["start"],
                end=frame.storage["end"],
                storage_kind="kosinski_code_storage",
            )
        )
    return result


def complete(rows: list[dict], size: int) -> None:
    cursor = 0
    for row in sorted(rows, key=lambda item: item["start"]):
        if row["start"] != cursor or row["end"] <= row["start"]:
            raise ValueError(f"Source ownership gap or overlap at0x{cursor:X}")
        cursor = row["end"]
    if cursor != size:
        raise ValueError(f"Source ownership ends at0x{cursor:X}, expected0x{size:X}")
