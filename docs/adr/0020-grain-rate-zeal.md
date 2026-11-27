# ADR 0020: Scoring as Grain × Rate × Zeal

## Status

Accepted by the project owner on 2026-11-12. Replaces the Grain × Zeal model of P1C.5.

## Context

A play scored `(hand-type base Grain + card Grain) × hand-type Zeal`, and each bomb or rocket doubled Zeal. J, Q and K were all worth 10 Grain. The owner found the result unreadable:

- Grain looked random. A Single 9 showed 14 Grain, because the hand type's base was hidden inside it, and a K counted the same as a 10.
- Zeal looked tied to the hand type, since every hand type had its own base Zeal. Modifiers that changed Zeal could not be told apart from the hand type.
- The hand type counted twice, once in Grain and once in Zeal, with a third hidden doubling for bombs.

## Decision

A play scores **Grain × Rate × Zeal**, and each part has one source.

1. **Grain** is the sum of the scored cards' rank values, plus additive Grain from modifiers. Card values by rank are 3 to 10 at face value, J 11, Q 12, K 13, A 14, 2 15, Small Joker 16 and Big Joker 17. Kickers still score no Grain unless a modifier (Hidden Reserves) scores them. There is no hand-type base Grain.
2. **Rate** comes only from the hand type and its level, from `ScoreParams.hand_rate`. Hand levels raise Rate and nothing else. The bomb and rocket doubling is folded into their Rates. A modifier may cap Rate (`PlayContext.rate_cap`).
3. **Zeal** starts at 1 for every play and changes only through modifiers: `max(min_zeal, (1 + add_zeal) × mul_zeal)`. `min_zeal` is 0.5. Zeal can be fractional and is shown to the hundredth when it is not whole, so 0.75 never reads as 0.8.

Level 1 Rates are the owner's. For levels 2 to 10 each Rate keeps a reference play close to its old total: `rate(L) = round(old_total(L) / new_grain)`, where the reference play is the hand type's scored cards all valued 8 (a Single 8, a Pair of 8s, a 5-card Straight 6 to 10, 3 pairs, 2 trios, a bomb of 8s), at the minimum legal chain length, and the Rocket's two jokers (old 13 + 14, new 16 + 17). Where rounding would tie a level with the one below, the Rate goes up by one, so every row strictly increases. The numbers are written in the data file, not computed at runtime.

| Hand type | L1 | L2 | L3 | L4 | L5 | L6 | L7 | L8 | L9 | L10 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Single | 1 | 6 | 12 | 22 | 33 | 47 | 64 | 83 | 105 | 129 |
| Pair | 3 | 8 | 14 | 22 | 32 | 44 | 58 | 74 | 91 | 111 |
| Trio | 6 | 15 | 27 | 43 | 61 | 83 | 109 | 137 | 169 | 205 |
| Trio + single | 7 | 18 | 32 | 50 | 73 | 100 | 131 | 166 | 205 | 249 |
| Trio + pair | 10 | 22 | 38 | 58 | 82 | 110 | 143 | 179 | 220 | 265 |
| Straight | 7 | 18 | 33 | 52 | 76 | 105 | 138 | 175 | 217 | 264 |
| Pair Run | 7 | 17 | 31 | 48 | 69 | 94 | 123 | 155 | 191 | 231 |
| Airplane | 11 | 24 | 41 | 62 | 88 | 118 | 152 | 191 | 234 | 282 |
| Airplane + singles | 12 | 26 | 43 | 65 | 91 | 122 | 157 | 197 | 240 | 289 |
| Airplane + pairs | 15 | 32 | 52 | 78 | 108 | 144 | 184 | 230 | 280 | 336 |
| Four + two singles | 20 | 38 | 62 | 91 | 126 | 166 | 213 | 264 | 322 | 385 |
| Four + two pairs | 22 | 43 | 70 | 104 | 144 | 190 | 244 | 304 | 370 | 443 |
| Bomb | 32 | 65 | 106 | 158 | 219 | 291 | 372 | 464 | 565 | 677 |
| Rocket | 50 | 96 | 168 | 238 | 343 | 440 | 578 | 703 | 874 | 1026 |

The breakdown's steps are card Grain, added Grain, Rate, Rate cap, added Zeal and multiplied Zeal. The Zeal cap and the bomb Zeal step are gone, because nothing uses them.

## Consequences

- **Modifiers convert, keeping their meaning.** Parameters stay integers, with Zeal in hundredths under names that start with `zeal_percent`, which `ModifierDef.text_values()` writes as decimals in rules text.
  - Great Leap: +2 Zeal becomes +0.5 Zeal (`zeal_percent: 50`).
  - Ration Cut: −1 Zeal becomes −0.25 Zeal (`zeal_percent: 25`).
  - Stakhanovite: +2 Zeal per card past 5 becomes +0.5 Zeal per card (`zeal_percent_per_card: 50`).
  - Iron Rice Bowl keeps +30 Grain; its Zeal cap of 6 becomes a Rate cap of 20 (`rate_cap: 20`). At level 1 only bombs and rockets exceed 20, so with the added Grain a level-1 bomb under the Bowl now scores more than without it (1,320 against 1,152 for four 9s), where it used to score less. Leveled hands still hit the cap.
  - Paperwork, Straightened Lines, Landlord's Ledger, Red Ink, Hidden Reserves, Morning Meeting and Requisition need no change: they act on Grain or the total, which keep their meaning.
- **Totals move with rank.** At level 1, plays of low cards score less than before and plays of high cards more, because the hand-type base Grain used to lift every play by the same amount. Four 9s go from 1,088 to 1,152, a Straight 3 to 7 from 220 to 175, an Airplane 333444 from 405 to 231, and a Pair of Ks from 60 to 78. Across the run golden's five Sets, a Set's total moved between −7.5% and +4.9%, and no Set changed outcome.
- **Quotas are untouched and untuned.** The Rates were chosen to keep totals close, so quota targets keep their values. Whether they still feel right is for playtesting.
- **Bot strength is unmeasured.** Bots value moves with their own `CandidateScorer`, which does not read the scoring tables, so their play is unchanged. How the new totals change what a good play is has not been measured.
- `PLAY_SCORED` events and `PlayPreview` carry `rate` beside `grain` and `zeal`, and the ledger and action bar write "Grain × Rate × Zeal". Run saves hold no scoring tables or play scores, so the schema does not change. A save is the state at its Set's start plus the player's commands, though, so a run saved mid-Set before this change replays that Set under the new scores and may reach the target at a different point; a command the loop is not waiting for changes nothing. No migration is attempted, since no saves have shipped.
