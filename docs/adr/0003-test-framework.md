# ADR 0003: gdUnit4 for tests

Status: accepted, 2026-10-30.

## Context

P0.5 needs one headless command that runs every test and exits non-zero on failure.

## Options

- gdUnit4 v6.2.2: 1.3k stars, MIT, released 2026-10-07. Its compatibility table stops at Godot 4.7.1, so 4.7.2 was tested directly.
- A hand-written `SceneTree` runner: no dependency, but no assertions, mocks or reports.

## Choice

gdUnit4 v6.2.2, vendored in `addons/gdUnit4` and run through `tools/test.sh`, which CI also uses.

## Consequences

- Each gdUnit4 upgrade needs a re-check against the pinned Godot version.
- The add-on is excluded from exports. Its update checker and editor UI are not used by the command-line runner.
