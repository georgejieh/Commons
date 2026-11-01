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

Expert's bar is not settled. The aim was at least 55% over Hard, and the measurement below misses it.

## Results

Measured at commit 00d69b9, with Hard's search removed.

| Pair | Win rate | Bar | Status |
| --- | --- | --- | --- |
| Hard over Medium | 56.4% | 55% | Met |
| Expert over Hard | 50.0% | 55%, proposed | Missed |

Medium and Easy are unchanged by this decision, so Medium over Easy stands at 63.3%. There were 0 illegal actions.

Time budgets are met. Hard's mean is 1 ms and its p99 is 7 ms at worst across seats. Expert's p99 is 376 ms over 1,240 decisions through `ExpertRunner`, with a 300 ms deadline.

Removing Hard's search cost it 0.7 points against Medium and gave Expert nothing, so Hard's search was not what held Expert back. Expert wins 46.2% as landlord and 53.7% as peasants, against Hard's 46.3% and 53.8%. Searching every decision for over 100 ms adds no measurable strength to the Hard rules. The cause is not known. Rollouts of a weaker policy may misjudge moves that Hard's rules get right, or the search may have a fault no test has caught.

## Consequences

P2.9's box stays unticked until Expert's cause is found and its bar is set. Option 3 is the next thing to try. Expert is safe to ship as it stands, but until then it is a slower Hard.

P2.10 to P2.12 do not depend on the choice.
