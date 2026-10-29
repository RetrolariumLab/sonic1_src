"""Resolve Kit's checked tool suite and pin the executable actually invoked."""
import platform
import subprocess
from pathlib import Path
from scripts.build.project import load, sha256


def resolve() -> dict[str, Path]:
    host = "windows-x86_64" if platform.system() == "Windows" and platform.machine().lower() in ("amd64", "x86_64") else "unsupported"
    specification = load("config/toolchain.json")
    if host not in specification["hosts"]:
        raise ValueError(f"Preservation toolchain is not yet pinned for host {host}")
    status = subprocess.check_output(["rltool", "build-tools", "status"], text=True)
    import json
    if json.loads(status)["release"] != specification["kit"]["release"]:
        raise ValueError("Kit build-tool release differs from the manifest")
    result = {}
    for name, spec in specification["hosts"][host]["components"].items():
        path = Path(subprocess.check_output(["rltool", "build-tools", "path", "megadrive", name], text=True).strip())
        if sha256(path.read_bytes()) != spec["sha256"]:
            raise ValueError(f"{name}: executable SHA-256 differs from pinned toolchain")
        result[name] = path
    return result
