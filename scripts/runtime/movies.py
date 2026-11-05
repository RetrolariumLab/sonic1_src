"""Original-ROM golden movies and direct checks of each relocated profile."""

from __future__ import annotations
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import subprocess
import shutil
import time
from scripts.build.project import (
    ROOT,
    rltool_command,
    atomic_write,
    checked_path,
    image,
    load,
    profile,
    profiles,
    read_rom,
    sha256,
)
from scripts.build.project import file_sha256
from scripts.build.listing import symbols
from scripts.runtime.matrix import validate as validate_matrix
from scripts.validation import relocation
from scripts.validation.lint_project import source_paths


RUNNER_SHA256 = file_sha256(Path(__file__))


def processes() -> list[dict]:
    # WMI hides CommandLine in some managed environments. Parent IDs and
    # creation timestamps still establish ownership without guessing by name.
    script = r"""
$rows = @()
foreach ($runtimeProcess in @(Get-CimInstance Win32_Process -Filter "Name='consoles.exe'")) {
    $chain = @()
    $ancestorId = [int]$runtimeProcess.ParentProcessId
    for ($index = 0; $index -lt 24 -and $ancestorId -gt 0; $index++) {
        if ($chain -contains $ancestorId) { break }
        $chain += $ancestorId
        $ancestor = Get-CimInstance Win32_Process -Filter "ProcessId=$ancestorId"
        if (-not $ancestor) { break }
        $ancestorId = [int]$ancestor.ParentProcessId
    }
    $created = if ($runtimeProcess.CreationDate) { $runtimeProcess.CreationDate.ToUniversalTime().ToString('o') } else { '' }
    $rows += [pscustomobject]@{ ProcessId=[int]$runtimeProcess.ProcessId; Created=$created; Ancestors=@($chain) }
}
@($rows) | ConvertTo-Json -Compress -Depth 5
"""
    raw = subprocess.check_output(
        ["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", script], text=True
    ).strip()
    result = json.loads(raw) if raw else []
    return result if isinstance(result, list) else [result]


def remember_owned(rows: list[dict], client_pid: int, owned: dict[int, str]) -> None:
    for item in rows:
        if client_pid in item["Ancestors"]:
            if not item["Created"]:
                raise ValueError("Cannot establish MAME creation identity")
            owned[int(item["ProcessId"])] = item["Created"]


def owned_leftovers(rows: list[dict], owned: dict[int, str]) -> list[dict]:
    return [item for item in rows if owned.get(int(item["ProcessId"])) == item["Created"]]


def wait_until_idle(timeout: float = 3600) -> None:
    deadline = time.monotonic() + timeout
    announced = False
    while processes():
        if not announced:
            print("[WAIT] Another MAME run is active; waiting for the sequential runtime slot", flush=True)
            announced = True
        if time.monotonic() >= deadline:
            raise ValueError("MAME remained busy; no concurrent emulator was started")
        time.sleep(min(5, max(0.01, deadline - time.monotonic())))


def emulator(named: Path | None) -> Path:
    value = str(named) if named else os.environ.get("RETROLARIUM_MAME")
    if not value:
        value = subprocess.check_output([*rltool_command(), "movie", "mame"], text=True).strip()
    path = Path(value).resolve()
    expected = load("config/toolchain.json")["emulator"]["sha256"]
    if not path.is_file() or file_sha256(path) != expected:
        raise ValueError("MAME executable does not match config/toolchain.json")
    wait_until_idle()
    staged = checked_path("build/emulator/consoles.exe")
    if not staged.is_file() or file_sha256(staged) != expected:
        staged.parent.mkdir(parents=True, exist_ok=True)
        temporary = staged.with_name("consoles.exe.tmp")
        shutil.copyfile(path, temporary)
        if file_sha256(temporary) != expected:
            raise ValueError("Staged emulator hash differs")
        temporary.replace(staged)
    return staged


def controller_movie(profile_id: str, scenario: dict) -> bytes:
    runs = []

    def frames(count: int, buttons: int = 0):
        if count > 0:
            runs.append((count, buttons))

    def pulse(buttons: int):
        frames(1, buttons)
        frames(3)

    if scenario["id"] == "attract":
        frames(scenario["frames"])
    elif scenario["id"] == "special-stage":
        frames(600)
        for button in (1, 2, 4, 8) if profile_id == "rev00" else (1, 2, 2, 2, 4, 8):
            pulse(button)
        frames(8)
        frames(4, 64)
        frames(1, 192)
        frames(90)
        pulse(1)
        pulse(1)
        pulse(64)
        frames(scenario["frames"] - sum(count for count, _ in runs))
    elif scenario["id"] == "ending":
        code = (1, 2, 4, 8) if profile_id == "rev00" else (1, 2, 2, 2, 4, 8)
        frames(600)
        for button in code:
            pulse(button)
        pulse(4)
        for _ in range(6):
            pulse(32)
        for button in code:
            pulse(button)
        frames(8)
        frames(4, 64)
        frames(1, 192)
        frames(90)
        pulse(1)
        for _ in range(31):
            pulse(8)
        pulse(64)
        remaining = scenario["frames"] - sum(count for count, _ in runs)
        if remaining < 0:
            raise ValueError("Ending movie is shorter than its original title input sequence")
        frames(remaining)
    else:
        raise ValueError("Unknown runtime scenario")
    if sum(count for count, _ in runs) != scenario["frames"]:
        raise ValueError("Movie duration differs from its scenario")
    header = "# retrolarium movie 1\nplatform megadrive\nsource mame\n"
    return (
        header
        + f"title {scenario['id'].capitalize()} preservation scenario\n---\n"
        + "".join(f"{count} {button:02X} 00\n" for count, button in runs)
    ).encode()


def prepare_check(profile_id: str, scenario: dict, check_path: Path) -> None:
    movie = f"{profile_id}-{scenario['id']}.rlmovie"
    atomic_write(check_path.parent / movie, controller_movie(profile_id, scenario))
    listing = ROOT / "build/artifacts" / profile_id / "entry.lst"
    registry = load("config/runtime/cells.json")["cells"]
    values = {}
    wanted = {
        item[key]
        for name, item in registry.items()
        if name in scenario["cells"]
        for key in ("symbol", "offset_symbol")
        if key in item
    }
    table = symbols(listing, wanted)
    for name in scenario["cells"]:
        item = registry[name]
        address = table[item["symbol"]]
        if item.get("offset_symbol"):
            address += table[item["offset_symbol"]]
        values[name] = {"address": hex(address), "length": item["length"]}
    spec = {
        "schema": "retrolarium.movie-check",
        "schema_version": 1,
        "machine": scenario["machine"],
        "movie": movie,
        "cells": values,
        "frames": list(range(scenario["checkpoint_step"], scenario["frames"], scenario["checkpoint_step"])) + ["end"],
        "expected": {},
    }
    atomic_write(check_path, (json.dumps(spec, indent=2) + "\n").encode())


def validate_check(spec: dict, scenario: dict) -> None:
    if spec.get("schema") != "retrolarium.movie-check" or spec.get("schema_version") != 1:
        raise ValueError("Unsupported movie check")
    frames = list(range(scenario["checkpoint_step"], scenario["frames"], scenario["checkpoint_step"])) + ["end"]
    if spec.get("frames") != frames or spec.get("machine") != scenario["machine"] or spec.get("offset", 0) != 0:
        raise ValueError("Movie frame or machine contract differs")
    if set(spec.get("cells", {})) != set(scenario["cells"]):
        raise ValueError("Movie RAM cell coverage differs")
    expected = spec.get("expected", {})
    if set(expected) != set(map(str, frames)):
        raise ValueError("Golden trace is missing required checkpoints")
    for cell in spec["cells"].values():
        if (
            set(cell) != {"address", "length"}
            or not 0xFF0000 <= int(cell["address"], 0) <= 0xFFFFFF
            or not 1 <= cell["length"] <= 4
        ):
            raise ValueError("Movie RAM cells must use exact registered program-space ranges")
    for checkpoint, values in expected.items():
        if set(values) != set(scenario["cells"]):
            raise ValueError(f"Golden checkpoint {checkpoint} is missing RAM cells")
        for name, value in values.items():
            try:
                raw = bytes.fromhex(value)
            except (TypeError, ValueError) as error:
                raise ValueError("Golden RAM value is not hexadecimal") from error
            if len(raw) != spec["cells"][name]["length"]:
                raise ValueError("Golden RAM value has an incorrect width")
    checkpoints = iter(expected[str(frame)] for frame in frames)
    for state in scenario.get("required_sequence", []):
        if not any(all(int(values[name], 16) == value for name, value in state.items()) for values in checkpoints):
            raise ValueError("Movie never reaches its ordered scene transition")
    for state in scenario["required_states"]:
        if not any(
            all(int(values[name], 16) == value for name, value in state.items()) for values in expected.values()
        ):
            raise ValueError(f"Movie never reaches required state: {state}")


def invoke(action: str, rom: Path, check_path: Path, mame: Path, log: Path) -> None:
    wait_until_idle()
    # Core runs MAME from the executable's parent. Only the exact copied binary
    # survives between runs, so cfg, NVRAM, states and ini files cannot leak in.
    stage = checked_path("build/emulator")
    if mame.parent != stage:
        raise ValueError("Runtime must execute inside the isolated build directory")
    for candidate in stage.iterdir():
        if candidate.name == "consoles.exe":
            continue
        resolved = candidate.resolve()
        if not resolved.is_relative_to(stage.resolve()):
            raise ValueError("Emulator cleanup escaped its build directory")
        if candidate.is_dir():
            shutil.rmtree(candidate)
        else:
            candidate.unlink()
    temporary = checked_path("build/tmp")
    temporary.mkdir(exist_ok=True)
    environment = dict(
        os.environ, PYTHONDONTWRITEBYTECODE="1", TEMP=str(temporary), TMP=str(temporary), TMPDIR=str(temporary)
    )
    log.parent.mkdir(parents=True, exist_ok=True)
    result = None
    owned = {}
    try:
        with log.open("wb") as stream:
            result = subprocess.Popen(
                [*rltool_command(), "movie", action, "--mame", str(mame), "--rom", str(rom.resolve()), str(check_path)],
                cwd=ROOT,
                env=environment,
                stdout=stream,
                stderr=subprocess.STDOUT,
            )
            deadline = time.monotonic() + 3700
            while True:
                remember_owned(processes(), result.pid, owned)
                try:
                    result.wait(timeout=min(5, max(0.01, deadline - time.monotonic())))
                    break
                except subprocess.TimeoutExpired:
                    if time.monotonic() >= deadline:
                        result.kill()
                        result.wait()
                        raise
    finally:
        remaining = processes()
        if result is not None:
            remember_owned(remaining, result.pid, owned)
        ours = owned_leftovers(remaining, owned)
        for item in ours:
            subprocess.run(
                [
                    "powershell.exe",
                    "-NoProfile",
                    "-NonInteractive",
                    "-Command",
                    f"Stop-Process -Id {int(item['ProcessId'])} -Force",
                ],
                check=True,
            )
        if ours:
            raise ValueError(
                f"MAME remained after the run: terminated owned IDs {[item['ProcessId'] for item in ours]}; unrelated processes were preserved"
            )
    if result.returncode:
        raise ValueError(
            f"Movie {action} failed; read {log.relative_to(ROOT)}: {log.read_text(errors='replace')[-1200:]}"
        )
    print(log.read_text(errors="replace").strip())


def verify_relocated(profile_id: str) -> Path:
    target = relocation.artifact(profile_id)
    report = load(f"build/relocated/{profile_id}/relocation.json")
    if sha256(target.read_bytes()) != report["sha256"]:
        raise ValueError("Relocated artifact differs from its build report")
    expected = {path.as_posix(): sha256((ROOT / path).read_bytes()) for path in source_paths()}
    if expected != report["source_hashes"] or report.get("pipeline_hashes") != relocation.pipeline_hashes():
        raise ValueError("Relocated source report is stale; run build-relocated again")
    return target


def run(action: str, profile_id: str, selected: str | None, directory: Path, mame: Path) -> None:
    matrix = load("scenarios/runtime_matrix.json")
    validate_matrix(matrix)
    scenarios = {item["id"]: item for item in matrix["scenarios"]}
    row = next(item for item in matrix["profiles"] if item["profile"] == profile_id)
    for entry in row["scenarios"]:
        if selected and entry["id"] != selected:
            continue
        scenario = scenarios[entry["id"]]
        path = checked_path(entry["check"])
        if action == "golden":
            rom, _ = read_rom(profile_id, directory)
            prepare_check(profile_id, scenario, path)
            invoke("golden", rom, path, mame, ROOT / "build/runtime" / f"{profile_id}-{scenario['id']}-golden.log")
            spec = json.loads(path.read_text())
            if spec.get("movie") != f"{profile_id}-{scenario['id']}.rlmovie":
                raise ValueError("Movie path differs from the profile scenario")
            validate_check(spec, scenario)
            registry = load("config/runtime/cells.json")["cells"]
            listing = ROOT / "build/artifacts" / profile_id / "entry.lst"
            wanted = {
                item[key]
                for name, item in registry.items()
                if name in scenario["cells"]
                for key in ("symbol", "offset_symbol")
                if key in item
            }
            table = symbols(listing, wanted)
            for name in scenario["cells"]:
                cell = registry[name]
                address = table[cell["symbol"]]
                if cell.get("offset_symbol"):
                    address += table[cell["offset_symbol"]]
                if spec["cells"][name] != {"address": hex(address), "length": cell["length"]}:
                    raise ValueError(f"Runtime cell {name} differs from the assembled RAM declaration")
            spec["reference"] = {"image": profile_id, "sha256": image(profile_id)["sha256"]}
            spec["emulator_sha256"] = load("config/toolchain.json")["emulator"]["sha256"]
            spec["emulator_environment"] = "isolated-cwd-v1"
            spec["movie_sha256"] = sha256((path.parent / spec["movie"]).read_bytes())
            atomic_write(path, (json.dumps(spec, indent=2) + "\n").encode())
        else:
            spec = json.loads(path.read_text())
            if spec.get("movie") != f"{profile_id}-{scenario['id']}.rlmovie":
                raise ValueError("Movie path differs from the profile scenario")
            validate_check(spec, scenario)
            registry = load("config/runtime/cells.json")["cells"]
            listing = ROOT / "build/artifacts" / profile_id / "entry.lst"
            wanted = {
                item[key]
                for name, item in registry.items()
                if name in scenario["cells"]
                for key in ("symbol", "offset_symbol")
                if key in item
            }
            table = symbols(listing, wanted)
            for name in scenario["cells"]:
                cell = registry[name]
                address = table[cell["symbol"]]
                if cell.get("offset_symbol"):
                    address += table[cell["offset_symbol"]]
                if spec["cells"][name] != {"address": hex(address), "length": cell["length"]}:
                    raise ValueError(f"Runtime cell {name} differs from the assembled RAM declaration")
            if spec.get("reference") != {"image": profile_id, "sha256": image(profile_id)["sha256"]}:
                raise ValueError("Golden check does not name its accepted original input")
            if spec.get("emulator_environment") != "isolated-cwd-v1":
                raise ValueError("Golden was not captured in the isolated emulator environment")
            if spec.get("emulator_sha256") != load("config/toolchain.json")["emulator"]["sha256"]:
                raise ValueError("Golden check was recorded with a different emulator")
            movie_hash = sha256((path.parent / spec["movie"]).read_bytes())
            if (
                spec.get("movie_sha256") != movie_hash
                or controller_movie(profile_id, scenario) != (path.parent / spec["movie"]).read_bytes()
            ):
                raise ValueError("Movie input differs from its declared scenario")
            rom = verify_relocated(profile_id)
            artifact_hash = sha256(rom.read_bytes())
            check_hash = sha256(path.read_bytes())
            invoke("check", rom, path, mame, ROOT / "build/runtime" / f"{profile_id}-{scenario['id']}-check.log")
            if sha256(rom.read_bytes()) != artifact_hash or sha256(path.read_bytes()) != check_hash:
                raise ValueError("Runtime inputs changed during the run")
            if file_sha256(Path(__file__)) != RUNNER_SHA256:
                raise ValueError("Runtime runner changed during the check")
            report = {
                "schema_version": 1,
                "runner_sha256": RUNNER_SHA256,
                "profile": profile_id,
                "scenario": scenario["id"],
                "passed": True,
                "artifact_sha256": artifact_hash,
                "check_sha256": check_hash,
                "movie_sha256": movie_hash,
                "emulator_sha256": spec["emulator_sha256"],
                "checked_at": datetime.now(timezone.utc).isoformat(),
            }
            atomic_write(
                ROOT / "build/runtime" / f"{profile_id}-{scenario['id']}.json",
                (json.dumps(report, indent=2) + "\n").encode(),
            )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("golden", "check"))
    parser.add_argument("--profile")
    parser.add_argument("--scenario", choices=("attract", "ending", "special-stage"))
    parser.add_argument("--rom-dir", type=Path, default=ROOT)
    parser.add_argument("--mame", type=Path)
    args = parser.parse_args()
    try:
        mame = emulator(args.mame)
        ids = [args.profile] if args.profile else [item["id"] for item in profiles()]
        for selected in ids:
            profile(selected)
            run(args.action, selected, args.scenario, args.rom_dir, mame)
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        parser.exit(1, f"error: {error}\n")
    return 0
