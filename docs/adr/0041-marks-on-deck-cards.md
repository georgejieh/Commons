# ADR 0041: Marks on deck cards

- Status: Accepted, 2026-11-24. The owner's direction from their playtest of 2026-11-24; the design is the lead's, the names and details below are the agent's.
- Scope: card enhancements, their scoring and their marks on the card face, the Campaigns that give them, a desk in each shop that marks a deck card, the deck sheet, and the save.

## Why this needs a decision

The owner, after playing: "we need ways to modify cards in decks too, because i think currently right now its only private plots". And, on what such changes are: "effects that directly modify cards in the deck stays persistent in the deck until end of run", "effects that only care about scoring can effect villagers", "effects that changes how the game is played but doesnt effect scoring should not effect villagers".

Before this, a deck card could carry one enhancement, Model, and the player's stamp (ADR 0021), and the only ways to give them were two Campaigns used on cards in hand: Model Harvest and Registration Drive. The owner played two Years without meeting either, and nothing showed what the deck held. The fault was breadth and visibility.

## Options

1. More Cadres that act on cards of a rank or suit. Rejected: they change scoring through the board, not the deck, and the owner asked for the deck itself to change.
2. Marks that sit on single deck cards for the run, each a scoring effect, given by Campaigns and by a desk in each shop, with a sheet that shows the whole deck. Chosen.

## Decision

**Rules that hold for every mark.** A mark is on the card in the communal deck for the rest of the run and goes wherever the deal sends it: into a villager's hand as readily as the player's. A scoring mark works for whoever scores the card, because it is a scoring effect (ADR 0039's amendment). A card holds one enhancement at a time: a new one replaces the old, and the player is told before it happens. Separately it may carry the player's stamp. Nothing a mark does changes what may be played or what beats what. A kicker scores nothing, so a mark on a kicker does nothing.

**Four enhancements**, each on a different lever. Every number is in `ScoreParams` (`data/scoring/default_scoring.tres`), beside Model's.

| Enhancement | ID | Effect | Number |
| --- | --- | --- | --- |
| Model | `model` | The card scores its printed Grain at a percent | `model_grain_percent` 200 |
| Sheaf | `sheaf` | The card scores a flat amount of Grain more; best on low cards, where Model's doubling is small | `sheaf_grain` 10 |
| Pennant | `pennant` | The play that scores the card gains Zeal, for each such card | `pennant_zeal` 0.2 |
| Surplus | `surplus` | When the player scores the card it pays coupons, up to a most a round; a villager who scores it is paid nothing, since coupons are the household's | `surplus_coupons` 1, `surplus_round_most` 2 |

The names are the game's: a model worker's rosette, a sheaf of wheat, an emulation pennant and a surplus ration coupon, all things a brigade office hands out on paper and cloth. The lead's working names were Bumper and Red Flag; a five-pointed star and a real flag are on art/STYLE.md's list of things not drawn.

**Scoring.** `Scorer.marked_grain` gives a scored card's Grain before any hook: Model's percent of the printed Grain, or the printed Grain and the Sheaf's. Each scored Pennant card adds its Zeal to the play's `add_zeal` before the play hooks run, so a hook's additive Zeal adds to it and a multiplier multiplies the sum. Each scored Surplus card is listed on the `ScoreBreakdown`, and `RunLoop` pays the player's through `SurplusPay`, which counts what it paid since the deal. The count is not saved: a save replays the round's plays, which pay the same.

**The trail.** Each mark is a step of its own on its card (`ScoreStep.Source.MARK`, its `source_id` the enhancement): a Sheaf's or Model's Grain, a Pennant's Zeal among the card steps, and a Surplus card's coupons after the whole score, as a step of the `COUPONS` figure, which is no part of the score and has no chit on the tally. At the table the card flashes on the pile and its tag says "+10 Grain", "+0.2 Zeal" or "+1 coupon".

**On the card face.** `CardMark` draws each in code, in the worn paper-and-ink manner of the chop and the rosette, each its own shape so they tell apart in grayscale and at the hand's size: Model's round rosette with two tails, an upright ear of wheat with a red band, a pointed pennant on a staff, and a coupon wider than tall with torn perforated ends. A card shows one at the rosette's place on the left edge; the stamp's chop stays at the foot. Every view that shows a card through `CardView` shows them: the hand, the pile, the swap sheet, the black market's plot stall and an envelope's plot cards. The informant's and Peek's views name ranks in words and show no mark, Model's included, so they are unchanged. Each has a keyword (`Keywords.TERMS`) whose meaning quotes the data's number.

## Consequences

- A villager who is dealt a Sheaf or Pennant card scores it; that is the owner's rule for scoring effects, and it can cut against the player as landlord.
- Saved marks are card IDs to enhancement IDs, so no schema changes and every older save loads as before.
