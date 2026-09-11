#!/usr/bin/env python3
"""Write the current git version into the game so the menu always matches the tag.

Run before committing a version bump, tagging, or exporting:
    python3 tools/write_version.py

Writes game/godot/data/version.txt (git describe --tags, e.g. "v1.6.1" or
"v1.6.1-3-gabc1234"); the game falls back to the VERSION const in main.gd
when the file is missing (editor runs without the script).
"""

import subprocess
import sys
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "game" / "godot" / "data" / "version.txt"


def main():
    try:
        version = subprocess.run(
            ["git", "describe", "--tags", "--always", "--dirty"],
            capture_output=True, text=True, timeout=10,
        ).stdout.strip()
    except Exception:
        version = ""
    if not version:
        print("could not resolve git version — leaving version.txt untouched")
        sys.exit(1)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(version + "\n", encoding="utf-8")
    print(f"version.txt <- {version}")


if __name__ == "__main__":
    main()
