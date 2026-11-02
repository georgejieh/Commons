# ADR 0011: Hard and Expert miss the 60% bar

## Status

Accepted for Hard. Open for Expert, so P2.9 stays blocked until a human chooses.

## Context

P2.9 asks each tier to beat the tier below at least 60% of the time, measured as in [ADR 0010](0010-measuring-tiers.md). The time budgets are a median under 30 ms and a p99 under 100 ms for Easy to Hard, and a p99 under 400 ms on worker threads for Expert.

The first measurement, at commit 0c741bc after the full review fixed bugs in the bot search, gave Hard its own endgame search. Each row here is 2,000 games over 1,000 deals, so the margin is about ±2.2 points at 95%, taking the games as independent.

| Pair | Win rate | Search size | Bar |
| --- | --- | --- | --- |
| Medium over Easy | 63.3% | None | Met |
| Hard over Medium | 57.1% | Hard 3 candidates × 3 samples | Missed |
| Expert over Hard | 50.1% | Expert 4 × 12, Hard 3 × 3 | Missed |

Hard's budget left no room for more samples. Before the fixes, 3 × 4 gave a p99 of 111 ms. Hard's rules were also stretched: effective-hand scoring, a tempo bonus, leading the hardest group and a stricter forced win were each tried and dropped.

Expert's rollouts use the Medium policy, as the checklist says. Hard searched its endgame with the same rollouts, which seemed to explain why Expert had no lead.

## Options

1. Lower the bar to what is measured: 55% for Hard over Medium, and Expert no weaker than Hard. Cheapest, but Expert is then Hard with a longer think.
2. Take the search out of Hard, so Expert has a clear lead, and accept Hard over Medium near 55%.
3. Roll out with the Hard policy instead of Medium. May lift Expert, but each rollout costs more, so fewer samples fit in 400 ms.
4. Raise the budgets. Hard gets stronger with more samples, but the player waits longer on every bot turn.

## Decision

Options 1 and 2 together, for Hard. Hard plays by rules alone, and its bar is 55% over Medium. Tiers should feel different to play against, and Expert should be the one that searches.

Expert's bar is not settled. The aim was at least 55% over Hard, and the measurements below miss it.

## Results

Measured at commit 00d69b9, with Hard's search removed.

| Pair | Win rate | Bar | Status |
| --- | --- | --- | --- |
| Hard over Medium | 56.4% | 55% | Met |
| Expert over Hard | 50.0% | 55%, proposed | Missed |

Medium and Easy are unchanged by this decision, so Medium over Easy stands at 63.3%. There were 0 illegal actions.

Time budgets are met. Hard's mean is 1 ms and its p99 is 7 ms at worst across seats. Expert's p99 is 376 ms over 1,240 decisions through `ExpertRunner`, with a 300 ms deadline.

Removing Hard's search cost it 0.7 points against Medium and gave Expert nothing, so Hard's search was not what held Expert back. Expert wins 46.2% as landlord and 53.7% as peasants, against Hard's 46.3% and 53.8%.

## Why Expert had no lead

Sample noise was the main cause. With 12 samples, Expert overturned its policy's play in 31% of decisions, mostly on chance differences. These short runs were all played with unlimited time, on one range of deals. Their margins are about ±4 points at 600 games and ±6 at 240.

| Search | Games | Expert over Hard | Decisions overturned |
| --- | --- | --- | --- |
| 12 samples, as at 00d69b9 | 600 | 47.2% | 31% |
| 12 samples, needing a lead of 2 | 600 | 52.0% | 16% |
| 12 samples, seeing the true hands | 600 | 58.5% | 8% |
| 48 samples | 240 | 54.6% | 37% |
| 48 samples, needing a lead of 6 | 480 | 56.5% | 13% |
| 48 samples, needing a lead of 6, Hard rollouts | 480 | 56.5% | 9% |
| 96 samples, needing a lead of 12 | 240 | 57.1% | 12% |

Option 3 is ruled out: Hard rollouts gave the same result as Medium rollouts at a higher cost. Seeing the true hands suggests that better guesses about the hidden cards are where further strength lies.

Commit 0a17560 applies the fix. Expert searches 3 candidates at 48 samples and keeps its policy's play unless another leads by 12.5% of the finished samples. At the deadline it uses the samples that finished, with at least 12, and otherwise falls back to Hard.

## Results after the fix

| Measure | Games | Expert over Hard | Margin |
| --- | --- | --- | --- |
| Unlimited time, one thread | 2,000 | 53.2% | ±2.2 |
| `ExpertRunner` at 300 ms, 8 cores | 600 | 51.2% | ±4 |

Both miss the proposed 55%. The short runs above overstated the gain: the settings were picked on those deals, and the 2,000 games use a different range. As landlord, Expert wins 51.2% to Hard's 44.7%. There were 0 illegal actions. Expert's p99 through `ExpertRunner` is 357 ms over 1,163 decisions.

The unlimited-time figure is probably a real gain over 50.0%, but only just: the two margins overlap slightly. The 300 ms figure cannot be told apart from Hard. Players get the 300 ms game, and fewer samples finish on a weaker machine.

## Consequences

P2.9's box stays unticked until a human sets Expert's bar or asks for more strength. The remaining choices are to accept a lower bar, or to improve how Expert guesses the hidden cards, for example from bidding and play history. Expert is safe to ship as it stands, but it is at best slightly stronger than Hard.

P2.10 to P2.12 do not depend on the choice.
