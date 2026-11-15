#!/usr/bin/env python3
"""Prints the UDID of an available simulator: the named device on the newest runtime of an iOS
version (default iPhone 18 Pro on the newest iOS 27.x; `--os any` takes the newest runtime that has
the device).

    python3 scripts/simulator.py [--name "iPhone 18 Pro"] [--os 27|26.4|any]

Exit codes: 0 found, 1 no such simulator (the message lists what is available).
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from typing import List, Optional, Tuple


def runtime_version(identifier: str) -> Optional[Tuple[int, ...]]:
    """`com.apple.CoreSimulator.SimRuntime.iOS-26-4` → (26, 4); None for other platforms."""
    m = re.search(r"\.iOS-(\d+(?:-\d+)*)$", identifier)
    return tuple(int(p) for p in m.group(1).split("-")) if m else None


def pick(devices: dict, name: str, os_version: str) -> Optional[str]:
    wanted = () if os_version == "any" else tuple(int(p) for p in os_version.split("."))
    candidates = []
    for runtime, entries in devices.items():
        version = runtime_version(runtime)
        if version is None or version[:len(wanted)] != wanted:
            continue
        for d in entries:
            if d.get("name") == name and d.get("isAvailable", True):
                candidates.append((version, d.get("state") == "Booted", d["udid"]))
    if not candidates:
        return None
    candidates.sort(reverse=True)  # newest runtime first, a booted device first within it
    return candidates[0][2]


def main(argv: List[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--name", default="iPhone 18 Pro")
    parser.add_argument("--os", default="27")
    args = parser.parse_args(argv)
    listing = json.loads(subprocess.run(["xcrun", "simctl", "list", "devices", "available", "-j"],
                                        check=True, capture_output=True, text=True).stdout)
    udid = pick(listing["devices"], args.name, args.os)
    if udid is None:
        names = sorted({d["name"] for r, ds in listing["devices"].items() if runtime_version(r) for d in ds})
        print(f"No available '{args.name}' simulator on iOS {args.os}. Available: {', '.join(names)}", file=sys.stderr)
        return 1
    print(udid)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
