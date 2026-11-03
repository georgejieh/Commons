# ADR 0014: Plot cards across rounds

## Status

Proposed. Needed before P4.8. Until then the plot starts empty and nothing fills it, so play never reaches this.

## Context

Each round deals a fresh 54-card deck with IDs 0 to 53. A plot swap moves one of those deck cards into the private plot. In the next round the fresh deck holds the same ID again, which breaks P1A.3's rule that IDs are unique within a run. The new copy can then be dealt to any seat while the plot holds the old one: a swap brings a duplicate into play, or `Hand.add()` refuses it and a card disappears. Both reviews of Phase 3A reproduced this. One also found that the landlord can't swap a kitty card, because the swap step runs on the 17 dealt cards before the round adds the kitty.

## Options

1. **A swapped-out deck card leaves the shared deck.** The run keeps its own deck in `RunState`, which also carries enhancements and stamps across rounds (P4.9). The deck shrinks while the plot holds deck cards, so the deal needs a rule for fewer than 54 cards.
2. **A swapped-out card becomes a plot card.** It gets a new plot ID (1000 and up, from a counter in `RunState`) and keeps its rank, suit and marks. The fresh deck stays 54 cards.
3. **Swaps last one round.** Each card goes back where it came from at round end, and a card that was played goes back to its owner. This matches the Plan's "cards that return to the plot after scoring" upgrade being a special case.

The kitty question is separate. Either the swap waits until the landlord holds the kitty (then the kitty, already revealed, can be swapped away), or kitty cards stay out of swaps.

## Choice

None yet. This is a design decision for the project owner, made with P4.8.

## Consequences

- Until then `PlotSwap.is_valid()` refuses a plot card whose ID is already in the hand, so a swap can't shrink the hand. A duplicate ID in another seat is still possible, and the plot stays empty in play.
- Whichever option is chosen changes `PlotSwap`, the deal in `RunLoop`, and possibly `RunState`, and P4.8's conservation test has to cover swaps across rounds.
