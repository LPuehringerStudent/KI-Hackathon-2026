#!/usr/bin/env bash
# One-shot demo build: sync version from git tags, then export the Linux binary.
set -euo pipefail
cd "$(dirname "$0")/.."
python3 tools/write_version.py
godot --headless --path game/godot --import >/dev/null 2>&1 || true
mkdir -p game/godot/build
godot --headless --path game/godot --export-release "Linux" build/buergermeister.x86_64
echo "game/godot/build/buergermeister.x86_64 (version: $(cat game/godot/data/version.txt))"
