# ADR 0013: How a debuff ladder spends its severity budget

## Status

Proposed. P3A.4 is built on option 2 and stays blocked until the project owner accepts or changes it.

## Context

P3A.4 asks for one debuff for each round after the first, under a tier cap, 60/30/10 tier weights, no repeats, one debuff per lever, and a severity budget per Set (small 5, large 6, boss 8), with "redraw one tier lower" when a draw would exceed the budget. These rules can conflict. In a small Set, rounds 2 and 3 drawing tiers 2 and 3 spend the whole budget of 5, so round 4 can't draw anything without exceeding it. The lever rule adds a second conflict: the Plan's only tier-1 debuffs pull the scoring and economy levers, so a late round can find nothing legal at any tier it can afford.

Both reviews of Phase 3A flagged that the code resolves this with a rule no document states.

## Options

1. **Spend greedily.** Redraw lower only when this draw would pass the budget. Later rounds often go clean once the budget is spent, which breaks "one debuff each round" in most small Sets.
2. **Reserve one point per later round (built).** Each round's tier is capped at the budget minus one point for each round still to draw. Every round can still afford tier 1, so a round goes clean only when the lever rule leaves nothing. Measured over 100,000 ladders with the Plan's pool, the last round is clean in 5.4% of small and 2.6% of large Sets, and never in boss Sets. The cost: the weights bend in small Sets. Round 3 is tier 3 in about 20% of small ladders, not 60%, and round 4 is mostly tier 1.
3. **Change the numbers instead.** Raise the small and large budgets, or add tier-1 debuffs on other levers in P4.12, so option 1 rarely runs dry.

## Choice

Option 2, pending the owner's decision. It keeps every hard rule (cap, no repeats, levers, budget) and comes closest to one debuff per round.

## Consequences

- `DebuffLadder.draw()` is the only code that changes under another option, and `tools/ladder_report.gd` shows the effect of any change.
- With option 2, tuning the budgets or the tier-1 pool in P4.12 changes how often small Sets reach tier 3 and 4.
