# Architecture

This file changes in the same commit as any architecture change. Decisions and their reasons are in [adr/](adr/).

## Layers

Dependencies run one way: `ui` → `game` → `core`. `core` may read definitions from `data`. Nothing in `core` references `game` or `ui`.

| Folder | Holds |
| --- | --- |
| `core/` | Pure logic: model, rules, modifiers, scoring, bots, run. No nodes, scenes, autoloads or I/O |
| `data/` | Resource definitions and the string table ([ADR 0006](adr/0006-string-table.md)) |
| `game/` | Controllers that bridge `core` to scenes |
| `ui/` | Scenes and themes |
| `art/`, `audio/`, `shaders/` | Assets |
| `tests/` | Unit, integration and golden tests |
| `tools/` | Asset scripts and headless harnesses |

`tools/layer_check.gd` enforces the `core/` rules, and the test suite runs it. It reads base types and global classes from Godot and separates code from strings. It fails on a path outside `core/` and `data/`, a relative or `uid://` path, runtime `load()`, a Node subclass, a scene, a global class outside those folders, autoload or scene tree access, or an engine singleton other than the math ones.

`tools/script_check.gd` makes every project script compile in the test suite, because exports tokenize scripts without type checking.
