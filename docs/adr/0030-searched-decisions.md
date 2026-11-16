# ADR 0030: Expert decisions are made under a deadline and written down

- Status: Accepted, 2026-11-15, by the agent under the design authority ADR 0021 records.
- Scope: how the live game asks an Expert villager for a play, and how a save replays it. It settles what ADR 0009 and ADR 0011 left to "when the search is wired into the game".

## The problem

`RunLoop` asks every villager for its play through `Bot.decide_play` with an unlimited budget. Three tiers answer from rules and that is cheap. The Expert tier searches: up to 48 deals of the unseen cards, up to three candidates played out in each. `ExpertRunner`, which spreads that search over the worker pool and stops starting new samples at a deadline, is used by a measuring tool and by tests, and never by the game.

The balance harness (P4.16) measured a searched Expert decision on the game's own path at about 2.3 seconds on average and 4 at worst, on the thread that handles the player's command. That figure is the harness build's own measurement and is not yet in `docs/perf.md`. Whatever the exact number, an unlimited search on that thread is far outside P2.9's budget of a p99 under 400 ms on a worker with a deadline. Two families are Expert: Ma, who joins the village after three finished runs, and Tang, after five. Nobody else can reach the tier: rising families stop at Hard.

A deadline cannot simply be dropped in, because of how saves work. A run save is a checkpoint and the player's commands since; loading replays those commands, and the villagers decide again as the replay goes. A decision that depends on a clock is not repeatable. The replay could then differ from what the player saw.

## Decision

1. **A config says whether it searches.** `BotConfig` answers it (Expert today), so a later searching tier is covered in one place.
2. **The loop asks a searcher.** `RunLoop` gets an optional searcher, a callable with `Bot.decide_play`'s inputs that returns a play. It is asked only for a searching seat. With none, the loop calls `Bot.decide_play` with the unlimited budget as today. The tournament plays through `SelfPlay` and the harness through a loop with no searcher, so both stay repeatable.
3. **The game supplies `ExpertRunner`** with a deadline kept in data (300 ms, the figure ADR 0011 measured with). At the deadline the runner starts no more samples and decides on those finished; a sample already running completes first, so a decision can run a little past the deadline. ADR 0011 recorded a p99 of 357 to 376 ms that way.
4. **Every decision by a searching seat is written down**, whether the search overturned the policy's play or not, since either can depend on the clock. The run record gains a list beside the player's commands: each such decision since the checkpoint, in order, as the seat and the card IDs played, or a pass. It is cleared with the commands at each checkpoint.
5. **Replay reads the list and nothing else.** The list is handed to the loop before the checkpoint is resumed, because villagers can act before the first replayed command. During replay a searching seat takes its play from the list. The load fails, as it does for a command that no longer applies, if the next entry is for another seat, is not a legal play there, if the list runs out before the replay ends, or if entries are left over when it ends. After the replay, play goes on with the searcher.
6. **Older saves.** The run save moves up a schema. A migrated save is marked as holding no written decisions, and replays with the unlimited search, as it was made.

## Consequences

- Loading a save in the middle of a Quota no longer repeats every search made so far.
- The game still waits for the Expert on the thread that handles the player's command. One command can be followed by two Expert decisions before the player's next turn, so the pause after a play can reach about two deadlines, and P2.9's budget is a p99, not a ceiling. Whether that is felt is for the playtest. Moving the wait off that thread means the loop must be able to stand still for a villager as it does for the player; that is a new checklist item (P5), not part of this change.
- The live figure has to be measured once the game uses the runner, and recorded in `docs/perf.md`, as ADR 0011 asked.
- The harness keeps the unlimited, repeatable search. Because that is slow, it may lower the number of deals an Expert samples (`--expert-samples`, never below the 12 a search needs before it may overturn the policy), and says so in its report. How much weaker that makes Expert villagers has not been measured.
