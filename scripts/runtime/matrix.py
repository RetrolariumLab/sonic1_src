"""Require direct coverage of every accepted profile and both release scenarios."""

from scripts.build.project import profiles


def validate(matrix: dict) -> None:
    required = {"attract", "ending"}
    scenarios = matrix.get("scenarios", [])
    if len(scenarios) != len(required) or {row.get("id") for row in scenarios} != required:
        raise ValueError("Runtime scenario set differs from the release boundary")
    expected = {row["id"] for row in profiles()}
    rows = matrix.get("profiles", [])
    if len(rows) != len(expected) or {row.get("profile") for row in rows} != expected:
        raise ValueError("Runtime profiles are missing, duplicated or unsupported")
    for row in rows:
        entries = row.get("scenarios", [])
        if len(entries) != len(required) or {entry.get("id") for entry in entries} != required:
            raise ValueError("Each profile needs direct coverage of every required scenario")
        for entry in entries:
            if entry.get("check") != f"scenarios/{row['profile']}-{entry['id']}.check.json":
                raise ValueError("Runtime check path does not belong to its profile and scenario")
    for scenario in scenarios:
        expected_machine = "genesis" if scenario["id"] == "attract" else "megadrij"
        expected_frames = 15000 if scenario["id"] == "attract" else 18000
        if scenario.get("machine") != expected_machine or scenario.get("frames") != expected_frames:
            raise ValueError("Runtime machine or duration differs from the release boundary")
        if scenario.get("checkpoint_step") != 60 or not scenario.get("required_states"):
            raise ValueError("Runtime checkpoints and reached-state predicates are required")
        if scenario.get("setup", {}).get("ram_patches") != [] or scenario.get("setup", {}).get("save_states") != []:
            raise ValueError("Release scenarios use original controller inputs without injected state")
