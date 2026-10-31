# ADR 0007: Reading a play and the kicker rules

## Status

Accepted

## Context

P1B.3 needs one reading for any set of cards, and an ambiguity rule. The Plan's rules table also leaves three kicker questions open: whether a chain rank's spare card can be a kicker, whether single wings may form a pair, and whether a quad may carry both jokers.

## Options

- Search subsets of the cards for a reading. Simple, but too slow for bots.
- Read the histogram of ranks holding 1, 2, 3 and 4 cards. O(15), and each play has one body shape.

For the kicker questions the choices were to follow [Pagat](https://www.pagat.com/climbing/doudizhu.html), which the Plan uses as its cross-check, or to be stricter.

## Decision

Read the histogram. The order is rocket, then bomb, then the valid reading with the highest main rank.

Under the default rules a count vector has at most one reading after the rocket and bomb, because the histogram fixes the body: a quad means four-with-two, any trios are the whole chain, and otherwise the cards are a chain of pairs or singles. The highest-main-rank rule is the stated tiebreak if a later modifier ever creates two readings, and no code path needs it yet.

Kicker rules follow Pagat:

- Kickers differ in rank from the body. A rank with four cards is never split between an airplane's body and its wings.
- Every trio in the play must be in the chain, so a trio can't be a wing, and a separate trio makes the play invalid.
- Single wings are either all different ranks, or pairs that fill two single-wing slots each (`single_wings_may_pair`). 4-4-4-5-5-5-9-9 is legal. 3-3-3-4-4-4-5-5-5-6-7-7 mixes a single with a pair and is not. Pagat's own example of mixing has the wrong card count, so the Plan's "never mixed" settles this.
- Pair wings are different ranks from each other, so a bomb can't be two pair wings.
- Both jokers can never be kickers (`rocket_may_be_kicker`), on wings as the Plan says and on a quad as Pagat says.

Wild rank substitution is not in P1B. The RuleSet holds the wild ranks, and the comparator treats a bomb of a wild rank as pure-wild, which settles the disputed rule. Reading a wild card as another rank belongs to the item that adds wild ranks.

## Consequences

Classification stays O(15), and move generation can match it exactly. A later rule that makes two readings legal, such as trios carrying trios, must add the tiebreak in the same change.
