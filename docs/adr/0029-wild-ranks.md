# ADR 0029: Wild ranks (P4.18)

- Status: Accepted, 2026-11-15, by the agent under the design authority ADR 0021 records. The owner judges by playtest.
- Scope: what a wild card is, how a play that uses one is read and compared, how it scores, the three items that bring wild ranks in, and what the bots and the screen must do.

## Why this needs a decision

ADR 0007 left wild substitution to "the item that adds wild ranks". The engine today holds a list of wild ranks and one rule about them: a bomb of a wild rank is the pure-wild bomb, below the rocket. Nothing lets a wild card stand in for another. The Plan names the source (the 癞子 tables of Chinese apps) and three items, and notes that apps disagree on the details. A play read from cards alone stops being unique once a card can be any rank, so the rules below say who decides and how.

## The rules

1. **Wild cards.** While a rank is wild, every card of that rank is a wild card, in every hand. At most two ranks are wild at once. Jokers are never wild.
2. **Standing in.** A wild card may be played as its own rank, or stand in for any rank from 3 to 2. It never stands in for a joker, so it can never make a rocket. A play made only of wild cards is read with at least one of them at its own rank: two wild 7s alone are a pair of 7s, as the published rules of the laizi tables have it.
3. **A play is declared.** A play is a set of cards and one reading of them. When the chosen cards can be read in more than one legal way, the player picks the reading, strongest first in the list; with one legal reading the play goes straight down. The reading stands once played. A bot's move is always a reading.
4. **Comparing.** A play is compared by its reading, as if every card were what it stands for. A wild 7 read as a queen is a queen for every rule about rank: the rank order, Promotion of the Masses, Criticism Meeting, Rehabilitation, Class Label, Inverted Order.
5. **Bombs** come in tiers, high to low: the rocket; the **pure-wild bomb** (exactly four cards of one wild rank, read as that rank); the **natural bomb** (no stand-ins); the **soft bomb** (at least one stand-in). Within a tier the higher rank wins. A bomb is four cards unless rule 6 is in force. This is the order two of the large operators publish; a third puts the pure-wild bomb above the rocket, and the Plan chose the rocket.
6. **Bigger bombs** (only under Industrialization). Five or more cards read as one rank are a bomb. More cards beat fewer, whatever the tier; at the same size the tiers of rule 5 decide, then rank. The rocket still beats every bomb.
7. **Scoring.** Grain comes from the cards as printed: a wild 7 standing in for a queen scores as a 7. A card scores as a body card or a kicker by where the reading puts it. Rate comes from the reading's hand type. Marks stay with the card.
   - **Read the card:** Red Banner (suit), Poor Peasants' Association (printed rank), Hidden Reserves (the kickers' own cards), Landlord's Ledger, Planned Allocation's deal.
   - **Read the reading:** Slogan of the Week, Stakhanovite, Canteen, Collective Farm, Paperwork, Straightened Lines, and everything that fires on a bomb. A soft bomb is a bomb for Cultural Revolution, Show Trial, Steel Target and Requisition.
   - **Class Label:** a rank is raised while every card of it in the holder's hand is stamped, counted on the real cards as today. A wild card standing in for a rank takes that rank's standing, whatever its own stamp.
   - **Taking cards:** where a rule takes a highest or lowest card (Levy, Seizure Notice, Struggle Session, Mutual Aid's return), a wild card counts at its own rank.
   - **Night Shift** asks whether any legal reading beats the table.
8. **Everything else is unchanged.** Wild cards are ordinary cards for dealing, the kitty, the plot, Levy, Redistribution, Mutual Aid, Unplanned Economy and the count of cards left.

## The three items

They are the game's fifth unlock tier: tier 4, open after four finished runs. This is the new mechanic the unlocks promise.

| Item | Kind | Sold at | Rule | Cost |
| --- | --- | --- | --- | --- |
| Model Worker | Campaign, collective | State store | Before the first play: one rank, drawn at random from 3 to 2, is wild this round for everyone. If a rank is already wild, this adds a second. With two already wild it cannot be used. | 3 |
| Mass Line | Reform | State store | Every round, one rank drawn with the deal is wild for everyone. | 10 |
| Industrialization | Reform | State store | Bombs may hold 5 or more cards. A bigger bomb beats a smaller one, and each card past the fourth adds 1 Zeal. | 8 |

- The wild rank is drawn on the deal stream after the deal, so the deal itself does not change. It is shown before anyone bids.
- Wild ranks apply to all three seats, so these items are collective.
- Industrialization also counts for five or more cards of a rank reached through the private plot, where a hand can hold a fifth copy. Until now that was a data flag with no item behind it.

## What the screen must do

- When a rank becomes wild, a call-out names it ("7s are wild"), and it stays named in the table's rules strip for the round.
- Every wild card carries a mark in the strip a fanned hand shows: a small red ribbon under the index, on every seat's played cards too.
- A played wild card that stands in for another rank shows the rank it stands for beside its own, so the pile can be read.
- The reading picker appears only when there is a choice, lists each reading in words ("Bomb of 9s", "Three 9s with a single"), and works with keyboard and gamepad.
- The hint offers a reading, and the Rules sheet gains a section on wild ranks while one is in force.

## What the bots must do

All four tiers choose from moves the generator produces, each with its reading, so no tier can play an illegal one. The tiers that plan a whole hand (Medium, Hard and Expert) count wild cards as cards that can complete a set, within the 300 ms the Expert runner allows. The tiers that judge what opponents may hold (Hard and Expert) count played cards by the cards really spent, and treat a bomb of any rank as possible while a rank is wild, since four unseen cards of a rank are no longer needed for one.

## Consequences

- A play gains, beside its shape, the cards it really spends. Classifying a set of cards returns every legal reading, not one, and move generation enumerates readings with their stand-ins.
- The rules property tests run with no wild rank, one and two, with and without bigger bombs: every generated move is legal, every legal reading of a random selection is generated, and comparison is a strict order.
- The run save records the wild ranks of the round in play. The round's replay needs each play's reading, so a recorded play carries it.
- The tournament tool gains a `--wild N` option.
- The ladder of unlock tiers grows to five, and ADR 0021's table gains a row.

## As built (2026-11-16)

Calls made while building, which the sections above did not settle:

- **Placement.** Where a play's stand-ins could fill either the body or a kicker, they fill the body first, the lowest printed rank and then the lowest ID first. Grain comes from the printed cards, so this costs a little Grain against the other order.
- **Lean generation.** Bots and rollouts never consider a wild card standing in for a kicker, or a four-with-two whose four needs a stand-in. The round still accepts both from the player.
- **The demo stops below tier 4.** A run outside the profile opens tiers 0 to 3 only. The demo, the tutorial and every default test run are unchanged, and no golden moved. The balance harness opens every tier.
- **Model Worker** uses the timing Campaigns already have for "before the first play": a peasant uses it at the opening, the landlord on their first turn. It cannot be used during the bid, so a redeal never meets one. It draws on the deal stream when used.
- **Mass Line redraws on a redeal**, so the rank goes with the deal that is played.
- **Industrialization's Zeal is for every seat's bombs**, since the rule is the table's. It is 1 per card past the fourth, as data (`zeal_percent_per_card` 100).
- **Bids** count each wild card held at `wild_card_points`, 2, a 2's value.
- **Ranks are named in words**, "Sevens are wild" and "Bomb of Nines", not "7s" and "Bomb of 9s" as the examples above have it: the call-out is set in capitals, where "AS" does not read as Aces. A Single and the ends of a chain keep the printed glyph.
- **The hint's reading is played without the picker** while the selection is still the hint's cards on the same turn. Any other selection that can be played more than one way opens the picker.
- **The strip names the wild ranks on its first line** and no more, since the trick pile lies over the strip's lower lines; what a wild card may do is on the Rules sheet. Industrialization is listed under the rules for the whole table, on the strip and on the sheet.
- **The Rules sheet is drawn smaller when it would not fit**, so no rule in play is ever cut off.
- **Nothing announces a tier opening between runs**, as for tiers 1 to 3. The collection shows the three items locked until then.

Not done: a full `tools/expert_deadline.gd -- --wild 1` run. A 20-deal sample gave a p99 of 403 ms with one wild rank against 355 ms with none, both over the 300 ms the runner is set to, and 20 deals is too few to trust. P5.0 moves Expert off the command thread and takes the full measurement with it.
