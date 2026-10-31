# ADR 0006: String table as a Godot CSV translation

Status: accepted, 2026-10-31.

## Context

P1A.1 needs display labels behind string keys, and the conventions require one English string table. No item names its format, and the string table autoload arrives only with P3B.2.

## Options

- Godot's CSV translation importer: built in, loaded through project settings, read with `tr()`.
- A typed Resource holding a dictionary: no import step, but custom code for what the engine already does.

## Choice

`data/strings/strings.csv` with one `en` column, imported to `strings.en.translation` and registered in `project.godot`. `core/` holds keys only and never calls `tr()`. Presentation resolves them.

## Consequences

- The compiled `.translation` file is committed through Git LFS, so a fresh clone does not report a missing resource before its first import. Re-import after editing the CSV.
- The game stays English only, so the CSV keeps one language column.
