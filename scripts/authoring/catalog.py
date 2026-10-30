"""Resolve content views from authoritative extraction and checked AS ownership."""

from __future__ import annotations
from pathlib import Path
import json
from scripts.build.project import ROOT, load, profile, image, sha1, sha256, file_sha256, checked_path
from scripts.build.sources import fingerprint
from scripts.build.listing import symbols
from scripts.validation.source_layout import actual


class Catalog:
    def __init__(self):
        self.spec = load("config/authoring/data_formats.json")
        self.items = {row["id"]: row for row in self.spec["artifacts"]}
        if len(self.items) != len(self.spec["artifacts"]):
            raise ValueError("Duplicate content owner")
        self.assets = {
            name: {row["path"]: row for row in load(name)["assets"]}
            for name in ("assets/manifest.json", "config/build/derived_assets.json")
        }
        self.builds = {}
        self.coverage()

    def coverage(self):
        seen = set()
        formats = {row["id"] for row in self.spec["formats"]}
        transports = {row["id"] for row in self.spec["transports"]}
        for row in self.items.values():
            profile(row["profile"])
            if (
                row["abi"] != self.spec["abi"]
                or row["codec"] not in formats
                or row.get("compression") not in transports | {None}
            ):
                raise ValueError("Content ABI/codec/transport differs")
            if type(row["decoded_capacity"]) is not int or row["decoded_capacity"] <= 0:
                raise ValueError("Content destination has no bounded capacity")
            source = row["source"]
            kind = source["kind"]
            if kind == "asset":
                owner = self.assets[source["manifest"]][source["path"]]
                if owner["image"] != row["profile"]:
                    raise ValueError("Extraction/profile binding differs")
                key = (source["manifest"], source["path"])
                if key in seen:
                    raise ValueError("Duplicate extraction view")
                seen.add(key)
            elif kind == "module":
                checked_path(source["path"])
            elif kind != "symbol":
                raise ValueError("Unknown content source kind")
        layout = load("config/reconstruction/source_layout.json")
        expected_modules = {
            (selected["profile"], selected["source"]["path"])
            for selected in self.items.values()
            if selected["source"]["kind"] == "module"
        }
        actual_modules = {
            (profile_id, row["path"])
            for row in layout["modules"]
            if any(part in row["path"] for part in ("/mappings/", "/animation/", "/demos/"))
            for profile_id, ranges in row["ranges"].items()
            if any(part["address_space"] == "m68000_rom" and part["end"] > part["start"] for part in ranges)
        }
        if actual_modules != expected_modules:
            raise ValueError("Content registry does not cover every compiled mapping, animation and demo owner")
        expected = {(manifest, path) for manifest, assets in self.assets.items() for path in assets}
        if seen != expected:
            raise ValueError("Content registry does not cover every extraction owner")

    def select(self, identifier: str) -> dict:
        if identifier not in self.items:
            raise ValueError("Unknown content owner")
        return self.items[identifier]

    def built(self, profile_id: str) -> dict:
        if profile_id not in self.builds:
            directory = ROOT / "build/artifacts" / profile_id
            inputs = json.loads((directory / "inputs.json").read_text())
            if inputs != fingerprint():
                raise ValueError("AS content artifacts are stale; rebuild this profile")
            raw = (directory / "sonic1.bin").read_bytes()
            if sha256(raw) != image(profile_id)["sha256"]:
                raise ValueError("Content requires a byte-identical preservation build")
            self.builds[profile_id] = dict(raw=raw, layout=actual(profile_id), directory=directory, inputs=inputs)
        return self.builds[profile_id]

    def read(self, item: dict) -> tuple[bytes, dict]:
        source = item["source"]
        kind = source["kind"]
        if kind == "asset":
            owner = self.assets[source["manifest"]][source["path"]]
            raw = checked_path(source["path"], ROOT / "data").read_bytes()
            if len(raw) != owner["size"] or sha1(raw) != owner["sha1"]:
                raise ValueError("Private content differs from its extraction owner")
            return raw, dict(slot=owner["size"], offset=owner["offset"], source_kind=kind)
        built = self.built(item["profile"])
        if kind == "module":
            # The title-card view deliberately includes its Game Over child;
            # source_layout still owns the underlying source bytes exclusively.
            frames = [
                row
                for row in built["layout"]["includes"]
                if row["path"] == source["path"] and row["address_space"] == "m68000_rom"
            ]
            if len(frames) != 1:
                raise ValueError("Content module must have one active include view")
            start, end = frames[0]["start"], frames[0]["end"]
        else:
            start = symbols(built["directory"] / "entry.lst", {source["first"]})[source["first"]]
            end = start + source["bytes"]
            owners = [
                (path, part)
                for path, parts in built["layout"]["ranges"].items()
                for part in parts
                if part["address_space"] == "m68000_rom" and part["start"] <= start and end <= part["end"]
            ]
            if len(owners) != 1:
                raise ValueError("Symbol content crosses its exclusive source owner")
        if not 0 <= start < end <= len(built["raw"]):
            raise ValueError("Content view crosses ROM")
        events = [
            dict(kind=row["kind"], offset=row["address"] - start)
            for row in built["layout"]["events"]
            if start <= row["address"] < end
        ]
        context = dict(slot=end - start, offset=start, events=events, source_kind=kind)
        if item["codec"] == "palette_cycle":
            context["source_palettes"] = [
                (row["offset"], row["offset"] + row["size"])
                for row in self.assets["assets/manifest.json"].values()
                if row["image"] == item["profile"] and "/palette/Cycle - SBZ " in row["path"]
            ]
            bounds = symbols(built["directory"] / "entry.lst", {"v_palette"})["v_palette"] & 65535
            context["palette_ram"] = (bounds, bounds + 128)
        return built["raw"][start:end], context
