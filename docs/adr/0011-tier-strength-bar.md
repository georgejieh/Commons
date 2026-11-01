# ADR 0011: Hard and Expert miss the 60% bar

## Status

Proposed. P2.9 is blocked until a human chooses.

## Context

P2.9 asks each tier to beat the tier below at least 60% of the time, measured as in [ADR 0010](0010-measuring-tiers.md). The time budgets are a median under 30 ms and a p99 under 100 ms for Easy to Hard, and a p99 under 400 ms on worker threads for Expert.

| Pair | Games | Win rate | Search size | Bar |
| --- | --- | --- | --- | --- |
| Medium over Easy | 2,000 | 63.2% | None | Met |
| Hard over Medium | 2,000 | 56.3% | Hard 3 candidates × 4 samples | Missed |
| Expert over Hard | 1,000 | 50.9% | Expert 4 × 12, Hard 3 × 4 | Missed |

The Hard budget then forced Hard down to 3 × 3, with a median of 0.9 ms and a p99 of 83 ms. At that size Hard over Medium was 58.3% over 400 games, which is too few to separate from 56.3%. At 3 × 6 it was 58.1% over 1,000 games, with a p99 of 168 ms.

Expert's time budget is met: a p99 of 373 ms over 1,128 decisions through `ExpertRunner`, with a 300 ms deadline.

Hard's rules alone reached only 55% to 57% over Medium. Effective-hand scoring, a tempo bonus, leading the hardest group and a stricter forced win were each tried and dropped. So Hard also searches once 36 or fewer cards are left, which the checklist does not ask for. A larger endgame search was stronger in small samples but breaks the Hard budget.

Expert's rollouts use the Medium policy, as the checklist says. Hard already searches its endgame with the same rollouts, which leaves Expert only its early game and a larger sample to pull ahead.

## Options

1. Lower the bar to what is measured: 55% for Hard over Medium, and Expert no weaker than Hard. Cheapest, but Expert is then Hard with a longer think.
2. Take the search out of Hard, so Expert has a clear lead, and accept Hard over Medium near 55%.
3. Roll out with the Hard policy instead of Medium. May lift Expert, but each rollout costs more, so fewer samples fit in 400 ms.
4. Raise the budgets. Hard gets stronger with more samples, but the player waits longer on every bot turn.

## Decision

None yet. The recommendation is option 2 with option 3 tried on top, then a bar set from what that measures. Tiers should feel different to play against, and Expert should be the one that searches.

## Consequences

P2.9's code is committed, with its tests passing and the sizes above in `default_weights.tres`. Its box stays unticked. P2.10 to P2.12 do not depend on the choice, because each option changes only data or a tier's policy.
