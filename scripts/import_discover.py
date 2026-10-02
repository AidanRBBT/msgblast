#!/usr/bin/env python3
"""Refresh the bundled direct-SMS directory and its original service icons.

Usage: python3 scripts/import_discover.py [--catalog /path/to/catalog.json]
Requires curl and macOS sips. Never contacts messaging destinations.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
import json
from pathlib import Path
import re
import subprocess
import tempfile
from zoneinfo import ZoneInfo

ROOT = Path(__file__).resolve().parents[1]
SOURCE = "https://www.imessage.store/api/app/catalog"
DEST = ROOT / "MsgBlast/Resources/Discover"


def download(url, path):
    subprocess.run(["curl", "--location", "--fail", "--silent", "--show-error", "--max-time", "40", url, "--output", str(path)], check=True)


def direct_agents(catalog):
    groups = {}
    for entry in catalog["agents"]:
        if re.fullmatch(r"sms:\+[0-9]{5,15}", entry.get("sms") or ""):
            groups.setdefault(entry["sms"], []).append(entry)
    result = []
    for sms, listings in groups.items():
        # Prefer the short canonical Bo listing, retaining both source categories.
        entry = next((a for a in listings if a["slug"] == "bo"), listings[0])
        result.append({
            "id": entry["slug"], "name": entry["name"], "tagline": entry["tag"],
            "categories": list(dict.fromkeys([entry["category"]] + [a["category"] for a in listings])),
            "website": entry["site"], "smsURL": sms, "number": sms[4:],
            "icon": entry["slug"] + ".png", "iconSource": entry["logo"],
            "sourceListings": ["https://www.imessage.store/agent/" + a["slug"] for a in listings],
        })
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog", type=Path)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="msgblast-discover-") as scratch:
        scratch = Path(scratch)
        source = args.catalog or scratch / "source.json"
        if not args.catalog:
            download(SOURCE, source)
        catalog = json.loads(source.read_text())
        agents = direct_agents(catalog)
        icons = scratch / "icons"
        icons.mkdir()

        def icon(agent):
            original = scratch / (agent["id"] + ".original")
            try:
                download(agent["iconSource"], original)
                subprocess.run(["sips", "--resampleHeightWidthMax", "160", "--setProperty", "format", "png", str(original), "--out", str(icons / agent["icon"])], check=True, stdout=subprocess.DEVNULL)
                return "Icon: " + agent["id"]
            except subprocess.CalledProcessError:
                agent["icon"] = None
                return "Source icon unavailable: " + agent["id"]

        with ThreadPoolExecutor(max_workers=6) as pool:
            for slug in pool.map(icon, agents):
                print(slug, flush=True)
        # Broken source images use initials in the app; never invent a service's logo.
        import shutil
        DEST.mkdir(parents=True, exist_ok=True)
        if (DEST / "icons").exists():
            shutil.rmtree(DEST / "icons")
        shutil.copytree(icons, DEST / "icons")
        snapshot = {
            "source": SOURCE,
            "importedOn": datetime.now(ZoneInfo("America/Los_Angeles")).date().isoformat(),
            "sourceAgentCount": len(catalog["agents"]),
            "directListingCount": sum(len(a["sourceListings"]) for a in agents),
            "unavailableIcons": [a["id"] for a in agents if a["icon"] is None],
            "categoryOrder": catalog["topicOrder"], "agents": agents,
        }
        (DEST / "catalog.json").write_text(json.dumps(snapshot, ensure_ascii=False, indent=2) + "\n")
        print(f"Imported {len(agents)} unique direct numbers from {snapshot['directListingCount']} listings; excluded {snapshot['sourceAgentCount'] - snapshot['directListingCount']} website-only listings.")


if __name__ == "__main__":
    main()
