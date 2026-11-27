# Tournament formats

`tools/tournament.gd` writes results as CSV and, with `--log PATH`, each game as one line of JSON.

## CSV

Each row covers one configuration in one role at one seat.

| Column | Meaning |
| --- | --- |
| `mode` | `duplicate`, the measure in ADR 0010, or `bidding`, where bids pick the landlord |
| `config` | `easy`, `medium`, `hard` or `expert` |
| `role` | `landlord` or `peasant` |
| `seat` | 0 to 2 |
| `games`, `wins`, `win_rate` | Games played in this row, and how many that side won |
| `mean_usec`, `p99_usec` | Decision time in microseconds, on one thread |
| `illegal_actions` | Rejected bot actions. Must be 0 |

`--wild N` makes 1 or 2 ranks wild in every game and `--big-bombs` lets five or more cards of a rank be a bomb, both for every seat ([ADR 0029](adr/0029-wild-ranks.md)). The wild ranks are drawn per deal from the deal's seed, so both games of a deal share them. Neither changes the columns.

Expert times here are for one thread. `ExpertRunner` spreads the same work over the worker pool in play, and `tests/integration/test_expert_runner.gd` measures that.

## Game log, version 1

One JSON object per line.

| Field | Type | Meaning |
| --- | --- | --- |
| `version` | int | 1 |
| `seed` | string | The deal seed, for `SelfPlay.deal_from_seed()`. Text, because JSON numbers lose large integers |
| `seats` | array of string | The configuration at seats 0, 1 and 2 |
| `landlord` | int | The landlord's seat |
| `hands` | array of string | Each seat's dealt hand, before the kitty |
| `kitty` | string | The three kitty cards |
| `plays` | array of [seat, cards] | Every action in order. Empty cards mean a pass |
| `winner` | int | The seat that went out first |

Cards are rank symbols in ascending order, with no suits: `3456789TJQKA2XD`. `X` is the small joker and `D` the big joker. The log holds only base ranks, so it fits games without rank modifiers, which is all the tournament plays. Under `--wild` a play lists the cards as printed; the log holds neither the wild ranks, which `TournamentRun.wild_ranks_for(seed, N)` gives again, nor the reading a play was made as.
