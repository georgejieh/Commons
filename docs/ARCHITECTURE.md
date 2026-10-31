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

`tools/layer_check.gd` enforces the `core/` rules, and the test suite runs it. It reads base types and global classes from Godot and separates code from strings. It scans `core/` and `data/`, so a data script cannot smuggle randomness in. It fails on a path outside `core/` and `data/`, a relative or `uid://` path, runtime `load()`, a Node subclass, a scene, a global class outside those folders, autoload or scene tree access, an engine singleton other than the math ones, a card setter outside `CardModifiers`, a global random function, array shuffle or pick by call, reference or name, access to `_rng`, `tr()`, runtime code evaluation, or an engine generator outside the stream service.

`tools/script_check.gd` makes every project script compile in the test suite, because exports tokenize scripts without type checking.

## Randomness

Each run has one `RandomStreams` with six independent streams: deal, shop, debuff, ai, events, cosmetic. A stream's seed is an FNV-1a hash of the run seed and its name, so adding a stream never disturbs the others. `core/` code takes a `RandomStream` and never touches an engine generator. Seeds and states serialize as text, because JSON numbers cannot hold 64 bits.

## Rules

`core/rules/` is the rules engine. Everything works on rank counts, so suits never affect legality.

| Piece | Job |
| --- | --- |
| `RuleSet` | Frozen legality parameters, built from a `RuleParams` Resource |
| `Pattern` | One play as ranks, with a comparison key fixed at construction |
| `Classifier` | Reads one Pattern from a count vector in O(15) ([ADR 0007](adr/0007-classifier-rules.md)) |
| `PlayComparator` | Decides whether one play beats another |
| `MoveGenerator` | Lists every legal Pattern for a hand |
| `CardSelection` | Maps a Pattern to card instances, and a player's picks back to a Pattern |
| `Bidding`, `LandlordSeat` | Call and grab, and who holds the seat across a Set |
| `RoundState` | One round. `apply()` is its only mutator, and it returns a reason code or emits `RoundEvent`s |

Patterns store base ranks. Only the comparison key uses the effective rank map, so chains stay adjacent in base ranks whatever a modifier does to rank order.

### Information boundary

A bot receives a `SeatView` and nothing else: a `PublicView` plus copies of its own hand. Every field of a view is an independent copy with no link back to the round, so a bot can neither reach another seat's hand nor change the round by editing what it holds. A test walks every object reachable from a `SeatView`, and another edits a view and checks the round is unchanged. The round copies the hands it is given and never hands out a `Hand`; `action_for()` turns a Pattern into an action on the controller side.

## Bots

`core/bots/` holds the bots. `Bot` is the only way the game asks for a decision, and a test fails if `core/`, `game/` or `ui/` reaches past it. Bots stay pure: a `BotBudget` carries an injected clock, worker threads live in `game/bots/`, and a `BotRationale` code replaces debug text, whose words live in `tools/` so they never ship ([ADR 0009](adr/0009-bots-and-the-core-boundary.md)).

`HandDecomposer` finds the fewest plays that empty a hand: a memoized search over chains, with a closed-form count for the rest in `DecompositionLeaf`. One instance serves one decision, so all its candidates share the memo. Quads stay bombs unless a chain takes from them, and trios stay whole, so its optimum is over those groups, not over every legal play. Four-with-two is left out for the same reason.

## Modifiers

Every Cadre, Campaign, Directive, Reform, debuff and boss twist is a `ModifierDef` Resource in `data/modifiers/`. Its behavior is a small `ModifierEffect` script registered by ID in `EffectRegistry`. `ModifierValidator` checks each definition against the hook list, its effect and the string table.

`ModifierStack` runs hooks in one order: active Cadres in slot order left to right, then active debuffs in ladder order, then the boss twist. `SeatRules` caches one RuleSet and one effective-rank map per seat, rebuilt behind a dirty flag when a modifier changes or a round starts, or when a bomb changes the trick's state. `RoundState` calls `refresh()` before each action, and queries never rebuild. A modifier runs only on the hooks its definition lists. [ADR 0008](adr/0008-rank-modifiers.md) has the rank rules.

Each hook takes one typed context:

| Hook | Context | Fields |
| --- | --- | --- |
| `build_ruleset` | `RulesetContext` | seat, landlord, params |
| `build_rank_map` | `RankMapContext` | seat, landlord, trick_bombed, rank_map |
| `on_deal` | `DealContext` | landlord, deal |
| `round_start` | `RoundContext` | landlord, winner, finish |
| `play_scored` | `PlayContext` | seat, is_landlord, pattern, add_grain, add_zeal, mul_zeal |
| `card_scored` | `CardContext` | seat, is_landlord, card, grain |
| `trick_won` | `TrickContext` | winner, landlord |
| `round_end` | `RoundContext` | landlord, winner, finish |
| `set_end` | `SetContext` | set_index, target_met |
| `shop_open` | `ShopContext` | seat |
| `meter_change` | `MeterContext` | meter, delta |

## Scoring

`Scorer` scores a play as Grain × Zeal from the `ScoreParams` Resource, then hooks apply additive Grain, additive Zeal and multiplicative Zeal, in that order. Each bomb or rocket doubles Zeal. `ScoreBreakdown` holds the ordered steps for the UI in one flat array. `HandLevels` tracks each hand type's level, and `ScoreFormat` writes short-scale numbers. `Banking` converts scores to whole pool units, rounding down, and splits the pool by need.

Card enhancements, seals and stamps change only through `CardModifiers`, and the layer check rejects their setters anywhere else in `core/` or `data/`.
