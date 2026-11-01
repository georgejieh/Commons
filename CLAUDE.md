# Commons

A single-player roguelike deckbuilder in Godot 4.7.2, built on Fight the Landlord.

The design is in [docs/PLAN.md](docs/PLAN.md). The ordered work is in [docs/CHECKLIST.md](docs/CHECKLIST.md). Both are local and gitignored, so a fresh clone does not have them. Read "How agents use this checklist" before starting an item; it is binding.

Architecture is in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), decisions in [docs/adr/](docs/adr/), and third-party code in [docs/DEPENDENCIES.md](docs/DEPENDENCIES.md).

## Commands

Run these from the repository root, in Bash. `godot` must be Godot 4.7.2; set `GODOT_BIN` if it has another name. `tools/lint.sh` needs `gdlint` and `gdformat` from `requirements-dev.txt`, or `uvx`.

```bash
git config core.hooksPath .githooks
```

Enables the lint hook, once per clone.

```bash
godot --headless --path . --import
```

Imports the project. Needed once on a fresh clone before anything else that uses Godot directly.

```bash
bash tools/test.sh
```

Runs every test, including the layer check and a check that every project script compiles. Exits 0 only if tests ran and all passed. Reports go to `reports/`.

```bash
bash tools/lint.sh
```

Lints and format-checks project GDScript. Add-ons are skipped.

```bash
godot --headless --path . --script res://tools/check_layers.gd
```

Checks the `core/` layer rules on their own. `tools/test.sh` covers them too.

```bash
godot --headless --path . --export-release Windows build/windows/Commons.exe
```

Exports a Windows build. Create `build/windows` first. `Linux` works the same way, with `build/linux/Commons.x86_64`.

```bash
godot --headless --path . --script res://tools/tournament.gd -- --games 200 --a medium --b easy
```

Plays seeded bot games between `easy`, `medium`, `hard` and `expert`, and writes `reports/tournament.csv`. Exits 1 on any illegal action. Add `--bidding`, `--seed N`, `--out PATH` or `--log PATH`. [docs/TOURNAMENT_LOG.md](docs/TOURNAMENT_LOG.md) has the formats.

Balance commands arrive with P4.16. Add them here when they work.

## Layers

Dependencies run `ui` → `game` → `core`. `core` may read `data` definitions. Nothing in `core` references `game` or `ui`.

- `core/` is pure logic: no Node subclasses, scenes, autoloads, file or network I/O, runtime `load()`, or engine singletons except math. It must run headless. `preload` is allowed for `core/` and `data/`.
- Presentation never mutates game state. It sends commands to a controller and renders the events it receives.
- Content definitions are data. Their behavior lives in small effect scripts registered by ID, with no logic in `.tres` files.

## Conventions

- Static typing on every variable, parameter, return value and array. Untyped declarations fail to load. Godot does not enforce typed arrays and dictionaries, so write `Array[int]` yourself.
- All randomness goes through the seeded stream service. Global random functions and array shuffle are forbidden in `core/`.
- Every tunable number lives in data Resources. Structural constants are named constants.
- Every player-facing string lives in one English string table and is referenced by key. The game is English only.
- One class per file, files under about 400 lines, functions under about 50 lines, composition over inheritance. Exceeding a limit needs a one-line justification comment.
- Build only what a checklist item asks for. No abstraction until a second concrete use exists.
- Check Godot built-ins first, then a vetted add-on, then custom code. Vendor add-ons in `addons/` at a pinned version and record them in `docs/DEPENDENCIES.md`.

## Working rules

- Work in checklist ID order. One concern per commit, with the item ID in the message.
- Never mark an item complete while any test, lint check or warning-as-error fails. Each "Done when" needs a run, not inspection.
- If an item needs a decision the docs don't cover, write an ADR in `docs/adr/`, mark the item blocked and stop for a human.
- When an item changes architecture, update `docs/ARCHITECTURE.md` in the same change.
- `main` is protected. Work on a branch and open a pull request; `lint`, `test` and `export` must pass.
- Releases come from `vX.Y.Z` tags on `main`. A pull request that changes packaging runs the release without publishing.
- `addons/godot_ai` and `addons/gdUnit4` never ship. Export presets exclude them, and `tools/` and `tests/`.
- Start Claude Code before opening the Godot editor, so the editor attaches to the running Godot AI server.
- Binary assets go through Git LFS. Check `.gitattributes` before adding a new type.

## Skills

Project skills are in `.claude/skills/`: Godot and game design references, plus `commons-prose` for all game text, `commons-bgm` for Suno music and `commons-sfx` for sound effects. Use them for that work.
