"""Audit the exact public preservation boundary and its current build evidence."""

from __future__ import annotations
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import subprocess
import sys
from scripts.build.listing import symbols
from scripts.build.project import ROOT, atomic_write, checked_path, file_sha256, image, load, profiles
from scripts.runtime import movies
from scripts.runtime.matrix import validate as validate_matrix

EXPECTED_REQUIREMENTS = {
    "canonical_identity",
    "reproducible_build",
    "source_boundary",
    "provenance_and_unknowns",
    "baseline_documentation",
    "baseline_validation",
    "release_contract",
    "private_inputs",
    "generated_outputs",
    "claims_need_evidence",
    "symbolic_pointers",
    "runtime_coverage",
    "licensing_and_provenance",
    "commit_history",
}
DOCUMENTS = {
    "README.md",
    "CONTRIBUTING.md",
    "docs/index.md",
    "docs/build.md",
    "docs/architecture.md",
    "docs/memory_map.md",
    "docs/verification.md",
    "docs/relocation.md",
    "docs/runtime.md",
    "docs/unknowns.md",
    "docs/provenance.md",
}
STEPS = [
    "lint",
    "test",
    "check-inputs",
    "clean",
    "split",
    "verify-all",
    "audit-symbolic",
    "verify-layout",
    "build-relocated-all",
    "runtime-check",
    "release-audit",
]


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True, encoding="utf-8").strip()


def targets() -> set[str]:
    return {
        match[1]
        for path in [ROOT / "Makefile", *sorted((ROOT / "mk").glob("*.mk"))]
        for match in re.finditer(r"^([a-z][a-z0-9-]*):", path.read_text(), re.M)
    }


def validate_manifest(spec: dict) -> None:
    exact = {
        "schema_version": 1,
        "release_line": "1.0",
        "release_kind": "preservation",
        "release": {"name": "Source Reconstruction 1.0", "version": "1.0"},
        "tag": "source-reconstruction-1.0",
        "predecessor": None,
    }
    for key, value in exact.items():
        if spec.get(key) != value:
            raise ValueError(f"Preservation manifest field differs: {key}")
    if spec.get("status") not in ("tag-ready", "tagged"):
        raise ValueError("Preservation candidate is not ready for the full audit")
    if set(spec.get("requirements", {})) != EXPECTED_REQUIREMENTS:
        raise ValueError("Preservation requirement IDs are missing or unsupported")
    if set(spec.get("required_documents", [])) != DOCUMENTS:
        raise ValueError("Required document corpus differs from the release boundary")
    if spec.get("release_commands") != STEPS:
        raise ValueError("Public gate commands or their order differ")
    if spec.get("aggregate_gates") != {
        "pre_tag": ["make release-check"],
        "post_tag": ["make release-audit AUDIT_MODE=--post-tag"],
    }:
        raise ValueError("Aggregate gate interface differs")
    ids = {row["id"] for row in profiles()}
    declared = spec.get("profiles", [])
    if len(declared) != len(ids) or {row.get("id") for row in declared} != ids:
        raise ValueError("Release profiles differ from the build profiles")
    entry = load("config/revision_profiles.json")["entrypoint"]
    for row in declared:
        if row != dict(
            id=row["id"],
            status="supported",
            artifact="sonic1_" + row["id"],
            identity="byte-identical",
            input=row["id"],
            entrypoint=entry,
        ):
            raise ValueError("Profile identity, entrypoint or artifact differs")
    expected_artifacts = [
        dict(
            id="sonic1_" + row["id"],
            profile=row["id"],
            build_target="verify-all",
            path=f"build/artifacts/{row['id']}/sonic1.bin",
            size=image(row["id"])["size"],
            sha1=image(row["id"])["sha1"],
            sha256=image(row["id"])["sha256"],
            tracked=False,
        )
        for row in profiles()
    ]
    if spec.get("artifacts") != expected_artifacts:
        raise ValueError("Artifact paths, hashes or sizes differ from their single input owner")
    expected_coverage = [
        dict(
            profile_id=row["id"],
            mode="direct",
            scenarios=["attract", "ending"],
            manifest="scenarios/runtime_matrix.json",
        )
        for row in profiles()
    ]
    if spec.get("runtime_coverage") != expected_coverage:
        raise ValueError("Every profile needs direct attract and ending coverage")
    if not spec.get("delta") or not spec.get("included_scope") or not spec.get("excluded_scope"):
        raise ValueError("Release scope and full-history delta must be explicit")
    for row in spec["delta"]:
        if row.get("kind") not in ("source", "tooling", "evidence", "documentation") or not row.get("summary"):
            raise ValueError("Release delta lacks a concrete change")
        if not row.get("evidence") or set(row["evidence"]) - EXPECTED_REQUIREMENTS:
            raise ValueError("Release delta names unknown evidence")
    available = targets()
    for requirement in spec["requirements"].values():
        evidence = requirement.get("evidence", {})
        if requirement.get("status") != "satisfied" or not evidence:
            raise ValueError("A preservation requirement lacks evidence")
        for name in evidence.get("files", []):
            if not checked_path(name).exists():
                raise ValueError(f"Evidence path is missing: {name}")
        if set(evidence.get("targets", [])) - available:
            raise ValueError("Evidence names an unavailable Make target")
    for row in spec.get("layout_deviations", []):
        if not all(row.get(key) for key in ("rule_id", "actual_path", "reason", "equivalent_control")):
            raise ValueError("Layout deviation lacks an equivalent check")
    licences = {row["component"]: row for row in spec.get("licensing", [])}
    for name in ("reconstructed_game_source", "upstream_annotations"):
        if licences.get(name, {}).get("license_id_or_status") != "license_not_granted":
            raise ValueError("Source licensing boundary differs")
    if spec.get("provenance", {}).get("private_inputs_tracked") is not False:
        raise ValueError("Private input policy is missing")
    if spec.get("toolchain", {}).get("manifest") != "config/toolchain.json":
        raise ValueError("Toolchain facts have no manifest owner")


def documents(spec: dict) -> None:
    tracked = set(git("ls-files").splitlines())
    for name in spec["required_documents"]:
        path = checked_path(name)
        if name not in tracked or not path.is_file():
            raise ValueError(f"Required document is not tracked: {name}")
        text = path.read_text(encoding="utf-8")
        if not text.strip():
            raise ValueError(f"Empty document: {name}")
        for link in re.findall(r"\[[^\]]+\]\(([^)]+)\)", text):
            if re.match(r"[a-z]+://", link) or link.startswith("#"):
                continue
            target = (path.parent / link.split("#", 1)[0]).resolve()
            if not target.is_relative_to(ROOT) or not target.exists():
                raise ValueError(f"Broken local documentation link in {name}: {link}")
    memory = (ROOT / "docs/memory_map.md").read_text()
    for row in load("config/reconstruction/memory_map.json")["symbols"]:
        wanted = {row["symbol"]}
        for selected in profiles():
            actual = symbols(ROOT / "build/artifacts" / selected["id"] / "entry.lst", wanted)[row["symbol"]]
            expected = row["addresses"][selected["id"]]
            if actual != expected or f"${expected:06X}" not in memory or row["symbol"] not in memory:
                raise ValueError(f"Documented landmark moved: {row['symbol']}")
    for name in tracked:
        path = ROOT / name
        if path.is_file() and path.suffix not in (".png",):
            text = path.read_text(encoding="utf-8")
            if re.search(r"[\u0400-\u04ff]", text):
                raise ValueError(f"Non-English tracked text: {name}")


def history() -> int:
    commits = git("rev-list", "--reverse", "HEAD").splitlines()
    previous_dates = None
    for commit in commits:
        fields = git("show", "-s", "--format=%an%n%ae%n%cn%n%ce%n%at%n%ct%n%B", commit).split("\n", 6)
        expected = ["Daniel Oranguthang", "75395800+oranguthang@users.noreply.github.com"] * 2
        if fields[:4] != expected:
            raise ValueError(f"Commit identity differs: {commit}")
        dates = tuple(map(int, fields[4:6]))
        if previous_dates and any(now < before for now, before in zip(dates, previous_dates)):
            raise ValueError("Commit dates regress in parent order")
        previous_dates = dates
        message = fields[6]
        paragraphs = message.strip().split("\n\n")
        if len(paragraphs) not in (4, 5) or paragraphs[-1] != "Co-Authored-By: Codex <noreply@openai.com>":
            raise ValueError(f"Commit body or attribution differs: {commit}")
        if paragraphs[0].endswith(".") or re.search(r"[\u0400-\u04ff]", message):
            raise ValueError(f"Commit language or subject differs: {commit}")
        if not git("diff-tree", "--root", "--no-commit-id", "--name-only", "-r", commit):
            raise ValueError(f"Empty commit: {commit}")
    # Private sound content cannot remain as text in any public branch snapshot.
    for commit in git("rev-list", "--all").splitlines():
        tree = git("ls-tree", "-r", "--name-only", commit).splitlines()
        for name in tree:
            if name.startswith(("sound/music/", "sound/sfx/")) or name == "sound/_smps2asm_inc.asm":
                raise ValueError(f"Private audio assembly remains in reachable history: {commit}:{name}")
            if name.endswith("s1.sounddriver.asm"):
                source = git("show", f"{commit}:{name}")
                if re.search(r"^PSG[1-9]:?\s+dc\.b\b", source, re.M | re.I):
                    raise ValueError(f"Private PSG envelope declarations remain in reachable history: {commit}")
    return len(commits)


def current_evidence(spec: dict) -> None:
    matrix = load("scenarios/runtime_matrix.json")
    validate_matrix(matrix)
    for artifact in spec["artifacts"]:
        target = checked_path(artifact["path"])
        identity = json.loads(target.with_name("identity.json").read_text())
        if identity != dict(
            profile=artifact["profile"],
            byte_identical=True,
            size=artifact["size"],
            sha1=artifact["sha1"],
            sha256=artifact["sha256"],
        ):
            raise ValueError("Identity report differs from the release artifact")
        if target.stat().st_size != artifact["size"] or file_sha256(target) != artifact["sha256"]:
            raise ValueError("Canonical artifact differs from its current identity report")
        profile_id = artifact["profile"]
        relocated = movies.verify_relocated(profile_id)
        for scenario in ("attract", "ending"):
            report = load(f"build/runtime/{profile_id}-{scenario}.json")
            check_path = ROOT / f"scenarios/{profile_id}-{scenario}.check.json"
            check = json.loads(check_path.read_text())
            movie = check_path.parent / check["movie"]
            scenario_spec = next(row for row in matrix["scenarios"] if row["id"] == scenario)
            movies.validate_check(check, scenario_spec)
            expected = dict(
                profile=profile_id,
                scenario=scenario,
                passed=True,
                runner_sha256=file_sha256(ROOT / "scripts/runtime/movies.py"),
                artifact_sha256=file_sha256(relocated),
                check_sha256=file_sha256(check_path),
                movie_sha256=file_sha256(movie),
                emulator_sha256=load("config/toolchain.json")["emulator"]["sha256"],
            )
            if any(report.get(key) != value for key, value in expected.items()):
                raise ValueError(f"Stale runtime evidence: {profile_id}/{scenario}")


def clean_tree() -> None:
    if git("status", "--porcelain", "--untracked-files=all"):
        raise ValueError("Tag-ready audit requires a clean tracked and untracked tree")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--post-tag", action="store_true")
    args = parser.parse_args()
    try:
        spec = load("config/source_reconstruction_1_0.json")
        validate_manifest(spec)
        documents(spec)
        current_evidence(spec)
        count = history()
        # Public Core owns the external vocabulary; do not duplicate its list here.
        subprocess.run(
            [sys.executable, "-B", "-m", "retrolarium_core.stop_words", "history", str(ROOT), "--all"],
            cwd=ROOT,
            check=True,
        )
        tag = spec["tag"]
        local = subprocess.run(["git", "show-ref", "--verify", "--quiet", f"refs/tags/{tag}"], cwd=ROOT).returncode == 0
        if args.post_tag:
            if (
                not local
                or git("rev-parse", f"{tag}^{{}}") != git("rev-parse", "HEAD")
                or git("cat-file", "-t", f"refs/tags/{tag}") != "tag"
            ):
                raise ValueError("Owner-created annotated tag must name this commit")
        elif local:
            raise ValueError("Future owner-created tag already exists")
        if git("remote"):
            raise ValueError("Publishing remote checks require an explicit remote policy before adding a remote")
        clean_tree()
        report = dict(
            schema_version=1,
            passed=True,
            commit=git("rev-parse", "HEAD"),
            commits=count,
            documents=sorted(DOCUMENTS),
            checked_at=datetime.now(timezone.utc).isoformat(),
        )
        atomic_write(ROOT / "build/audits/release.json", (json.dumps(report, indent=2) + "\n").encode())
        print(f"[OK] Preservation manifest, documents, evidence and {count} commits")
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        parser.exit(1, f"error: {error}\n")
    return 0
