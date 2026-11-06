# ADR 0014: Plot cards across rounds

## Status

Accepted, 2026-11-05 (project owner, during Phase 4 planning). Built in P4.8.

## Context

Each round deals a fresh 54-card deck with IDs 0 to 53. A plot swap moves one of those deck cards into the private plot. In the next round the fresh deck holds the same ID again, which breaks P1A.3's rule that IDs are unique within a run. The new copy can then be dealt to any seat while the plot holds the old one: a swap brings a duplicate into play, or `Hand.add()` refuses it and a card disappears. Both reviews of Phase 3A reproduced this. One also found that the landlord can't swap a kitty card, because the swap step runs on the 17 dealt cards before the round adds the kitty.

## Options

1. **A swapped-out deck card leaves the shared deck.** The run keeps its own deck in `RunState`, which also carries enhancements and stamps across rounds (P4.9). The deck shrinks while the plot holds deck cards, so the deal needs a rule for fewer than 54 cards.
2. **A swapped-out card becomes a plot card.** It gets a new plot ID (1000 and up, from a counter in `RunState`) and keeps its rank, suit and marks. The fresh deck stays 54 cards.
3. **Swaps last one round.** Each card goes back where it came from at round end, and a card that was played goes back to its owner. This matches the Plan's "cards that return to the plot after scoring" upgrade being a special case.

The kitty question is separate. Either the swap waits until the landlord holds the kitty (then the kitty, already revealed, can be swapped away), or kitty cards stay out of swaps.

## Choice

**Option 2, with kitty swaps.**

- A deck card swapped into the plot is reissued as a plot card: a new ID from `RunState.next_plot_id` (1000 and up), with its rank, suit and marks kept. The fresh deck stays at 54 cards, and its IDs never meet a plot card's.
- The swap runs after the landlord takes the kitty, so a landlord may swap a kitty card. The kitty has already been revealed to the table by then.

## Consequences

- `RunLoop._begin_play` creates the round, with the kitty taken, before the swap. `RoundState.exchange` trades cards in the seat's hand before the first play.
- `PlotSwap.apply` reissues each deck card that enters the plot.
- `tests/integration/test_private_plot.gd` checks conservation and unique IDs across rounds, kitty swaps, reissue, and the fifth-copy rule.
