#!/usr/bin/env bash
# Starts a build headless. Fails on a nonzero exit or any reported error, because a
# Godot build exits 0 even when its main scene's script failed to compile.
set -uo pipefail
log="$(mktemp)"

"$@" --headless --quit 2>&1 | tee "$log"
status="${PIPESTATUS[0]}"

if [ "$status" -ne 0 ]; then
	exit "$status"
fi
if grep -qE 'SCRIPT ERROR|^ERROR:' "$log"; then
	echo "The build reported errors." >&2
	exit 1
fi
