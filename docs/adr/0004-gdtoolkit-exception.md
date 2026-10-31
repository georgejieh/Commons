# ADR 0004: Keep gdtoolkit past the 12-month bar

Status: accepted, 2026-10-30.

## Context

P0.4 names gdtoolkit. Its latest release, 4.5.0, is from 2025-10-09, so it misses the "release or commit in the last 12 months" bar by three weeks. It predates Godot 4.7.

## Options

- gdtoolkit 4.5.0: 1.6k stars, MIT, named by the checklist. It parsed 60 of 60 sampled Godot 4.7 add-on scripts.
- GDQuest/GDScript-formatter 0.28.0: actively released, MIT, 484 stars, and not named by the checklist.

## Choice

Keep gdtoolkit 4.5.0, pinned in `requirements-dev.txt`. It runs only in development and CI, so it never ships.

## Consequences

- New GDScript syntax may fail to parse. If that happens, move to GDScript-formatter with a new ADR.
- Re-check for a gdtoolkit release when Godot is upgraded.
