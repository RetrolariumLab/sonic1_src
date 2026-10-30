"""Audit numeric address operands and classify the remaining scalar command words."""

from __future__ import annotations
import argparse
from collections import Counter
import json
import re
from scripts.build.project import ROOT, atomic_write, load
from scripts.validation.lint_project import source_paths

LITERAL = re.compile(r"\$[0-9A-Fa-f]+|\b[0-9][0-9A-Fa-f]*[hH]\b|\b[0-9]+\b")
REGISTER = re.compile(r"\b(?:[ad][0-7]|sp|pc)\b", re.IGNORECASE)
ADDRESS_OPS = {"lea", "pea", "jmp", "jsr", "call", "jp"}
POINTER_MACROS = {
    "smpscall": -1,
    "smpsjump": -1,
    "smpsloop": -1,
    "smpsheadervoice": 0,
    "smpsheaderfm": 0,
    "smpsheaderpsg": 0,
    "smpsheaderdac": 0,
    "mappingstableentry.w": 0,
    "dplctableentry.w": 0,
}


def split_comment(line: str) -> str:
    quote = None
    escaped = False
    for index, char in enumerate(line):
        if escaped:
            escaped = False
            continue
        if char == "\\" and quote:
            escaped = True
        elif quote and char == quote:
            quote = None
        elif not quote and char in ("'", '"'):
            quote = char
        elif not quote and char == ";":
            return line[:index]
    return line


def statement(line: str) -> tuple[str, str]:
    code = split_comment(line).strip()
    code = re.sub(r"^[\w.]+:\s*", "", code)
    match = re.match(r"([!\w.]+)\s+(.*)", code)
    return (match[1].lower(), match[2].strip()) if match else (code.lower(), "")


def normalize(opcode: str, operands: str) -> str:
    return opcode.lower() + " " + re.sub(r"\s+", "", operands)


def raw_equates(sources: dict[str, str]) -> dict[str, str]:
    values = {}
    for text in sources.values():
        for line in text.splitlines():
            code = split_comment(line).strip()
            match = re.match(r"([\w.]+):?\s+(?:equ|=)\s+(\$[0-9A-Fa-f]+|[0-9]+|[0-9A-Fa-f]+[hH])$", code, re.IGNORECASE)
            if match:
                value = match[2]
                number = (
                    int(value[1:], 16)
                    if value.startswith("$")
                    else int(value[:-1], 16)
                    if value.lower().endswith("h")
                    else int(value)
                )
                if 0 < number < 0x80000:
                    values[match[1].lower()] = value
    changed = True
    while changed:
        changed = False
        for text in sources.values():
            for line in text.splitlines():
                match = re.match(
                    r"([\w.]+):?\s+(?:equ|=)\s+([A-Za-z_][A-Za-z0-9_.]*)$", split_comment(line).strip(), re.IGNORECASE
                )
                if match and match[1].lower() not in values and match[2].lower() in values:
                    values[match[1].lower()] = values[match[2].lower()]
                    changed = True
    return values


def non_symbolic(operand: str, aliases: dict[str, str], *, registers: bool = True) -> bool:
    operand = operand.strip()
    if registers and re.search(r"\b(?:a[0-7]|sp)\b", operand, re.IGNORECASE):
        return False
    if registers and re.match(r"^\(?\s*\*", operand):
        return False
    operand = REGISTER.sub("", operand)
    operand = re.sub(r"\.[wl]\b", "", operand, flags=re.IGNORECASE)
    identifiers = re.findall(r"[A-Za-z_][A-Za-z0-9_.]*", LITERAL.sub("", operand))
    identifiers = [name for name in identifiers if name.lower() not in {"low", "high", "lo", "hi"}]
    if identifiers:
        return all(name.lower() in aliases for name in identifiers)
    return bool(LITERAL.search(operand))


def candidates(text: str, aliases: dict[str, str]) -> list[dict]:
    found = []
    for number, line in enumerate(text.splitlines(), 1):
        opcode, operands = statement(line)
        if not operands:
            continue
        reason = None
        first = operands.split(",", 1)[0].strip()
        if opcode in ADDRESS_OPS and non_symbolic(first, aliases):
            reason = "numeric effective address or raw ROM-valued equate"
        elif opcode in {"movea.w", "movea.l", "move.w", "move.l"} and re.search(
            r",\s*a[0-7]$", operands, re.IGNORECASE
        ):
            if first.startswith("#") and non_symbolic(first[1:], aliases, registers=False):
                reason = "numeric immediate loaded into an address register"
        elif opcode == "dc.l":
            if any(
                non_symbolic(value, aliases, registers=False) and value.strip() not in {"0", "$0", "$0000", "$00000000"}
                for value in operands.split(",")
            ):
                reason = "numeric longword in a potential pointer table"
        elif opcode in POINTER_MACROS:
            value = operands.split(",")[POINTER_MACROS[opcode]]
            if non_symbolic(value, aliases, registers=False):
                reason = "numeric pointer-bearing macro operand"
        if reason:
            found.append({"line": number, "statement": normalize(opcode, operands), "reason": reason})
    return found


def audit(sources: dict[str, str], policy: dict) -> dict:
    aliases = raw_equates(sources)
    permitted = {}
    for record in policy["classified_literals"]:
        opcode, operands = statement(record["statement"])
        key = normalize(opcode, operands)
        for owner in record["owners"]:
            permitted[owner, key] = record
    findings, classified, counts = [], [], Counter()
    for path, text in sources.items():
        for entry in candidates(text, aliases):
            record = permitted.get((path, entry["statement"]))
            if record is None:
                findings.append({"path": path, **entry})
            else:
                classified.append({"path": path, **entry, "kind": record["kind"], "classification": record["reason"]})
                counts[path, entry["statement"]] += 1
    stale = [dict(path=path, statement=signature) for path, signature in permitted if not counts[path, signature]]
    if findings or stale:
        raise ValueError(
            json.dumps({"unclassified_address_operands": findings, "stale_classifications": stale}, indent=2)
        )
    return {
        "schema_version": 1,
        "source_files": len(sources),
        "classified_numeric_operands": classified,
        "raw_pointer_findings": [],
        "fixed_regions": policy["fixed_regions"],
    }


def main() -> int:
    argparse.ArgumentParser(description=__doc__).parse_args()
    sources = {path.as_posix(): (ROOT / path).read_text(encoding="utf-8") for path in source_paths()}
    try:
        report = audit(sources, load("config/reconstruction/address_policy.json"))
    except ValueError as error:
        raise SystemExit(f"error: {error}") from error
    atomic_write(ROOT / "build/audits/symbolic-pointers.json", (json.dumps(report, indent=2) + "\n").encode())
    print(
        f"[OK] Symbolic address operands: {report['source_files']} sources, {len(report['classified_numeric_operands'])} classified scalar/VDP words"
    )
    return 0
