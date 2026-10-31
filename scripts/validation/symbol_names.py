"""Reject address-generated assembler names and validate the canonical rename registry."""

import argparse
from collections import Counter
import json
import re
from scripts.build.project import ROOT, atomic_write, load
from scripts.build.sources import source_paths

ADDRESS_NAME = re.compile(
    r"z?(?:loc(?:ret)?|bra|sub|unk|byte|word|dword|off|nullsub|asc|stru|jpt|def|code|data)_[0-9a-f]+",
    re.IGNORECASE,
)
GLOBAL_NAME = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
TOKEN = re.compile(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|;[^\n]*|(?P<name>[A-Za-z_.$?@][A-Za-z0-9_.$?@]*)')


def identifiers(line: str) -> list[str]:
    return [
        re.sub(r"\.(?:b|w|l)$", "", match["name"], flags=re.IGNORECASE)
        for match in TOKEN.finditer(line)
        if match["name"]
    ]


def audit(sources: dict[str, str], registry: dict | None = None) -> dict:
    findings, definitions, used = [], Counter(), set()
    for path, text in sources.items():
        for number, line in enumerate(text.splitlines(), 1):
            names = identifiers(line)
            used.update(name.lower() for name in names)
            for name in names:
                if ADDRESS_NAME.fullmatch(name.lstrip(".?@")):
                    findings.append(dict(path=path, line=number, name=name))
            declaration = re.match(r"^\s*([A-Za-z_][A-Za-z0-9_]*):", line)
            if declaration:
                definitions[path, declaration[1].lower()] += 1
    if findings:
        raise ValueError("Address-generated symbol names: " + json.dumps(findings))
    count = 0
    if registry is not None:
        if (
            not isinstance(registry, dict)
            or registry.get("schema_version") != 1
            or not isinstance(registry.get("baseline"), dict)
            or not registry["baseline"].get("repository")
            or not re.fullmatch(r"[0-9a-f]{40}", registry["baseline"].get("commit", ""))
            or not isinstance(registry.get("renames"), list)
            or not isinstance(registry.get("project_additions"), list)
        ):
            raise ValueError("Invalid label rename registry schema or baseline")
        old_names, new_names = set(), set()
        for row in registry["renames"]:
            if not isinstance(row, dict) or any(
                not isinstance(row.get(key), str) or not row[key].strip() for key in ("old", "new", "path", "reason")
            ):
                raise ValueError("Rename needs old/new names, a source path and a reason")
            old, new = row["old"].lower(), row["new"].lower()
            if (
                not GLOBAL_NAME.fullmatch(row["old"])
                or not GLOBAL_NAME.fullmatch(row["new"])
                or old == new
                or old in old_names
                or new in new_names
                or old in new_names
                or new in old_names
                or ADDRESS_NAME.fullmatch(new)
            ):
                raise ValueError("Invalid, duplicate or chained label rename")
            old_names.add(old)
            new_names.add(new)
            if old in used:
                raise ValueError("Renamed symbol remains active: " + row["old"])
            if (
                row["path"] not in sources
                or definitions[row["path"], new] != 1
                or sum(total for (_, name), total in definitions.items() if name == new) != 1
            ):
                raise ValueError("Renamed symbol must have one definition in its registered owner: " + row["new"])
        for row in registry["project_additions"]:
            if (
                not isinstance(row, dict)
                or not all(isinstance(row.get(key), str) and row[key].strip() for key in ("name", "path", "reason"))
                or row["path"] not in sources
                or definitions[row["path"], row["name"].lower()] != 1
            ):
                raise ValueError("Added boundary label is missing or invalid")
        count = len(registry["renames"])
    return dict(schema_version=1, source_files=len(sources), address_name_findings=[], registered_renames=count)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.parse_args()
    try:
        sources = {path.as_posix(): (ROOT / path).read_text() for path in source_paths()}
        report = audit(sources, load("config/reconstruction/label_renames.json"))
    except (OSError, ValueError, KeyError, TypeError) as error:
        parser.exit(1, f"error: {error}\n")
    atomic_write(ROOT / "build/audits/symbol-names.json", (json.dumps(report, indent=2) + "\n").encode())
    print(f"[OK] Symbol names: {report['source_files']} sources, {report['registered_renames']} audited renames")
    return 0
