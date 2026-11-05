"""Check non-emitting RAM declarations and the preserved Z80 driver context."""

import argparse
import json
import re

from scripts.authoring.kosinski import decode as decompress
from scripts.build.listing import symbols
from scripts.build.project import ROOT, atomic_write, file_sha256, load, profiles, sha1, sha256
from scripts.build.sources import fingerprint, source_paths
from scripts.validation.source_layout import actual
from scripts.validation.symbolic_pointers import split_comment

CONFIG = "config/reconstruction/memory_contracts.json"
SAMPLE_SCOPES = {
    "src/audio/dac/dpcm/" + name + ".asm": "zDAC_" + name.capitalize() for name in ("kick", "snare", "timpani")
}
NAME = r"[A-Za-z_.][A-Za-z_0-9.]*"
MEMORY_OPS = {
    "",
    "equ",
    "function",
    "struct",
    "endstruct",
    "ds.b",
    "ds.w",
    "ds.l",
    "smps_ram",
    "smps_track",
    "include",
    "phase",
    "dephase",
    "org",
    "!org",
    "if",
    "elseif",
    "else",
    "endif",
    "fatal",
    "error",
    "warning",
}
Z80_OPS = set(
    "adc add and bit call cp cpl dec di djnz ei ex exx halt im in inc jp jr ld ldd lddr ldi ldir neg nop or out pop push res ret reti retn rl rla rlc rlca rld rr rra rrc rrca rrd rst sbc scf set sla sra srl sub xor".split()
)


def statements(text):
    for line in text.splitlines():
        code = split_comment(line).strip()
        if not code:
            continue
        name = None
        declaration = re.match(r"^(" + NAME + r"):\s*", code)
        if declaration:
            name, code = declaration[1], code[declaration.end() :]
        else:
            declaration = re.match(r"^(" + NAME + r")\s+(function|struct|macro|equ|:=|=)\s+", code, re.I)
            if declaration:
                name, code = declaration[1], code[declaration.start(2) :]
        parts = code.split(None, 1)
        yield name, parts[0].lower() if parts else "", parts[1].strip() if len(parts) == 2 else ""


def signature(text):
    # Preserve statement/argument order, including declaration fields and guards.
    tokens = [str(name) + ":" + op + " " + re.sub(r"\s+", "", args) for name, op, args in statements(text)]
    return sha256("\n".join(tokens).encode())


def memory_model(text):
    names, phases, structures = [], [], []
    phase = False
    conditions = []
    for name, op, args in statements(text):
        if op not in MEMORY_OPS:
            raise ValueError("Executable or unknown RAM declaration: " + op)
        if op == "struct":
            if not name or structures or phase or args.lower() != "dots":
                raise ValueError("Invalid RAM structure context")
            structures.append(name)
            names.append(name + ".len")
            continue
        if op == "endstruct":
            if not structures or name or args:
                raise ValueError("Unbalanced RAM structure")
            structures.pop()
            continue
        if name and op != "function":
            names.append((structures[-1] + "." if structures else "") + name)
        if op.startswith("ds."):
            if not (phase or structures) or not args or "," in args:
                raise ValueError("RAM reserve must be uninitialized and inside its declared context")
        elif op == "phase":
            if phase or structures or not args:
                raise ValueError("Nested or empty RAM phase")
            phase = True
            phases.append(re.sub(r"\s+", "", args))
        elif op == "dephase":
            if not phase or args:
                raise ValueError("Unbalanced RAM phase")
            phase = False
        elif op == "include" and args != '"src/audio/ram.inc"':
            raise ValueError("RAM include has no declared memory owner")
        elif op == "function" and name != "ramaddr":
            raise ValueError("Unknown RAM address function")
        elif op in {"if", "elseif", "else", "endif"}:
            if op == "if":
                conditions.append(False)
            elif not conditions:
                raise ValueError("Unbalanced RAM condition")
            elif op == "endif":
                conditions.pop()
            elif conditions[-1]:
                raise ValueError("RAM condition continues after else")
            elif op == "else":
                conditions[-1] = True
        elif op in {"fatal", "error", "warning"} and not conditions:
            raise ValueError("RAM diagnostic needs a bounded guard")
        elif op == "org" and (not phase or args != "$FFFF8000"):
            raise ValueError("Unexpected RAM cursor rebase")
        elif op == "!org" and (phase or structures or args != "0"):
            raise ValueError("Unexpected RAM cursor rewind")
    if phase or structures or conditions:
        raise ValueError("Unclosed RAM declaration context")
    return dict(names=sorted(set(names)), phases=phases, statements_sha256=signature(text))


def z80_model(text):
    cpu, saved, macros = "68000", [], []
    names = []
    helpers = {"ensure1byteoffset", "zpcmmetadata"}
    directives = {
        "",
        "equ",
        "function",
        "=",
        ":=",
        "if",
        "else",
        "endif",
        "fatal",
        "message",
        "align",
        "db",
        "dw",
        "include",
    }
    for name, op, args in statements(text):
        if name and not macros and not name.startswith(".") and op not in {"macro", "function", ":="}:
            names.append(name)
        if op == "save":
            if saved or cpu != "68000":
                raise ValueError("Nested Z80 CPU save")
            saved.append(cpu)
        elif op == "restore":
            if not saved or macros or cpu != "z80":
                raise ValueError("Unbalanced Z80 CPU restore")
            cpu = saved.pop()
        elif op == "cpu":
            if not saved or cpu != "68000" or args.lower() != "z80":
                raise ValueError("Unexpected CPU in DAC driver")
            cpu = "z80"
        elif op == "macro":
            if name is None or name.lower() not in helpers or macros or cpu != "z80":
                raise ValueError("Unknown Z80 helper definition")
            macros.append(name)
        elif op == "endm":
            if not macros or args:
                raise ValueError("Unbalanced Z80 helper")
            macros.pop()
        elif op == "!org":
            expected = "0" if saved and cpu == "68000" else "(DACDriver+Size_of_DAC_driver_guess)"
            if args != expected:
                raise ValueError("Z80 cursor leaves its declared storage owner")
        elif op in {"listing", "padding"}:
            if (op, args.lower(), cpu) not in {("listing", "purecode", "z80"), ("padding", "off", "68000")}:
                raise ValueError("Unexpected Z80 assembler context")
        elif cpu != "z80" or op not in directives | Z80_OPS | helpers:
            raise ValueError("Instruction outside its Z80 CPU context: " + op)
    if saved or macros or cpu != "68000":
        raise ValueError("Unclosed Z80 assembler context")
    return dict(names=sorted(set(names)), statements_sha256=signature(text))


def listing_symbols(path):
    values = {}
    for line in path.read_text(errors="replace").splitlines():
        for cell in line.split("|"):
            match = re.fullmatch(r"\s*\*?(" + NAME + r")\s*:\s*([A-Fa-f0-9]+)\s+[A-Za-z-]\s*", cell)
            if match:
                name, value = match[1], int(match[2], 16) & 0xFFFFFF
                if name in values and values[name] != value:
                    raise ValueError("Conflicting AS declaration symbol: " + name)
                values[name] = value
    return values


def sample_model(text, scope):
    rows = list(statements(text))
    if (
        len(rows) != 4
        or rows[0][0:2] != (".sample_rate", "=")
        or not rows[0][2].isdigit()
        or not 0 < int(rows[0][2]) <= 96000
        or rows[1] != (".start", "=", "$")
        or rows[2][0:2] != (None, "binclude")
        or not re.fullmatch(r'"sound/dac/dpcm/(?:kick|snare|timpani)\.dpcm"', rows[2][2])
        or rows[3] != (".size", "=", "$-.start")
    ):
        raise ValueError("DPCM wrapper differs from its bounded sample declaration ABI")
    return dict(
        names=sorted(scope + suffix for suffix in (".sample_rate", ".start", ".size")),
        statements_sha256=signature(text),
    )


def check(built=False):
    spec = load(CONFIG)
    owners = {
        "src/memory/ram.inc": "memory",
        "src/audio/ram.inc": "memory",
        "src/audio/z80.asm": "z80",
        **{path: "z80-sample" for path in SAMPLE_SCOPES},
    }
    if (
        len(spec["owners"]) != len(owners)
        or {row["path"]: row["kind"] for row in spec["owners"]} != owners
        or not re.fullmatch(r"[0-9a-f]{40}", spec.get("baseline_commit", ""))
        or len(spec["primitive_helpers"]) != 1
        or spec["primitive_helpers"][0]["path"] != "src/system/assembler.inc"
    ):
        raise ValueError("Memory/CPU contract must cover every declared owner and primitive helper")
    for row in spec["owners"]:
        text = (ROOT / row["path"]).read_text()
        if row["kind"] == "memory":
            model = memory_model(text)
        elif row["kind"] == "z80-sample":
            model = sample_model(text, SAMPLE_SCOPES[row["path"]])
        else:
            model = z80_model(text)
        if model != row["declarations"]:
            raise ValueError("Memory/CPU declaration contract differs: " + row["path"])
        if set(row["symbols"]) != {selected["id"] for selected in profiles()}:
            raise ValueError("Memory ABI witness must cover every revision")
        for key, expected in row["symbols"].items():
            inactive = (
                {"v_scorelife" if key == "rev00" else "v_scorecopy"} if row["path"] == "src/memory/ram.inc" else set()
            )
            if set(expected) != set(model["names"]) - inactive or any(
                type(address) is not int or not 0 <= address <= 0xFFFFFF for address in expected.values()
            ):
                raise ValueError("Memory ABI witness omits a declaration or has an invalid address")
    reserved = r"(?:ds(?:\.[bwl])?|phase|dephase|org|!org|cpu|save|restore)"
    helpers = {row["path"]: row["statements_sha256"] for row in spec["primitive_helpers"]}
    for path, expected in helpers.items():
        if signature((ROOT / path).read_text()) != expected:
            raise ValueError("Reviewed assembler primitive helpers changed: " + path)
    for path in source_paths():
        if path.as_posix() not in helpers and re.search(
            r"(?im)^\s*" + reserved + r"\s+macro\b", (ROOT / path).read_text()
        ):
            raise ValueError("Assembler primitive redefinition: " + path.as_posix())
    if built:
        for profile in profiles():
            key = profile["id"]
            parsed = actual(key)  # Requires fresh canonical build and decoded Z80 ownership.
            listing = ROOT / "build/artifacts" / key / "entry.lst"
            values = listing_symbols(listing)
            for row in spec["owners"]:
                expected = row["symbols"][key]
                if any(values.get(name) != address for name, address in expected.items()):
                    raise ValueError("Historical memory/Z80 symbol moved: " + key + " " + row["path"])
            container = next(
                row for row in load("config/build/derived_assets.json")["containers"] if row["image"] == key
            )
            addresses = symbols(listing, {"DACDriver", "Size_of_DAC_driver_guess", "zDACDriver_End", "z80_stack"})
            raw = (listing.parent / "sonic1.bin").read_bytes()
            start = addresses["DACDriver"]
            plain = decompress(
                raw[start : start + addresses["Size_of_DAC_driver_guess"]], max_output=addresses["z80_stack"]
            ).data
            if len(plain) != addresses["zDACDriver_End"] or sha1(plain) != container["decoded_sha1"]:
                raise ValueError("Compiled Z80 payload differs from its independently extracted original")
            if not any(
                row["path"] == "src/audio/z80.asm" and row["address_space"] == "z80" for row in parsed["includes"]
            ):
                raise ValueError("Z80 source has no declared CPU-space owner")
    report = dict(
        schema_version=1,
        passed=True,
        built=built,
        inputs=fingerprint(),
        contract_sha256=file_sha256(ROOT / CONFIG),
        validator_sha256=file_sha256(ROOT / "scripts/validation/memory_contracts.py"),
    )
    atomic_write(
        ROOT / "build/audits" / ("memory-layout.json" if built else "memory-contract.json"),
        (json.dumps(report, indent=2) + "\n").encode(),
    )
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--built", action="store_true")
    args = parser.parse_args()
    try:
        check(args.built)
    except (OSError, ValueError, KeyError) as error:
        parser.exit(1, f"error: {error}\n")
    print(
        "[OK] RAM declarations, historical memory ABI and Z80 contexts"
        if args.built
        else "[OK] Typed RAM and Z80 declaration contracts"
    )
    return 0
