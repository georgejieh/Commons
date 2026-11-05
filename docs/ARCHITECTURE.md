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

`UnseenCards` counts what a seat has not seen, from its view alone. `Controls` flags the groups no unseen combination can beat, so effective hands are hands less controls.

`CandidateScorer` values a candidate by the hand it leaves, from a `BotWeights` Resource. `SelfPlay` plays bots against each other through the real `RoundState`, so every harness measures the rules the game uses.

`BotPosition` works out what one decision knows, once, from the seat's view. `LeadPolicy` applies the lead rules in priority order on top of it, `FollowPolicy` the follow rules and their gates, and `SeatRole` what differs between the upstream and downstream peasants. `BidPolicy` weighs hand points against a threshold from data.

`BotConfig` picks a tier. Easy is `GreedyPolicy`. Medium is the policies above with 2s and jokers as controls. Hard adds card counting, endgame blocking and seat roles, and plays by rules alone. Expert searches every decision. `ExpertSearch` deals the unseen cards consistently with what is public and plays each top candidate out with `Rollout`, a fast count-based simulator of the Medium policy. A `BotSearchJob` holds that work, so `ExpertRunner` in `game/bots/` can spread it over the worker pool. A search only chooses among the policy's own play, a pass and the moves its gates leave open, so it never reopens a gate. A rival must beat the policy's play by a margin, so noise can't overturn it. At the deadline the job decides on the samples it finished, and with too few the policy decision stands. Tier strength is measured as in [ADR 0010](adr/0010-measuring-tiers.md), and [ADR 0011](adr/0011-tier-strength-bar.md) records the tier bars and why Expert's is low.

A `Personality` Resource holds a tier and five levels. `PersonalityTable` turns levels into numbers, and `BotConfig.from_personality()` applies them.

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

## Run

`core/run/` holds the run. `RunState` is everything a run needs to resume: the seed and stream states, the Year, Set and round, the debuff ladder, both meters, the roster as `RosterEntry` rows, the player's `RunInventory` (Cadres in slot order, consumables, the private plot), coupons, the Commons pool, the landlord seat, the family in each seat, and one `SetSummary` per Set, the current Set's last. It serializes to a Dictionary of JSON-safe values, with numbers that can pass 2^53 as text.

`RunFlow` holds the run's states and the one table of moves between them; any other move returns a reason code and changes nothing. `RunState.phase` records where the run stands. A test checks this diagram against the table.

```mermaid
stateDiagram-v2
    [*] --> RUN_START
    RUN_START --> SET_INTRO
    SET_INTRO --> BIDDING
    BIDDING --> BIDDING
    BIDDING --> ROUND_PLAY
    ROUND_PLAY --> ROUND_END
    ROUND_END --> BIDDING
    ROUND_END --> ROUND_PLAY
    ROUND_END --> SET_END
    ROUND_END --> RUN_END
    SET_END --> SHOP
    SET_END --> REEDUCATION
    SET_END --> RUN_END
    SHOP --> EVENT
    SHOP --> SET_INTRO
    SHOP --> YEAR_END
    SHOP --> RUN_END
    EVENT --> SET_INTRO
    EVENT --> YEAR_END
    EVENT --> RUN_END
    YEAR_END --> SET_INTRO
    YEAR_END --> RUN_END
    REEDUCATION --> SET_INTRO
    REEDUCATION --> YEAR_END
    REEDUCATION --> RUN_END
    RUN_END --> [*]
```

Bidding loops on itself for a redeal. A round goes back to bidding when the landlord lost, and straight to play when the seat is kept. Reeducation (P4.1) replaces a Set's shop visit, and the run can end wherever a meter moves.

**Meters (P4.1).** `data/run/meters.tres` is a `MeterTable`:

- `MeterBands` for each meter: the low, mid, high and death thresholds, plus a re-arm margin.
- One `MeterSource` row per cause of change: missed target, Commons shortfall, private purchase, caught lie, and a band-sized row for each meter's debuffs.
- The store slots that rationing cuts.

`RunMeters.apply(source)` handles every change:

1. It runs the change through the `meter_change` hook and clamps the result.
2. It logs `METER_CHANGED`.
3. It fires the mid-band setback once per upward crossing. The flags for this live in `RunState`. A setback re-arms only after the meter falls below mid minus the margin.

The two setbacks:

- **Rationing** holds while Famine stays up. `RunShop.slot_count()` cuts the store's slots for as long as it lasts.
- **Reeducation** is owed once. `open_shop()` serves it in place of the store: the run moves to `REEDUCATION`, the plot is emptied, and one held Cadre is exchanged ([ADR 0019](adr/0019-reeducation-setback.md)).

Death is checked after each meter move, at a state that may go to `RUN_END`: Set end, or round end for a shortfall. The run log gets `RUN_DIED`, naming the meter. Run saves are schema 3; `RunRecord.migrate_from_2` adds the setback flags.

`SetConfig` reads the run's shape from the `SetParams` Resource in `data/run/`: the number of Years, rounds per Set, coupons per Set type, and the target curve, one target per Set in play order. `validate()` rejects a curve that falls anywhere, across Years too.

`DebuffLadder` draws a Set's ladder at Set intro on the debuff stream, in O(rounds × pool size). Round 0 is clean, and a later round's tier is capped at its round number and at `ModifierDef.MAX_TIER`. The tier is drawn by the weights in `LadderParams`, 60/30/10 for the cap, one below and two below, with tiers under 1 dropped. A debuff never repeats or shares a lever with another in the same Set. Each round keeps one severity point of the Set's budget for every round after it, and a draw that would spend more is redrawn a tier lower, down to tier 1 ([ADR 0013](adr/0013-ladder-budget-reserve.md)). A round with nothing left to draw stays clean. With the Plan's pool that happens only in the last round of a small or large Set (5.4% and 2.6% of 100,000 ladders), because the only tier-1 debuffs pull the scoring and economy levers.

`RunLoop` plays a Set round by round. Set intro draws the ladder. Each round adds its debuff to the `ModifierStack` (debuffs stack through the Set), deals a fresh deck on the deal stream, then bids. A kept seat skips bidding, and an all-pass redeals. Plot swaps come after bidding, through `PlotSwap`, one for one. What a swapped deck card becomes across rounds waits on [ADR 0014](adr/0014-plot-card-identity.md); until then a swap that would collide with a card in hand is refused. Every play is scored by `Scorer` as it happens. At round end `RoundTotals` applies the round multipliers. `RoundBanking` then banks the landlord, pools the peasants' totals, and splits the pool by declared need, with bots declaring on the ai stream. Only what reaches the player counts toward the target. The Set ends when the target is met, for its coupons, or when its rounds run out, which raises Famine. The player sits in seat 0 and acts by commands (`player_bid`, `player_swap`, `player_play`, `player_need`); `advance()` runs the bots until the player is needed. Each command returns a reason code, and a command the loop is not waiting for changes nothing. Everything the loop does is recorded as a `RunEvent`, with round play wrapped.

A Set reads only the `RunState` at its start, so the state there plus the player's commands rebuild it, the Set's log included. Numbers that later items own come from `RunParams`: a base need for every villager (P4.3) and swaps per round (P4.8). The grab stake is recorded but not scored, because scoring (P1C.5) has no stake step.

## Saves

A save holds a `RunRecord`: the `RunState` where the loop last stood still, at a Set's start or end, and the player's commands since. The loop is deterministic, so `RunRecord.resume()` replays those commands on that state and rebuilds any moment in between exactly, mid-round included, with the Set's whole log. That is the full round state, kept without serializing `RoundState`. A command that no longer applies makes `resume()` return null. `RunLoop.on_boundary` is called with the loop after every state move, for autosaves; the Set-end and run-end moves mark the record first. Replay assumes the same rules and bots as when the save was written, and bots run without a deadline in the loop.

`SaveService` in `game/save/` does the file work, because `core/` has no I/O. It writes JSON with a `schema_version` to a temporary file and renames it into place, keeping the save it replaces as a `.bak`. Loading falls back to the backup when the main file is missing, damaged, or parses but fails the validator (`RunRecord.is_valid` for run saves), and returns a notice key for the player. A damaged main file never replaces the backup. A save from an older version runs through one registered migration per version step; a newer one is refused. The run save and the profile save (P4.14) are separate files with separate services. Floats are saved as their bits, because Godot's JSON writer does not round-trip every double.

## Event log

`SetLog` holds the current Set's `RunEvent`s, appended in order and cleared when the next Set starts, so memory stays flat however long a run lasts. As each round ends, `SummaryFold` folds that round's events into the Set's `SetSummary`: per villager's family, how often the player fed, bombed, denounced or betrayed them ([ADR 0012](adr/0012-set-summary-counts.md)). Folding by round keeps the summary right when a run resumes mid-Set, since the checkpoint carries the rounds before. Villager memory, epilogues and the New Landlord read summaries, never raw logs.

At the same point `ObservationFold` adds the round to `RunState.observations`, which is the dossier's source. It counts, per villager family, what the player saw that villager do across the run: bid turns and calls, bombs, passes, plays over a teammate, first-out finishes, and rounds as landlord. It never records a personality. Run saves went from schema 1 to 2 for this field. The 1-to-2 migration (`RunRecord.migrate_from_1`) gives an older save an empty record.

A view hears the log through `RunLoop.set_log`: `SetLog` hands its listener every event in order, including events that banking and meters append directly, which reach it at the next add or at `flush()`. The listener survives a Set's start, so one command that ends a Set and starts the next delivers both.

## Presentation boundary

`RunController` in `game/run/` is the only way the UI touches a run ([ADR 0017](adr/0017-demo-first-2d-3d-comparison.md)). It owns the `RunLoop` and its state, and takes the UI's commands: bid, swap, play, pass, declare need, and finish a Set. Each command flushes the log and re-emits its events as `event_emitted`, then `awaiting_changed`. A refused command emits `command_refused` and changes nothing. Queries hand out copies (the seat view, the player's cards, `state_copy()`), so a view can read the run but never change it. Card selection is the hand model's, not the run's.

`tools/ui_boundary_check.gd` scans `ui/` for core loop and round types and their mutators, and the test suite runs it.

## Autoloads

Four singletons, and no more (P3B.2): `Settings` (`SettingsStore`: player settings in `user://settings.cfg`, defaults from `data/settings/default_settings.tres`), `Strings` (`StringTable`: string-table keys to text), `Saves` (`SaveHub`: the run save service) and `Audio` (`AudioMixer`: the Music, Effects and Voice buses and their volumes). None holds run state; the run lives in `RunController`. The Godot AI add-on's `_mcp_game_helper` is a development autoload that export presets exclude ([ADR 0017](adr/0017-demo-first-2d-3d-comparison.md)). `tests/integration/test_autoloads.gd` checks the list exactly.

## Hand model

`HandModel` in `game/hand/` is the player's hand as the table view sees it ([ADR 0017](adr/0017-demo-first-2d-3d-comparison.md)): which cards are selected, how the selection reads, its projected score and the hint. Selection is local to the view; playing it goes through `RunController`. `RoundState.read_play()` reads a seat's cards against the table without playing them, and `apply()` plays through the same reading, so a preview and a play can never disagree on legality. `RoundScoring` scores a round's plays as they happen and previews a play through the same path, so the projected score equals the scored one. A preview changes nothing: hooks learn how many plays the seat made before from `PlayContext.plays_before`, so effects keep no state of their own. A label key names the pattern (`pattern.*`) or the reason Play is off (`hand.reason.*`). Hints light every card whose rank appears in a legal move, since moves are over ranks.

## State store

`RunShop` in `core/run/` is the state store between Sets (part of P4.10, per [ADR 0017](adr/0017-demo-first-2d-3d-comparison.md)). After a finished Set, `RunLoop.open_shop()` moves to the shop state and draws stock: up to `ShopParams.slots` Cadres the player doesn't hold, from `data/run/cadre_pool.tres`, weighted by rarity, on the shop stream. Buying spends coupons and appends the Cadre to the inventory; a reroll draws new stock for a price that rises with each reroll in the visit. Stock is never saved. The shop visit, purchases and rerolls are record commands (`shop`, `buy`, `reroll`), so a save taken in the store replays the visit from the Set's end and draws the same stock. `next_set()` leaves the store; from a finished Set it still passes straight through, which harnesses use. There is no black market yet, because Resentment doesn't exist.

At each round's start the loop rebuilds its modifier stack from the player's Cadres in slot order, then the ladder's debuffs so far, as the hook order says.

`RunController` saves through its `SaveService` after every state boundary and every accepted command, so quitting at any moment loses nothing.

## Demo app and screens

`ui/main.tscn` runs `DemoApp` ([ADR 0017](adr/0017-demo-first-2d-3d-comparison.md)), which owns the `RunController`, the `HandModel` and a `SceneSwitcher` (`game/scenes/`). The switcher shows one screen at a time under a host node, with a back stack. Each screen is its own scene and gets the app in `open()`; the run lives beside the switcher, never in a screen, so changing or going back between screens keeps it. The demo is one Year (`data/run/demo.tres`): title, run setup, Set intro with the ladder, table, Set summary, state store, Year summary, settings and a closing screen. More screens open over these: the dossier and last-round summary from the table menu, the black market from the store, and the collection and village history from the title. The plot swap opens when the run waits on a swap. Reeducation and the ending screen exist, but nothing routes to them until P4.1 and P4.13. Screens whose systems are still to come show what `RunState` holds today. The table is the 2D `ui/table2d/table_screen.tscn` unless the build has the `table_3d` feature.

The 2D table renders the run's events through an `EventPlayer`, which spaces bids, plays, passes and trick ends a step apart so each bot play can be seen, and holds still during a hit-stop. It reads the run only when the queue is empty. Card views come from the table's `CardPool`, and ledger rows and notice-board slots are made once, so nothing is instanced during a round.

`TableInput` handles the keyboard and gamepad at the table. The `commons_*` actions in `project.godot` give play, pass, hint, sort and rules the same button a click presses. `commons_cursor_left`, `commons_cursor_right` and `commons_select` move a cursor along the hand and toggle the card under it. The table's buttons never take focus, so A or Space can't land on the wrong one. Menus and screens use focus navigation, and `ui_accept` and `ui_cancel` add gamepad A, and B or Start, to their default keys. The table's backdrops fill the screen, so a 16:10 Steam Deck screen shows more room, not an empty band.

The dread layers (P3B.12) put the run's state on the board without touching anything the player reads:
- **Data.** `data/horror/horror_config.tres` lists five `HorrorLayer`s: Famine, Denunciation, struggle (both meters high), landlord and corruption. Each maps one input, through a response curve of points, to a weight from 0 to 1, and lists the shader parameters it moves, the textures it swaps once past half weight, the set dressing it shows and the music stems it will fade. Flickers are `FlickerDef`s on cooldowns.
- **`BoardState`** (`game/horror/`) turns cached meters, class and corruption stage into target weights, and eases toward them over `ease_seconds` without allocating. Its targets change only when the table calls `refresh()`: at a deal, a landlord choice, a round's scoring, a Set's start or end, or a meter change.
- **`DreadLayers`** binds every parameter once. Each frame it writes clean value plus delta times weight into the post-process, lamp, watcher and spotlight materials, clamped to the range the layers span, and fades the `DreadDressing` pieces. Weights are scaled by the `horror_intensity` setting, and `no_flash` stops every flicker and the lamp's flutter.
- **The art itself changes with corruption.** This is the main carrier of dread (ADR 0018). `ArtStages` (`game/horror/`) resolves every key asset to its `ArtVariant` for the current stage, falling back to the nearest earlier stage, then the base. Variants are file paths. Base art is preloaded, but a stage version loads only when shown, and `ArtStages` holds just the current stage's files, so a picture that leaves the screen mid-play is not read from disk again and an earlier stage's files are let go when the stage changes. The assets are cover backdrops, paper, card face and back, Cadre art and portraits.
  - Screens resolve when they are built, and the table re-resolves its swap slots at each refresh, so a stage change lands at a round boundary or on the next screen.
  - Meter layers' texture swaps sit on top. The variants live in `horror_config.tres` under `art`.
  - Corruption stays at stage 0 until the profile save holds it. A development build can pass `--corruption-stage N`.
- **The content note** shows once, before the title, on first launch.
- **Readability.** Text that sits straight on the table has a paper outline, so it stays readable however dark the room gets. `tools/board_states.gd` renders the Plan's seven board states.

`TableSpeech` turns run events into villager speech. When the table reopens mid-Set it replays the Set silently, with no speech or sound. It takes lines by event from `data/ui/speech_book.tres`, where each `SpeechLine` has a string key and an optional mood tag. Each seat cycles a salt, so a given order of events always gives the same lines. It emits `spoke` for the voice player (P3B.13). The dossier screen, opened from the table's menu, shows `RunState.observations` for each villager at the table.

## Audio events

`AudioEvents` in `game/audio/` names a sound for every domain event type (P3B.10): each `RunEvent` type, each round event inside a `ROUND` event, and a separate name for bombs and rockets. The table passes each event it shows to `Audio.play()`, which routes it to the right bus once P3C.8 adds the sounds; until then every name is silent.

**Music (P3C.9).** `MusicPlayer` (`game/audio/`) is a child of the `Audio` autoload, reached as `Audio.music`, so the autoload list stays at four. It plays one `MusicCue` at a time on the Music bus, with the cue's stems in one `AudioStreamSynchronized` so they share a timeline. `MusicScore` (`data/audio/music_score.tres`) picks the cue from the Famine layer's target and the landlord seat. `DreadLayers` asks for a cue at each round boundary and passes its shown weights every frame, and each layer's `audio_stems` fades those stems by volume only, so they return in step. A new cue starts when playback crosses the next bar line, counted from the cue's measured first downbeat, and stems the two cues share keep their gains. Asking for the cue already playing cancels a waiting change, and leaving the table brings every stem back. Cues with no audio stay silent. The cue plan and Suno prompts are in `audio/music/CUES.md`.

## Card faces, atlases and lighting

- **Card faces are composed, never baked (P3C.5).** `CardArt` (`data/ui/card_art.tres`) holds the card stock, the four suit icons, the jack, queen and king art and the two jokers. `CardView` draws the rank from the font, the suit icon in the corner, and a middle picture: court or joker art, or a faint suit for pip cards. Every part resolves through `ArtStages`, so changing one part restyles every card that uses it, at any corruption stage.
- **Atlases and import sizes (P3C.4).** Small UI sprites are packed by `tools/pack_atlas.py` into `art/atlases/`, and the game loads one `AtlasTexture` per sprite from `data/ui/atlas/`. Large art imports at 512 px on its long side. `tools/texture_budget.gd` holds a full table under 128 MB in the cloud playtest.
- **Lighting (P3C.6).** `Lighting` (`ui/table2d/`) pairs a texture with its normal map by name (`art/normals/<name>_n.png`, made by `tools/normal_map.py`) in a `CanvasTexture`, with nothing cached, so old stages are released. Normal maps use the OpenGL convention (green up), which Godot's canvas lighting expects. Every stage version has its own normal map, so the relief matches the art shown. One `PointLight2D`, built from `TableLight` data and hosted by `TableAtmosphere` where the lamp hangs, lights only items on light mask 2: the table surface and the card stock. Labels and controls are never lit.

## Interface components and motion

`CommonsTheme` (`ui/theme/`) builds the demo's one component theme from `UiStyle` tokens (`data/ui/ui_style.tres`): four button kinds (primary vermilion, secondary ink, coupon green, ghost paper) drawn as raised keys whose bottom edge shrinks when pressed so the label sinks; a gold focus ring on every focusable control; paper `Sheet` panels; and a type scale of `Headline`, `Title`, `Eyebrow` and `Caption`. Screens choose a kind or level with `theme_type_variation` and style nothing by hand. `ScreenKit` composes pages, headers, sheets, stat tiles and rows from it.

`UiMotion` (`ui/motion/`) is the interface's motion: buttons lift on hover or focus and sink when pressed, pages bring their pieces in one after another, numbers roll to new values, and verdicts land like ink stamps. It moves only scale and opacity, so containers keep their layout, and each tween belongs to the node it moves. The app fades through ink between screens. On the table, played cards drop into their lanes, a fresh hand rises into the fan, a won trick sweeps toward its winner, ledger rows stamp in with their score counting up, and a reused `TableBanner` announces the landlord seat, bombs and the round's winner. Every duration is in `MotionPresets`; reduced motion shortens or skips all of it, takes effect the moment it is set, and stops any shake or hit-stop under way.

