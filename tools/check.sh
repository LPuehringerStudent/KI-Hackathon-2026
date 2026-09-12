#!/usr/bin/env bash
# Full gate before a merge or a demo: refresh the asset import cache, run every headless suite,
# then smoke-test the project the way the release binary is checked.
#
#   tools/check.sh [path-to-godot]
#
# The import step is not optional: a stale .godot/imported silently drops the 3D props (the .glb
# fails to load and the river renders empty), and only the smoke test's models= flag catches it.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${1:-godot}"
PROJECT="game/godot"

echo "== import assets"
"$GODOT" --headless --path "$PROJECT" --import >/dev/null

LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

for suite in run_tests run_data_tests run_panel_tests run_integration_tests run_menu_tests; do
	echo "== $suite"
	if ! "$GODOT" --headless --path "$PROJECT" -s "res://tests/$suite.gd" >"$LOG" 2>&1; then
		grep -E "^FAIL" "$LOG" || tail -20 "$LOG"
		echo "FAILED: $suite"
		exit 1
	fi
	grep -E "^SKIP|passed" "$LOG" || echo "  ok"
done

echo "== proxy client"
python3 tools/check_proxy_client.py "$GODOT" >/dev/null

echo "== smoke test"
"$GODOT" --headless --path "$PROJECT" -- --smoke-test | grep SMOKE

echo "ALL GREEN"
