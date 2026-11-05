"""Structural and final evidence checks for the source/content baseline."""

from __future__ import annotations
import argparse
import json
from pathlib import Path
import re
from scripts.authoring.catalog import Catalog
from scripts.authoring.cli import inputs as content_inputs
from scripts.authoring import core_codec
from scripts.build.project import ROOT, load, checked_path, image, profiles, atomic_write
from scripts.runtime.matrix import validate as runtime_matrix
from scripts.validation import release_audit, source_layout
from scripts.validation.release import STEPS as PRESERVATION_STEPS

STEPS = (
    "release-check",
    "scaffold-check",
    "source-layout-check",
    "check-memory-layout",
    "check-content-zero-edit",
    "check-content-edits",
    "source-2-audit",
)
DOCUMENTS = {
    "README.md",
    "CONTRIBUTING.md",
    *(
        "docs/" + name + ".md"
        for name in (
            "index",
            "build",
            "architecture",
            "source_layout",
            "memory_map",
            "data_formats",
            "development",
            "authoring_toolchain",
            "revisions",
            "verification",
            "relocation",
            "runtime",
            "unknowns",
            "resolved_unknowns",
            "architecture_decisions",
            "provenance",
        )
    ),
}


def manifest(spec: dict, *, ready: bool = False) -> None:
    if any(
        spec.get(key) != value
        for key, value in dict(
            schema_version=1, release_line="2.0", release_kind="baseline", tag="source-reconstruction-2.0"
        ).items()
    ):
        raise ValueError("Source/content release boundary differs")
    if spec.get("release_commands") != list(STEPS):
        raise ValueError("Source/content gate must execute the entire preservation gate first")
    if set(spec.get("required_documents", [])) != DOCUMENTS:
        raise ValueError("Source/content documentation corpus differs")
    predecessor = spec.get("predecessor", {})
    if (
        predecessor.get("manifest") != "config/source_reconstruction_1_0.json"
        or predecessor.get("gate") != "release-check"
        or predecessor.get("tag") != "source-reconstruction-1.0"
    ):
        raise ValueError("Inherited preservation predecessor differs")
    expected = dict(
        profiles="config/revision_profiles.json",
        source_layout="config/reconstruction/source_layout.json",
        label_renames="config/reconstruction/label_renames.json",
        formats="config/authoring/data_formats.json",
        authoring_toolchain="config/authoring/toolchain.json",
        runtime="scenarios/runtime_matrix.json",
        memory_contracts="config/reconstruction/memory_contracts.json",
    )
    if spec.get("owners") != expected:
        raise ValueError("Source/content authority paths differ")
    for name in expected.values():
        checked_path(name).read_text()
    if spec.get("status") not in ("draft", "tag-ready", "tagged"):
        raise ValueError("Unknown source/content candidate status")
    if not spec.get("delta") or not spec.get("excluded_scope") or not spec.get("included_scope"):
        raise ValueError("Source/content scope and delta must be explicit")
    for row in spec["delta"]:
        if row.get("kind") not in ("source", "tooling", "evidence", "documentation") or not row.get("summary"):
            raise ValueError("Source/content delta lacks a concrete change")
    if ready:
        if spec["status"] not in ("tag-ready", "tagged"):
            raise ValueError("Source/content candidate is still a draft; no accepted predecessor is bound")
        base = predecessor.get("commit")
        if not isinstance(base, str) or not re.fullmatch("[0-9a-f]{40}", base):
            raise ValueError("Source/content predecessor commit is missing")
        if release_audit.git("merge-base", base, "HEAD") != base:
            raise ValueError("Source/content predecessor is not an ancestor")
        history = release_audit.git("rev-list", "--reverse", base + "..HEAD").splitlines()
        boundary = spec.get("delta_history", {})
        if boundary != dict(base_commit=base, tip="release-commit", commit_count=len(history)) or not history:
            raise ValueError("Source/content history boundary/count differs")
        head = release_audit.git("rev-parse", "HEAD")
        declared = [
            head if commit == "release-commit" else commit for row in spec["delta"] for commit in row["commits"]
        ]
        if len(declared) != len(set(declared)) or set(declared) != set(history):
            raise ValueError("Source/content delta does not map every substantive commit exactly once")


def documents(spec: dict) -> None:
    index = (ROOT / "docs/index.md").read_text()
    for name in spec["required_documents"]:
        path = checked_path(name)
        text = path.read_text()
        if not text.strip():
            raise ValueError("Empty source/content document")
        if name.startswith("docs/") and name != "docs/index.md" and Path(name).name not in index:
            raise ValueError("Documentation index omits a required topic")
        if len(text.splitlines()) > 600:
            raise ValueError("Documentation topic exceeds its reviewed size")
        for target in re.findall(r"\[[^\]]+\]\(([^)]+)\)", text):
            if re.match(r"[a-z]+://", target) or target.startswith("#"):
                continue
            resolved = (path.parent / target.split("#", 1)[0]).resolve()
            if not resolved.is_relative_to(ROOT) or not resolved.exists():
                raise ValueError(f"Broken documentation link:{name}:{target}")
    if (ROOT / "docs/adr").exists() or (ROOT / "docs/provenance").is_dir():
        raise ValueError("Documentation must stay in thematic root topics")
    aliases = list((ROOT / "config").rglob("label_renames.json")) + list((ROOT / "docs").rglob("*label*rename*.json"))
    if aliases != [ROOT / "config/reconstruction/label_renames.json"]:
        raise ValueError("Label rename registry is missing or duplicated")


def scaffold() -> tuple[dict, Catalog]:
    spec = load("config/source_reconstruction_2_0.json")
    manifest(spec)
    documents(spec)
    source_layout.structure()
    from scripts.validation.memory_contracts import check as check_memory

    check_memory()
    catalog = Catalog()
    runtime_matrix(load("scenarios/runtime_matrix.json"))
    revisions = load("config/revision_profiles.json")
    if revisions.get("abi") != catalog.spec["abi"]:
        raise ValueError("Revision and content ABI differ")
    for row in profiles():
        if (
            row.get("abi_reference") != "config/revision_profiles.json#/abi"
            or row.get("layout") != spec["owners"]["source_layout"]
            or row.get("content_registry") != spec["owners"]["formats"]
        ):
            raise ValueError("Revision layout/content authority differs")
        if (
            row.get("inputs") != "assets/manifest.json"
            or row.get("outputs") != "config/source_reconstruction_1_0.json#/artifacts"
            or not row.get("capabilities")
        ):
            raise ValueError("Revision inputs/outputs/capabilities missing")
    return spec, catalog


def predecessor_contract(spec: dict) -> None:
    exact = dict(
        schema_version=1,
        release_line="1.0",
        release_kind="preservation",
        tag="source-reconstruction-1.0",
        predecessor=None,
    )
    if any(spec.get(key) != value for key, value in exact.items()) or spec.get("status") not in ("tag-ready", "tagged"):
        raise ValueError("Predecessor snapshot has no preservation release contract")
    if spec.get("release_commands") != list(PRESERVATION_STEPS):
        raise ValueError("Predecessor snapshot weakens the complete preservation gate")
    requirements = spec.get("requirements", {})
    if set(requirements) != release_audit.EXPECTED_REQUIREMENTS or any(
        row.get("status") != "satisfied" or not row.get("evidence") for row in requirements.values()
    ):
        raise ValueError("Predecessor snapshot lacks preservation requirements")
    expected = {row["id"] for row in profiles()}
    declared = spec.get("profiles", [])
    artifacts = spec.get("artifacts", [])
    if (
        len(declared) != len(expected)
        or {row.get("id") for row in declared} != expected
        or any(row.get("identity") != "byte-identical" or row.get("status") != "supported" for row in declared)
    ):
        raise ValueError("Predecessor snapshot does not preserve every accepted profile")
    if len(artifacts) != len(expected) or {row.get("profile") for row in artifacts} != expected:
        raise ValueError("Predecessor preservation artifacts are missing or duplicated")
    for row in artifacts:
        owner = image(row["profile"])
        if any(row.get(key) != owner[key] for key in ("size", "sha1", "sha256")):
            raise ValueError("Predecessor preservation artifact identity differs")


def evidence(spec: dict, catalog: Catalog) -> None:
    manifest(spec, ready=True)
    predecessor = spec["predecessor"]
    predecessor_contract(json.loads(release_audit.git("show", f"{predecessor['commit']}:{predecessor['manifest']}")))
    source_layout.origins(predecessor["commit"])
    core_codec.resolve()
    from scripts.validation.memory_contracts import check as check_memory
    from scripts.authoring.edited_containers import audit as audit_edits

    check_memory(built=True)
    audit_edits()
    preservation = load("build/release/preservation.json")
    head = release_audit.git("rev-parse", "HEAD")
    if (
        preservation.get("passed") is not True
        or preservation.get("commit") != head
        or preservation.get("steps") != list(PRESERVATION_STEPS)
    ):
        raise ValueError("Complete current preservation gate evidence is missing")
    report = load("build/authoring/zero-edit.json")
    if report.get("passed") is not True or report.get("inputs") != content_inputs():
        raise ValueError("Content export evidence is missing or stale")
    rows = report.get("rows", [])
    if (
        report.get("owners") != len(catalog.items)
        or len(rows) != len(catalog.items)
        or {row["owner"] for row in rows} != set(catalog.items)
    ):
        raise ValueError("Content export owner matrix differs")
    for row in rows:
        item = catalog.select(row["owner"])
        raw, _ = catalog.read(item)
        from scripts.build.project import sha256

        if (
            row.get("input_sha256") != sha256(raw)
            or row.get("profile") != item["profile"]
            or row.get("codec") != item["codec"]
            or not all(row.get(key) is True for key in ("unchanged", "byte_exact", "semantic"))
        ):
            raise ValueError("A content owner lacks current zero-edit proof")
    expected = [
        dict(profile=row["id"], size=image(row["id"])["size"], sha256=image(row["id"])["sha256"], byte_identical=True)
        for row in profiles()
    ]
    if report.get("rebuilt_profiles") != expected:
        raise ValueError("Zero-edit export did not rebuild every preservation profile")
    for row in profiles():
        source_layout.actual(row["id"])
    release_audit.history()
    release_audit.clean_tree()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scaffold", action="store_true")
    args = parser.parse_args()
    try:
        spec, catalog = scaffold()
        if not args.scaffold:
            evidence(spec, catalog)
        report = dict(
            schema_version=1,
            passed=True,
            scope="scaffold" if args.scaffold else "source_content_release",
            candidate_status=spec["status"],
            owners=len(catalog.items),
        )
        atomic_write(
            ROOT / ("build/audits/scaffold.json" if args.scaffold else "build/audits/source-2.json"),
            (json.dumps(report, indent=2) + "\n").encode(),
        )
        print(f"[OK] {report['scope']}:{len(catalog.items)}content views,candidate status{spec['status']}")
    except (OSError, ValueError, KeyError, TypeError) as error:
        parser.exit(1, f"error:{error}\n")
    return 0
