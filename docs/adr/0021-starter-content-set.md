# ADR 0021: The starter content set (P4.11)

## Status

Proposed, 2026-11-14. Waiting for the project owner. P4.11 is blocked until this is accepted or changed.

## Context

P4.11 asks for the Plan's 12 Cadres, then Campaigns, Directives and Reforms. Six of the Plan's twelve Cadres are built. The Plan names the other six and gives each one line, without numbers. It gives Campaigns, Directives and Reforms a role each. It sketches two Campaigns (Model Worker, Overfulfillment) and three Reforms (Mass Line, Unplanned Economy, Industrialization), and names no Directive.

The owner agreed, in the approved Phase 4 plan, to a starter set of about 6 Campaigns, 6 Directives and 4 Reforms, drafted here for approval. Growing to 60 Cadres is a later content pass.

All names are working names, and every number is a first guess that will live in data. Rules text goes through `commons-prose` after approval, and P4.16 tunes the numbers.

What the engine has today, which decided several choices below:

- Hand-type levels exist (`HandLevels`, 10 levels per type in data). Nothing raises them yet.
- `RunInventory.consumables` exists and is saved, but no path in the game adds to it or uses it.
- Hand levels are rebuilt with the run loop and are not saved.
- Owner stamps exist on cards (`CardModifiers.stamp`), and Red Ink scores off them. Nothing in the game stamps a card yet. Each stamped card you score already adds 1 Resentment.
- The deck is built new for every deal (`RunLoop._deal_cards`), so a stamp or enhancement does not yet outlast its round.
- Wild ranks exist only as a tier for a bomb made of a wild rank. Nothing lets a wild card stand in for another: not hand classification, not move generation, and so not the bots.
- The whole deck is dealt every round (17, 17, 17 and a kitty of 3), so there is no pile to draw or redraw from.
- A landlord banks their round total whether they win or lose.

## The six remaining Cadres

Costs here and below are base costs. The state store charges them as listed, and the black market charges 150%, rounded up, as it does today.

| Cadre | Tag, sold at | Effect | Cost |
| --- | --- | --- | --- |
| Rehabilitation | Private, black market | You pick a rank when you buy it. Your cards of that rank beat one more rank for each Year since. It stops below the jokers. | 6 |
| Class Label | Private, black market | While you are landlord, your stamped cards rank above 2s and below the jokers. | 5 |
| Collective Farm | Collective, state store | A peasant's Pair also scores the Grain of their teammate's last play this round. Applies to both peasants. | 5 |
| Show Trial | Private, black market | Your Bombs and Rockets score double Zeal. Each one adds 3 Resentment. | 6 |
| Model Commune | Collective, state store | When the peasants win and your teammate went out first, the round's Commons is multiplied by 1.5. | 5 |
| Ration Coupon | Collective, state store | Every 4th time you pass in a Quota, you earn 1 coupon, up to 3 a Quota. | 4 |

Two changes to Cadres already built:

- **Stakhanovite grows**, as the Plan says. Each Straight of 7 or more cards you play adds 0.05 to its Zeal per card, for the rest of the run.
- **Red Ink returns** to the black market once Registration Drive can stamp cards.

Hand types still form by printed rank under every rank Cadre. Only what beats what changes.

## Campaigns

One use each. You hold up to 2. A Campaign is used on your turn, or at the moment its text names.

| Campaign | Tag, sold at | Effect | Cost |
| --- | --- | --- | --- |
| Registration Drive | Private, black market | Stamp up to 3 cards in your hand as yours. The stamps stay on those cards for the run. | 3 |
| Model Harvest | Collective, state store | Mark up to 2 cards in your hand. Each scores double Grain for whoever scores it, for the run. A kicker still scores nothing. | 3 |
| Seizure Notice | Private, black market | Take the highest card from the opponent holding the most cards, and give them your lowest. Adds 4 Resentment. | 4 |
| Anonymous Letter | Private, black market | The next player must pass. Adds 2 Resentment. | 3 |
| Overfulfillment | Collective, state store | As landlord, after you take the kitty: win the round and your total doubles, lose it and you bank nothing. | 4 |
| Mutual Aid | Collective, state store | As a peasant, before the first play: you and your teammate each pass the other 2 cards. The bot chooses its own. | 3 |

Model Harvest is the Plan's Redistribution: the improved card goes back into the shared deck and can be dealt to anyone.

## Directives

One use each, used from the store when bought. Each raises a family of hand types by one level, and together the six cover all 14 types.

| Directive | Raises | Cost |
| --- | --- | --- |
| On Hand Tools | Single, Pair | 3 |
| On Work Teams | Trio, Trio with a Single, Trio with a Pair | 3 |
| On Deep Ploughing | Straight | 3 |
| On Close Planting | Pair Run | 3 |
| On Combined Brigades | Airplane and both Airplanes with wings | 4 |
| On Launching Satellites | Four with two (both kinds), Bomb, Rocket | 5 |

The state store sells them. Three names borrow real Great Leap terms: deep ploughing and close planting were farming methods the state promoted, and "launching a satellite" meant announcing a record yield, often an inflated one. They are names only, with no quoted slogan. The P5.5 sensitivity read covers them.

## Reforms

Permanent for the run. The state store offers one Reform per visit, in its own slot.

| Reform | Effect | Cost |
| --- | --- | --- |
| Enlarged Committee | You can hold one more Cadre (6, up from 5). | 10 |
| Supply Cooperative | The state store shows one more item on every visit. | 8 |
| Grain Reserve | A missed Quota adds 3 less Famine. | 8 |
| Unplanned Economy | The deck is no longer shuffled between rounds. Cards are gathered in the order they were played and cut, so bombs become common for everyone. | 8 |

## Questions for the owner

1. **Wild ranks are left out.** The Plan's Model Worker, Mass Line and Industrialization all need a wild rank. That means teaching hand classification, move generation and all four bot tiers about wild cards, which is closer to a rules item than a content item. I propose its own checklist item after P4.12, with those three as its content.
2. **Picking a rank.** Rehabilitation needs the player to choose a rank at purchase. The Plan gives Planned Allocation "a chosen rank" too, but it is built fixed at 2s. I propose one small rank picker for both.
3. **Hand swaps are left out.** The Plan lists "swap hands" as a Campaign idea. A landlord holds 20 cards against 17, so a whole-hand swap keeps hand sizes only between peasants before the first play. Mutual Aid is the small version of it.
4. **The Directive names** that borrow real terms, against invented ones.

## Consequences

- Stamps and enhancements must outlast the round. `RunState` gains a record of marked deck cards, applied when the deck is built. Unplanned Economy needs the last round's play order saved the same way, and hand levels need saving for Directives.
- New engine pieces: holding and using consumables (with save and replay commands), a store slot for Reforms, a pass counter, the rank picker, card enhancements that score, and per-Cadre run state for Rehabilitation's rank and Stakhanovite's growth. Run saves go to schema 5.
- The bots need to know Seizure Notice, Anonymous Letter and Mutual Aid can happen. They do not use Campaigns themselves in the starter set.
- Every item gets a golden test and its string keys. New art: 6 Cadres, plus Planned Allocation, The Informant and Peek, which still have none. Campaigns, Directives and Reforms use one card frame each, with the name set in type.
- `docs/ARCHITECTURE.md` gains the consumable and Reform flow when it is built.
