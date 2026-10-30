"""Numeric address symbols from AS listings, including sign-extended equates."""

from pathlib import Path
import re

HEADER = re.compile(r"/\s*([0-9A-F]+)\s*:(.*)")
DECLARATION = re.compile(r"^([A-Za-z_][A-Za-z0-9_.]*)(?::|\s+(?:equ|label|=)\b)")


def symbols(path: Path, wanted: set[str]) -> dict[str, int]:
    found = {name: set() for name in wanted}
    for line in path.read_text(errors="replace").splitlines():
        match = HEADER.search(line)
        if not match:
            continue
        value = int(match[1], 16) & 0xFFFFFF
        body = match[2].lstrip()
        annotation = re.match(r"=(?:\$([0-9A-F]+)|([0-9A-F]+)H)\s+", body)
        if annotation:
            value = int(annotation[1] or annotation[2], 16) & 0xFFFFFF
            body = body[annotation.end() :]
        else:
            body = re.sub(r"^\(MACRO\)(?:\[[0-9]+\])?\s*", "", body)
            body = re.sub(r"^(?:(?:[0-9A-F]{8}|[0-9A-F]{4}|[0-9A-F]{2})\s+)+", "", body)
        declaration = DECLARATION.match(body.lstrip())
        if declaration and declaration[1] in found:
            found[declaration[1]].add(value)
    result = {}
    for name, values in found.items():
        if len(values) != 1:
            raise ValueError(f"Listing symbol {name} has {len(values)} distinct definitions")
        result[name] = values.pop()
    return result


def symbol(path: Path, name: str) -> int:
    return symbols(path, {name})[name]
