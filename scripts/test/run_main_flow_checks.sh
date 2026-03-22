#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"

echo "[1/2] Running headless main flow smoke test"
"$GODOT_BIN" --headless \
  --path "$ROOT_DIR" \
  --log-file /tmp/game-main-flow-smoke.log \
  --scene res://tests/smoke/MainFlowSmoke.tscn

echo "[2/2] Running GdUnit main flow scene tests"
mkdir -p "$ROOT_DIR/reports/gdunit"
"$GODOT_BIN" --headless \
  --path "$ROOT_DIR" \
  --log-file /tmp/game-gdunit.log \
  -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
  -a tests/gdunit \
  -rd res://reports/gdunit \
  --ignoreHeadlessMode \
  -c
