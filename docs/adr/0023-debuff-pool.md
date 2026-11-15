# ADR 0023: The debuff pool (P4.12)

- Status: Accepted, 2026-11-15, by the agent under the design authority ADR 0021 records. The owner judges by playtest.
- Scope: the 14 debuffs the Plan lists that are not built yet, as they work under Grain × Rate × Zeal (ADR 0020) and beside the P4.11 content (ADR 0021).

## Why this needs a decision

The Plan's debuff table uses terms the game no longer has. Zeal no longer has a base per hand type (ADR 0020), an audit is now a die (ADR 0021), and one debuff shares its name with a Cadre. Some rows also need a rule for cards that leave a hand, and for what repeats while a debuff stays in force.

Six debuffs are built: Ration Cut, Paperwork, Morning Meeting, Straightened Lines, Criticism Meeting and Inverted Order.

Debuffs are the game's roadblocks. They never build toward anything, and the player sees the whole ladder before the Quota starts. A debuff that takes more from a stronger build is working as intended.

## Decisions

**One name changes.** The tier 4 debuff "Show Trial" becomes **Big-Character Poster**, because Show Trial is a Cadre. Its ID is `big_character_poster`.

**No card ever leaves the table.** The dealer and the no-shuffle deal need all 54 deck cards, and the bots count unseen cards from a full deck. A debuff that "takes" a card moves it to another hand, through `RoundState.trade()`, which already keeps the public kitty honest when a kitty card changes hands.

**Every debuff applies to the player only**, as the six built ones do, unless its row says otherwise.

**A debuff stays in force for the rest of its Quota**, as the built ones do: one drawn for round 2 also applies in rounds 3 and 4. "Each round" below means each round it is in force.

| Tier | Debuff | Lever | Rule |
| --- | --- | --- | --- |
| 1 | Short Supply | Economy | The next state store shows one fewer Cadre. It stacks with rationing. |
| 1 | Slogan of the Week | Scoring | One hand type, named with the ladder, scores at half its Rate, rounded up. Rocket is never named. |
| 2 | Levy | Hand | Each round, before play, your highest card goes to the player on your left, teammate or not, and you get their lowest. After the kitty, before the plot swap. |
| 2 | Work-Point Audit | Meters | Two more faces of the die mean an audit, for every claim, yours too. |
| 2 | Night Shift | Hand | Each round, the first time you could pass, you must play if you hold anything that beats the table. |
| 2 | Grain Tax | Economy | 20% of what you bank each round is taken before it counts toward the Quota, rounded against you. |
| 2 | Shared Kitchen | Hand | Only 1 private-plot swap a round. |
| 3 | Confiscation | Scoring | Each round, one of your Cadres, drawn at the round's start, does nothing. Its count is kept. With no Cadres it does nothing. |
| 3 | Glass Walls | Hand | Both opponents see your hand. |
| 3 | Redistribution | Hand | Each round, before play, every player passes 2 cards drawn at random to the player on their left. After the kitty, before the plot swap. |
| 3 | Overtime | Scoring | You bank a round's score only if your side goes out first. |
| 4 | Big-Character Poster | Meters | Each round your side loses, Denunciation rises by a full band. |
| 4 | Hungry Winter | Meters | Each round your side loses, Famine rises by a full band. |
| 4 | Plot Seized | Hand | No plot swap. One plot card, drawn at random, is destroyed when it first comes into force. With an empty plot only the swap is lost. |

## Rulings

- **Work-Point Audit amends ADR 0021**, which gave it one more audit face. It adds two (data), so 3 faces of 6 audit, or 4 with an informer family in the village. ADR 0021's cap stays: at most 5 faces audit, so a check is never certain.
- **Marks travel with cards.** A stamped or Model card moved by Levy or Redistribution keeps its mark for the round. A deck card's saved mark is kept by its deck ID, so who held it for a round changes nothing afterwards. A stamp still scores only for its owner.
- **Draw order.** Random choices (the Slogan's hand type, the confiscated Cadre, Redistribution's cards, the seized plot card) are drawn on existing seeded streams at fixed points, so a save replays them. The Slogan's hand type is drawn with the ladder, shown with it, and saved with it.
- **Slogan and Rate caps.** The Rate is halved first. A cap such as Iron Rice Bowl's applies after.
- **Glass Walls is real.** The bots that reason about hidden hands are given the player's cards. This is a new path: bots see only public state and their own hand today. The screen shows the hand as exposed.
- **Night Shift never traps.** With nothing that beats the table, the player passes as usual and the debuff is spent for the round.
- **A full band** is a row in the meter table: 25 today, the width of every band.
- **Plot Seized destroys for good.** The destroyed plot card is gone for the run, with its marks.
- **Appeal** lifts what the newest debuff still does this round. Cards already moved by Levy or Redistribution stay moved, and a plot card already destroyed stays destroyed, because Appeal is used after the plot swap.
- **Overtime and Overfulfillment.** If both are in force, losing banks nothing and winning banks the Campaign's multiple.
- **Lever limit.** The ladder allows one debuff per lever in a Quota, so the seven scoring debuffs never stack with each other.

## Consequences

- The ladder report and the Plan-pool ladder test move from the fixture table to the real pool, and the fixture is deleted.
- Each debuff ships with a scenario test, its string keys, and a table beat where a card or a Cadre visibly changes (Levy, Redistribution, Confiscation, Glass Walls, Plot Seized).
- The Slogan's hand type is new saved state. If it changes the checkpoint's shape, the run save moves to schema 9 with a migration.
- The tier budgets and every number above are starting values for P4.16.
