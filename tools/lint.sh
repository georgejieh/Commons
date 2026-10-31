#!/usr/bin/env bash
# Lints and format-checks project GDScript. Vendored addons are skipped.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

mapfile -t files < <(git ls-files --cached --others --exclude-standard '*.gd' ':!:addons/*')

if command -v gdlint > /dev/null; then
	gdlint "${files[@]}"
	gdformat --check "${files[@]}"
else
	uvx --from "$(cat requirements-dev.txt)" gdlint "${files[@]}"
	uvx --from "$(cat requirements-dev.txt)" gdformat --check "${files[@]}"
fi
