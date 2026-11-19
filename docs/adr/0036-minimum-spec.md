# ADR 0036: The minimum-spec machines

- Status: Accepted, 2026-11-19, by the agent. The owner judges by playtest, and owns the hardware question at the end.
- Scope: P5.3. It replaces the stand-in of [ADR 0016](0016-phase-3b-measurement-machine.md) for every budget in the conventions table.

## Why this needs a decision

The budgets are to be measured "on the minimum-spec machine defined in P5.3", and P5.3 says only "a low-power laptop with integrated graphics, plus Steam Deck". Nearly every figure in `docs/perf.md` so far was taken on the development PC, which ADR 0016 allowed for Phase 3B and which has a desktop CPU and a discrete GPU. The one exception, texture memory, was read on the cloud runner.

## Decision

**Two reference machines.** The game is supported on anything at or above either.

| | Laptop | Handheld |
| --- | --- | --- |
| Machine | A 2017-class thin laptop | Steam Deck (LCD, 2022) |
| CPU | Intel Core i5-8250U: 4 cores, 8 threads, 15 W | AMD APU, Zen 2: 4 cores, 8 threads |
| Graphics | Intel UHD Graphics 620, integrated | Integrated, 8 RDNA 2 compute units |
| Memory | 8 GB, shared with graphics | 16 GB, shared with graphics |
| Screen | 1920x1080 | 1280x800 |
| System | Windows 10 or 11, 64-bit | SteamOS 3 |
| Storage | SSD | The Deck's own |

**A slower machine also counts.** A measurement on a laptop below the reference, with an older or lower-power CPU and integrated graphics, stands as a minimum-spec measurement and is recorded with the machine's name.

**The renderer stays Compatibility.** The project already uses it (`gl_compatibility`), and it is the renderer Godot offers for older and integrated graphics.

**One command measures every budget.** `tools/perf_budget.gd` writes a report with the machine's name, each budget, the measurement and a verdict. Headless it covers the rules, the bots, the save and static memory. In a window it adds frame time during play, startup to the title and resident memory. The report from each reference machine is committed in `docs/perf.md`.

**Stand-ins are labelled.** Until a reference machine has been measured, `docs/perf.md` carries the development PC's figures and the CI runner's, each named as what it is. P5.3 is not ticked on stand-ins.

## Why these two

- The Deck is named in the Plan and has one specification apart from its storage, so a result on it means nearly the same for every owner of one. A report from a Deck names its storage. ADR 0034 already sizes text for its screen.
- The laptop is the other half of "low-power laptop with integrated graphics". A 15 W four-core chip of 2017 with its integrated graphics is slower than the Deck at drawing in published game benchmarks, and is the kind of machine a player without a gaming PC has. 8 GB is named so the machine is fully specified; the game's own budget is 512 MB.
- Both have 8 threads, so an Expert villager searches on 7 worker threads on either, as on the development PC. A two-core machine would search on 3 or fewer and finish fewer samples. P5.0's deadline and grace are a clock and not a count, so a slower machine should give a weaker search and not a longer wait, but the 400 ms budget is a p99 and still has to be measured there.

## Alternatives rejected

- **The development PC as minimum spec.** It has a GTX 1060; the P3B GPU budgets pass there with a margin that says nothing about integrated graphics.
- **The CI runner as minimum spec.** The playtest workflow forces software rendering there, so its frame times say nothing about a real GPU. Its CPU figures are a second stand-in and nothing more.
- **A looser definition, such as "any integrated graphics".** Then no measurement could be repeated or compared.

## Consequences

- The agent cannot finish P5.3 alone. Frame time, startup and resident memory need a window on a reference machine, and nothing may open a window on the owner's screen. The owner runs one command on each machine, or on a slower one, and the report is committed.
- If a budget misses on a reference machine it becomes P5.3 work, as ADR 0016 said, and the fix is measured there again.
- The store page's system requirements (P5.6) come from this table.
