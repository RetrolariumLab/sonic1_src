"""Audit numeric address operands and classify the remaining scalar command words."""

from __future__ import annotations
import argparse
from collections import Counter
import json
import re
from scripts.build.project import ROOT, atomic_write, load
from scripts.validation.lint_project import source_paths
from scripts.validation import symbol_names
from scripts.validation.constant_expressions import number

LITERAL = re.compile(r"\$[0-9A-Fa-f]+|\b[0-9][0-9A-Fa-f]*[hH]\b|\b[0-9]+\b")
REGISTER = re.compile(r"\b(?:[ad][0-7]|sp|pc)\b", re.IGNORECASE)
ADDRESS_OPS = {"lea", "pea", "jmp", "jsr", "call", "jp"}
MEMORY_OPS = {
    "move",
    "movea",
    "movem",
    "movep",
    "clr",
    "neg",
    "negx",
    "not",
    "tst",
    "tas",
    "add",
    "adda",
    "addi",
    "addq",
    "addx",
    "sub",
    "suba",
    "subi",
    "subq",
    "subx",
    "cmp",
    "cmpa",
    "cmpi",
    "cmpm",
    "and",
    "andi",
    "or",
    "ori",
    "eor",
    "eori",
    "btst",
    "bset",
    "bclr",
    "bchg",
    "asl",
    "asr",
    "lsl",
    "lsr",
    "rol",
    "ror",
    "roxl",
    "roxr",
    "mulu",
    "muls",
    "divu",
    "divs",
    "chk",
    "scc",
    "scs",
    "seq",
    "sne",
    "sgt",
    "sge",
    "slt",
    "sle",
    "shi",
    "sls",
    "spl",
    "smi",
    "svc",
    "svs",
    "st",
    "sf",
    "nbcd",
}
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
    bindings = {}
    for text in sources.values():
        for line in text.splitlines():
            code = split_comment(line).strip()
            match = re.match(r"([\w.]+):?\s+(?:equ|=)\s+(.+)$", code, re.IGNORECASE)
            if match:
                bindings.setdefault(match[1].lower(), set()).add(match[2])
    values = {}
    for _ in range(len(bindings) + 1):
        changed = False
        for name, expressions in bindings.items():
            resolved = [number(expression, values) for expression in expressions]
            if all(value is not None for value in resolved) and len(set(resolved)) == 1 and name not in values:
                values[name] = resolved[0]
                changed = True
        if not changed:
            break
    aliases = {name: str(value) for name, value in values.items() if 0 < value < 0x80000}
    # Conditional numeric definitions remain raw even when their values differ.
    for _ in range(len(bindings) + 1):
        additions = {}
        for name, expressions in bindings.items():
            if name in aliases or name in values:
                continue
            for expression in expressions:
                value = number(expression, values)
                names = re.findall(r"[A-Za-z_][A-Za-z0-9_.]*", LITERAL.sub("", expression))
                raw_dependency = any(name.lower() in aliases for name in names)
                if (value is not None and 0 < value < 0x80000) or (
                    value is None and raw_dependency and non_symbolic(expression, aliases, registers=False)
                ):
                    additions[name] = expression
                    break
        if not additions:
            break
        aliases.update(additions)
    return aliases


def operands_list(operands):
    """Commas within an indexed effective address do not separate operands."""
    depth, start = 0, 0
    result = []
    for index, char in enumerate(operands):
        if char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
        elif char == "," and depth == 0:
            result.append(operands[start:index].strip())
            start = index + 1
    return [*result, operands[start:].strip()]


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
    z80, saved = False, []
    for number, line in enumerate(text.splitlines(), 1):
        opcode, operands = statement(line)
        if opcode == "save":
            saved.append(z80)
        elif opcode == "restore" and saved:
            z80 = saved.pop()
        elif opcode == "cpu":
            z80 = operands.lower() == "z80"
        if not operands:
            continue
        reason = None
        parts = operands_list(operands)
        first = parts[0]
        base = re.sub(r"\.[bwl]$", "", opcode)
        target = parts[-1] if base in {"jp", "call"} else first
        if base in ADDRESS_OPS and non_symbolic(target, aliases):
            reason = "numeric effective address or raw ROM-valued equate"
        elif opcode in {"movea.w", "movea.l", "move.w", "move.l"} and re.search(
            r",\s*(?:a[0-7]|sp)$", operands, re.IGNORECASE
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
        if reason is None and not z80 and base in MEMORY_OPS:
            if any(not value.startswith("#") and non_symbolic(value, aliases) for value in parts):
                reason = "numeric absolute memory operand or raw ROM-valued equate"
        if reason:
            found.append({"line": number, "statement": normalize(opcode, operands), "reason": reason})
    return found


def audit(sources: dict[str, str], policy: dict, registry: dict | None = None) -> dict:
    names = symbol_names.audit(sources, registry)
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
        "symbol_names": names,
        "fixed_regions": policy["fixed_regions"],
    }


def main() -> int:
    argparse.ArgumentParser(description=__doc__).parse_args()
    sources = {path.as_posix(): (ROOT / path).read_text(encoding="utf-8") for path in source_paths()}
    try:
        report = audit(
            sources, load("config/reconstruction/address_policy.json"), load("config/reconstruction/label_renames.json")
        )
    except ValueError as error:
        raise SystemExit(f"error: {error}") from error
    atomic_write(ROOT / "build/audits/symbolic-pointers.json", (json.dumps(report, indent=2) + "\n").encode())
    print(
        f"[OK] Symbolic address operands: {report['source_files']} sources, {len(report['classified_numeric_operands'])} classified scalar/VDP words"
    )
    return 0
