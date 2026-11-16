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

# Tests keep their own settings file, started fresh each run, so no test reads or writes
# the player's settings.
export COMMONS_SETTINGS="user://test_run_settings.cfg"
if [ -n "${APPDATA:-}" ]; then
	user_dir="$APPDATA/Godot/app_userdata/Commons"
elif [ "$(uname)" = "Darwin" ]; then
	user_dir="$HOME/Library/Application Support/Godot/app_userdata/Commons"
else
	user_dir="${XDG_DATA_HOME:-$HOME/.local/share}/godot/app_userdata/Commons"
fi
rm -f "$user_dir/test_run_settings.cfg"

if [ $# -eq 0 ]; then
	set -- -a res://tests/unit -a res://tests/integration -a res://tests/golden
fi
# The unbound debug port stops a parse error from hanging in the interactive debugger.
"$godot" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 \
	res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode --continue "$@" 2>&1 | tee "$log"

if grep -q 'No test cases found' "$log"; then
	echo "No tests ran." >&2
	exit 1
fi
