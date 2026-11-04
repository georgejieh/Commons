# ADR 0017: Demo first, and a 2D/3D comparison

## Status

Accepted by the project owner on 2026-11-03.

## Context

The project owner wants a playable demo to test by hand before the rest of Phase 3B, and two versions of it to compare: the full-2D table the Plan decided on, and a 3D table built from Blender models. Working strictly in checklist ID order would finish all of Phase 3B, including dread layers and voices, before anything is playable. A Year with a shop also needs content from Phase 4.

## Options

1. Keep strict ID order and build the demo at the end of Phase 3B.
2. Build to a demo first, pulling only what a one-Year demo needs, in two table views over one game layer.

## Choice

Option 2. The demo is one Year (3 Sets) with a state store and about 10 Cadres, the Plan's phase 3 gate.

- **Pulled forward:**
  - P3B.0 through P3B.6, P3B.8, P3B.10, and a subset of P3B.9;
  - P3B.11 for mouse and keyboard only;
  - parts of P4.10 (state store only), P4.11 (the Plan's Cadres that current hooks support) and P4.12 (the debuffs that current hooks support);
  - the manifest logging part of P3C.2.
- **Deferred until after the comparison:** P3B.7, P3B.12, P3B.13, gamepad input, the 1280×800 check and the remaining screens.
- **Both tables are views of one game layer.** The 2D and 3D tables are two views of the same `RunController` and `HandModel`. Menus and other screens are 2D in both.
- **The 3D table is an experiment** against the Plan's "Decided: full 2D". Its models come from `bpy` scripts in `tools/blender/`, so they can be rebuilt, and its textures are logged in the art manifest.
- **Commits.** Demo-only work is tagged `DEMO` in commit messages. Work that belongs to a checklist item carries that ID. A checklist box is ticked only when its whole "Done when" is verified.
- **Dev-only autoloads are allowed.** The autoload check in P3B.2 allows the Godot AI add-on's dev-only autoload, because export presets exclude that add-on.

## Consequences

- After the comparison, the owner picks one direction. The other table is deleted, or the Plan's art pipeline section is rewritten for 3D in a new ADR.
- Partly done items stay unticked, with notes saying what the demo covers. The checklist order resumes from there.
- The 3D path adds Blender as a development tool, which goes into `docs/DEPENDENCIES.md`.
