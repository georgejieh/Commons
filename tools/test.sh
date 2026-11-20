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
# A test that loops must not fill the disk: a stack overflow that printed without end
# once did. The run is ended when it passes TEST_TIMEOUT seconds or its output passes
# TEST_LOG_MAX bytes, and either fails it.
limit="${TEST_TIMEOUT:-3600}"
cap="${TEST_LOG_MAX:-200000000}"
# The unbound debug port stops a parse error from hanging in the interactive debugger.
"$godot" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 \
	res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode --continue "$@" > "$log" 2>&1 &
run=$!
tail -n +1 -f "$log" &
show=$!
trap 'kill "$run" "$show" 2> /dev/null || true; rm -f "$log"' EXIT
ended=""
while kill -0 "$run" 2> /dev/null; do
	if [ "$(wc -c < "$log")" -ge "$cap" ]; then
		ended="its output passed $cap bytes"
	elif [ "$SECONDS" -ge "$limit" ]; then
		ended="it ran past $limit seconds"
	fi
	if [ -n "$ended" ]; then
		kill "$run" 2> /dev/null || true
		break
	fi
	sleep 1
done
status=0
wait "$run" 2> /dev/null || status=$?
# One more second, so the last lines are shown before the log stops being followed.
sleep 1
kill "$show" 2> /dev/null || true
wait "$show" 2> /dev/null || true
if [ -n "$ended" ]; then
	echo "The run was ended: $ended." >&2
	exit 1
fi
if [ "$status" -ne 0 ]; then
	exit "$status"
fi

if grep -q 'No test cases found' "$log"; then
	echo "No tests ran." >&2
	exit 1
fi
# An honest run never trips the file's detectors (ADR 0022). A test that trips one on
# purpose takes the line itself, so it never reaches the output.
if grep -q 'COMMONS FILE MISMATCH' "$log"; then
	echo "A file detector logged a mismatch." >&2
	exit 1
fi
