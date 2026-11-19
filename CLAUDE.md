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
python -m pytest -q tools
```

Tests the Python tools (art cleanup, voice bank). Needs `pillow` and `pytest` from `requirements-dev.txt`.

```bash
python tools/art_cleanup.py IN_DIR OUT_DIR --size 512x512
```

Cleans generated art: trims, hardens alpha, resizes, quantizes to `art/palette.json` and normalizes outlines. Add `--dither` for dithering. Deterministic and idempotent.

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

Plays seeded bot games between `easy`, `medium`, `hard` and `expert`, and writes `reports/tournament.csv`. Exits 1 on any illegal action. Add `--bidding`, `--seed N`, `--out PATH`, `--log PATH`, `--wild N` (1 or 2 wild ranks in every game) or `--big-bombs`. [docs/TOURNAMENT_LOG.md](docs/TOURNAMENT_LOG.md) has the formats.

```bash
godot --headless --path . --script res://tools/expert_deadline.gd -- --deals 1000 --seed 0
```

Plays Expert against Hard through `ExpertRunner` at its real deadline, 300 ms unless `--limit-usec N` says otherwise. The tournament gives Expert unlimited time, so use this for what players get. Takes hours, and reports strength and p99. Add `--wild N` for wild ranks.

```bash
godot --headless --path . --script res://tools/ladder_report.gd -- --ladders 100000
```

Draws seeded debuff ladders and writes the tier share per Set type and round to `reports/ladder_tiers.csv`. Add `--seed N` or `--out PATH`. It draws from the real pool, `data/run/debuff_pool.tres`.

```bash
git tag playtest/<name> && git push origin playtest/<name>
```

Plays the demo through its real UI on a GitHub runner with a virtual display, so no window opens locally (about 10 minutes). It fails on any misclick, hand mismatch, missing button or script error. It also renders the demo screens and every dread board state and corruption stage. Get the screenshots and log with `gh run download <run id> -n playtest`. Use this for any visual check, so nothing opens a window on the owner's screen. Locally, `godot --path . --script res://tools/playtest.gd -- --demo --rounds 6 --out reports/playtest` does the same in a window. The app starts the full eight-Year run unless it is launched with `-- --demo`.

```bash
godot --headless --path . --script res://tools/playtest.gd -- --tutorial --out reports/tutorial
```

Plays the arrival (the first-launch tutorial) from no profile to run setup with real clicks, and prints MISCLICK on a step that does not advance. Headless it names its frames without saving them. Its profile lives in `user://playtest_tutorial/`. The cloud playtest runs it after the play-through.

```bash
godot --headless --path . --script res://tools/playtest.gd -- --demo --rounds 6 --grayscale --reduced-motion --text-size 2 --out reports/playtest_access
```

Plays the same walk with a grayscale pass over the screen, reduced motion and the largest text size ([ADR 0035](docs/adr/0035-accessibility.md)), and fails on the same terms. Each flag works alone, and with `--tutorial` too. They hold for that run only and save to the tool's own settings file, never the player's. The grayscale pass is a test fixture, not a setting, and only a run with a window shows it. The cloud playtest runs this walk second, into `reports/playtest_access`. `tools/demo_screenshots.gd` takes the same three flags.

```bash
godot --headless --path . --script res://tools/perf_budget.gd -- --out reports/perf_budget.md
```

Measures the rows of the performance budget that need no window and writes a report to commit: hand classification, legal moves for a 20-card hand, the bots' decisions (Easy, Medium and Hard from seeded games, Expert through `ExpertRunner` at its real deadline), the size and the save, load and resume times of a real mid-run save from a played run in a `user://` sandbox, and the memory of a loaded run. The same command without `--headless` and with `--windowed-rows` adds startup to the title, frame time during play, nodes made during a round and resident memory with the table open; run it on the minimum-spec machines. Each row is PASS, MISS or NOT MEASURED, and NOT MEASURED is never a pass. Exits 1 when any measured row misses. Add `--seed N`, `--hands N`, `--movegen-hands N`, `--bot-deals N`, `--expert-deals N` (default 20; 0 skips Expert), `--save-sets N`, `--save-reps N`, `--frame-seconds S` or `--out PATH`. Thresholds are in `tools/perf_limits.gd`. A headless run takes about two minutes.

```bash
godot --headless --path . --script res://tools/balance.gd -- --runs 20 --jobs 4
```

Plays full runs headless (no profile, every unlock tier open, Poor Peasants) with the collective, private and mixed strategies of [ADR 0027](docs/adr/0027-balance-harness.md) on the same seeds, and writes `reports/balance_runs.csv`, `reports/balance_quotas.csv` (a row per Quota played) and `reports/balance.md`. Add `--minutes M` for a time budget, `--seed S`, `--stake K`, `--strategies a,b`, `--out DIR`, `--expert-samples N` so Expert villagers sample N deals instead of 48 (12 at least; several times faster), or `--check` to exit 1 unless mixed > private > collective > 0 holds. It exits 1 on any refused command, illegal bot action or script error. A run takes from seconds to several minutes, longest when an Expert family is seated.

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
- Every font size in `ui/` goes through `TextSize.px` (ADR 0034); art that holds a letter keeps its size.
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
