#!/usr/bin/env bash
# Runs every test headless. Exit code is 0 only if tests ran and all passed.
# Extra arguments go to gdUnit4, for example: tools/test.sh -a res://tests/unit/test_x.gd
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
godot="${GODOT_BIN:-godot}"
log="$(mktemp)"
trap 'rm -f "$log"' EXIT

if ! "$godot" --headless --path . --import > "$log" 2>&1; then
	cat "$log"
	exit 1
fi

if [ $# -eq 0 ]; then
	set -- -a res://tests/unit -a res://tests/integration -a res://tests/golden
fi
# The unbound debug port stops a parse error from hanging in the interactive debugger.
"$godot" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 \
	res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode "$@" 2>&1 | tee "$log"

if grep -q 'No test cases found' "$log"; then
	echo "No tests ran." >&2
	exit 1
fi
