"""Check declared hardware boundaries against every canonical AS listing."""

import argparse
import json
from scripts.build.listing import symbols
from scripts.build.project import ROOT, atomic_write, load, profiles


def run() -> dict:
    policy = load("config/reconstruction/address_policy.json")
    evidence = []
    for selected in profiles():
        regions = [item for item in policy["fixed_regions"] if selected["id"] in item.get("profiles", [selected["id"]])]
        wanted = {item[key] for item in regions for key in ("first", "last") if key in item}
        wanted |= {name for item in regions for name in item.get("symbols", {})}
        wanted |= {item["decoded_end_symbol"] for item in regions if "decoded_end_symbol" in item}
        table = symbols(ROOT / "build/artifacts" / selected["id"] / "entry.lst", wanted)
        for item in regions:
            if item.get("first") and table[item["first"]] != item["start"]:
                raise ValueError(f"{selected['id']}: {item['id']} start moved")
            if item.get("last") and table[item["last"]] != item["end"] % 0x1000000:
                raise ValueError(f"{selected['id']}: {item['id']} end moved")
            for name, address in item.get("symbols", {}).items():
                if table[name] != address:
                    raise ValueError(f"{selected['id']}: fixed hardware symbol {name} moved")
            if "decoded_end_symbol" in item:
                container = next(
                    value
                    for value in load("config/build/derived_assets.json")["containers"]
                    if value["image"] == selected["image"]
                )
                end = table[item["decoded_end_symbol"]]
                if end != container["decoded_size"] or end > table["z80_stack"]:
                    raise ValueError("DAC code and samples exceed their declared Z80 RAM boundary")
            evidence.append(
                {"profile": selected["id"], "region": item["id"], "start": item["start"], "end": item["end"]}
            )
    return {"schema_version": 1, "checked_regions": evidence}


def main() -> int:
    argparse.ArgumentParser(description=__doc__).parse_args()
    try:
        report = run()
    except (OSError, ValueError) as error:
        raise SystemExit(f"error: {error}") from error
    atomic_write(ROOT / "build/audits/fixed-regions.json", (json.dumps(report, indent=2) + "\n").encode())
    print(f"[OK] Fixed hardware/header regions: {len(report['checked_regions'])} profile-region checks")
    return 0
