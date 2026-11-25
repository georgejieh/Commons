#!/usr/bin/env bash
# Lints and format-checks project GDScript (gdlint, gdformat) and the Python tools (ruff).
# Vendored addons are skipped.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

files=()
while IFS= read -r file; do
	files+=("$file")
done < <(git ls-files --cached --others --exclude-standard '*.gd' ':!:addons/*')

if command -v gdlint > /dev/null; then
	gdlint "${files[@]}"
	gdformat --check "${files[@]}"
else
	uvx --from "$(grep -m1 "^gdtoolkit" requirements-dev.txt)" gdlint "${files[@]}"
	uvx --from "$(grep -m1 "^gdtoolkit" requirements-dev.txt)" gdformat --check "${files[@]}"
fi

if command -v ruff > /dev/null; then
	ruff check tools
	ruff format --check tools
else
	uvx --from "$(grep -m1 "^ruff" requirements-dev.txt)" ruff check tools
	uvx --from "$(grep -m1 "^ruff" requirements-dev.txt)" ruff format --check tools
fi
