# ADR 0010: What "tier A beats tier B" means

## Status

Accepted

## Context

P2.9 asks each tier to beat the tier below at least 60% of the time over 2,000 seeded games. A single game can't show that, because the landlord side has a built-in edge and deals swing results.

## Options

- Seat one A with two Bs at random. Noisy, and A would often share a side with B.
- Let bidding pick the sides. Tiers bid alike, so this mostly measures the deal.
- Fix the sides and play each deal twice with them swapped.

## Decision

Play each seeded deal twice with a fixed landlord in seat 0: A as landlord against two Bs, then B as landlord against two As. A's win rate is across both games, and bidding is left out. `SelfPlay.play_duplicate()` does this, so 2,000 games means 1,000 deals.

Full games with bidding are reported separately by the tournament harness.

This is the project's own method. DouZero's paper ([arXiv 2106.06135](https://arxiv.org/abs/2106.06135)) also reports winning percentage over sampled decks with per-position results, but we did not confirm that it swaps sides on the same deal.

## Consequences

Deal luck cancels within each pair, so samples go further. A tier's strength as landlord and as peasant both count, and the harness reports them apart. The 60% bar is demanding: that paper has DouZero beating the next-best program only 58.6% of the time.
