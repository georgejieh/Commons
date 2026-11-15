# ADR 0021: Content, growth and pushback (P4.11)

## Status

Accepted, 2026-11-14. The project owner handed the design calls to the agent on that day and reviews them by playtest. Every number here is a first guess that lives in data, and P4.16 tunes it. Names are working names until the `commons-prose` pass.

## Context

P4.11 asks for the Plan's 12 Cadres, then Campaigns, Directives and Reforms. Six of the twelve are built. The Plan gives the other six one line each, sketches two Campaigns and three Reforms, and names no Directive.

The owner set the goals this content has to serve:

- Commons is a roguelike deckbuilder first, not a Fight the Landlord simulator. There must be enough content to build a strategy that hangs together.
- Only the player builds. The game and the villagers put obstacles in the way, or score without a plan.
- Power grows during a run, and a little between runs as stronger things unlock.
- When the player grows stronger, the game grows harder because of it. That is the political message, and it stays underneath the play.
- The look and tone change across playthroughs with corruption (ADR 0018).

What the engine has today, which shaped the choices:

- Hand-type levels exist (`HandLevels`, 10 levels per type in data). Nothing in the game raises them, and they are not saved.
- `RunInventory.consumables` exists and is saved, but no path in the game adds to it or uses it.
- Owner stamps exist on cards, and Red Ink scores off them. Nothing in the game stamps a card. Each stamped card you score already adds 1 Resentment.
- The deck is built new for every deal (`RunLoop._deal_cards`), so a mark on a card does not yet outlast its round.
- Wild ranks exist only as a tier for a bomb made of a wild rank. Nothing lets a wild card stand in for another.
- The whole deck is dealt every round, so there is no pile to draw from.
- A Quota ends after the first finished round that brings it to its target, or after 4 rounds.
- Base targets grow about 27 times from Year 1 to Year 8 for the same kind of Quota, and the last one is 40 times the first. A build has to scale.

## How the game answers a strong player

**Overfulfilment.** Beating a Quota by a quarter or more is rewarded and punished at once:

- Each full 25% over the target is one step, up to 4 steps a Quota.
- Each step pays 1 extra coupon.
- Each step raises every later Quota's target by 3%, for the rest of the run. The raise never comes back down.
- Each step adds 1 Resentment. The village pays for your record.

Soviet-type planners often set the next target partly from the last result. Economists call this the ratchet effect, and it gave managers a reason to hide what they could do. The player gets the same lesson. A Quota ends with the round that reaches its target, so the overshoot is whatever that round lands, and a player near the target can choose to hold back.

**The other answers are already built** and stay as they are: debuff ladders, bosses, Resentment turning the villagers on a landlord, Famine and Denunciation.

## Audits are dice

An audit was a hidden 15% roll. It is now a die the player can see: two dice thrown into a bowl together, one per villager who declared, each in that seat's colour. A 1 means that villager is audited. They are drawn as traditional Chinese dice, with a large red 1, a red 4 and the other faces black.

- One face of six is 17%. An informer in the village adds a face (33%). Work-Point Audit (P4.12) adds another.
- At most 5 faces audit, so a check is never certain.
- The shown chance and the die always agree, because the die is the rule.

## What the player collects

| Kind | Holds | Lasts | Where it comes from |
| --- | --- | --- | --- |
| Cadre | 5 | The run | Collective at the state store, private at the black market |
| Campaign | 2 | One use | Either shop by tag, and envelopes |
| Directive | Used at once | The run | State store, and envelopes |
| Reform | No limit | The run | State store, one offered per visit |
| Plot card | The plot's room | The run | Black market |
| Mark on a card | On the card | The run | Campaigns, and marked plot cards from parcels |

Costs below are base costs. The state store charges them as listed. The black market charges 150%, rounded up, and every purchase there adds Resentment, as today.

**Marks** are saved per deck card and put back on each new deal. There are two: an owner's **stamp** (yours alone; Red Ink and Class Label read it) and **Model** (the card scores double Grain for whoever scores it). A Model card goes back into the shared deck, so an opponent can be dealt your upgrade. A kicker still scores nothing.

**Envelopes** are the packs. Opening one shows three items, and you keep one.

| Envelope | Sold at | Holds | Cost |
| --- | --- | --- | --- |
| Directive envelope | State store | 3 Directives | 4 |
| Campaign envelope | State store | 3 collective Campaigns | 4 |
| Parcel | Black market | 3 of: private Campaigns, stamped plot cards, Model plot cards | 4 |

## Cadres (24)

Hand types still form by printed rank under every rank Cadre. Only what beats what changes. A collective Cadre applies to everyone at the table; a private one applies to you.

Built already: Cultural Revolution, Promotion of the Masses, Iron Rice Bowl, Stakhanovite, Hidden Reserves, Landlord's Ledger, Planned Allocation, The Informant, Peek, Red Ink.

Two of those change:

- **Stakhanovite grows.** Each Straight of 7 or more cards you play adds 0.05 to its Zeal per card, for the run.
- **Red Ink returns** to the black market, now that cards can be stamped.

The Plan's remaining six:

| Cadre | Tag | Effect | Cost |
| --- | --- | --- | --- |
| Rehabilitation | Private | You pick a rank when you buy it. Your cards of that rank beat one more rank for each Year since. It stops below the jokers. | 6 |
| Class Label | Private | While you are landlord, your stamped cards rank above 2s and below the jokers. | 5 |
| Collective Farm | Collective | A peasant's Pair also scores the Grain of their teammate's last play this round. | 5 |
| Show Trial | Private | Your Bombs and Rockets score double Zeal. Each one adds 3 Resentment. | 6 |
| Model Commune | Collective | When the peasants win and your teammate went out first, the round's Commons is multiplied by 1.5. | 5 |
| Ration Coupon | Collective | Every 4th time you pass in a Quota, you earn 1 coupon, up to 3 a Quota. | 4 |

Eight new ones, so that each way of playing has something to build on:

| Cadre | Tag | Effect | Builds toward | Cost |
| --- | --- | --- | --- | --- |
| Shock Brigade | Collective | Straights may be 4 cards long. | Straights | 5 |
| Canteen | Collective | Every Trio hand gains 0.5 Zeal. | Trios | 4 |
| Red Banner | Collective | Each heart and diamond scores 2 more Grain. | Suits | 4 |
| Poor Peasants' Association | Collective | Cards ranked 3 to 7 score double Grain. | Low cards | 5 |
| Seed Grain | Collective | Every play scores 3 more Grain for each Quota met while it is held. | Scaling | 6 |
| The Bookkeeper | Private | At a Quota's end, earn 1 coupon for every 5 you hold, up to 3. | Coupons | 4 |
| Last Sheaf | Private | The play that empties your hand scores triple Zeal. | Going out | 5 |
| Steel Target | Private | Each Bomb or Rocket you play adds 0.1 Zeal to all your plays, for the run. Each adds 2 Resentment. | Scaling, bombs | 6 |

Planned Allocation gets the same rank picker as Rehabilitation. It is fixed at 2s today, and the Plan gives it a chosen rank.

## Campaigns (8)

One use each. A Campaign is used on your turn, or at the moment its text names. A peasant has no turn before the landlord's first play, so when a peasant holds Mutual Aid or Appeal the round pauses once before that play, until the player uses one or plays on.

| Campaign | Tag | Effect | Cost |
| --- | --- | --- | --- |
| Model Harvest | Collective | Mark up to 2 cards in your hand as Model. | 3 |
| Mutual Aid | Collective | As a peasant, before the first play: you and your teammate each pass the other 2 cards. The bot chooses its own. | 3 |
| Overfulfillment | Collective | As landlord, after you take the kitty: win the round and your total doubles, lose it and you bank nothing. | 4 |
| Appeal | Collective | Before the first play: this round's debuff is lifted. | 4 |
| Grain Loan | Collective | Gain 5 coupons. Famine rises 3. | 2 |
| Registration Drive | Private | Stamp up to 3 cards in your hand as yours. | 3 |
| Seizure Notice | Private | Take the highest card from the opponent holding the most cards, and give them your lowest. Adds 4 Resentment. Both hands must hold 2 or more cards. | 4 |
| Anonymous Letter | Private | The next player must pass. Adds 2 Resentment. | 3 |

## Directives (6)

Each raises a family of hand types by one level. Together they cover all 14 types.

| Directive | Raises | Cost |
| --- | --- | --- |
| On Hand Tools | Single, Pair | 3 |
| On Work Teams | Trio, Trio with a Single, Trio with a Pair | 3 |
| On Deep Ploughing | Straight | 3 |
| On Close Planting | Pair Run | 3 |
| On Combined Brigades | Airplane and both Airplanes with wings | 4 |
| On Launching Satellites | Four with two (both kinds), Bomb, Rocket | 5 |

Three names use real Great Leap terms: deep ploughing and close planting were farming methods the state promoted, and in farm reports "launching a satellite" meant announcing a record yield, often an inflated one. They are names only, with no quoted slogan. The P5.5 sensitivity read covers them.

## Reforms (6)

| Reform | Effect | Cost |
| --- | --- | --- |
| Supply Cooperative | The state store shows one more item on every visit. | 8 |
| Work-Point Reform | Every Quota you meet pays 1 more coupon. | 8 |
| Enlarged Committee | You can hold one more Cadre (6, up from 5). | 10 |
| Grain Reserve | A missed Quota adds 3 less Famine. | 8 |
| Courier's Bag | You can hold one more Campaign (3, up from 2). | 6 |
| Unplanned Economy | The deck is no longer shuffled between rounds. Cards are gathered in the order they were played and cut, which should deal more bombs to everyone. | 8 |

## Unlocks between runs

Every item carries an unlock tier in its data. A tier opens after that many finished runs, won or lost. P4.14 stores the count and applies the filter; until then everything is open, so it can all be playtested.

| Tier | Opens | Cadres | Other |
| --- | --- | --- | --- |
| 0 | First run | Iron Rice Bowl, Promotion of the Masses, Collective Farm, Ration Coupon, Canteen, Red Banner, Stakhanovite, Hidden Reserves, Peek, Landlord's Ledger, The Bookkeeper | All Directives and envelopes; Model Harvest, Mutual Aid, Grain Loan, Anonymous Letter; Supply Cooperative, Work-Point Reform |
| 1 | 1 run | Cultural Revolution, Model Commune, Shock Brigade, Show Trial, The Informant, Last Sheaf | Overfulfillment, Appeal; Enlarged Committee, Grain Reserve |
| 2 | 2 runs | Poor Peasants' Association, Seed Grain, Planned Allocation, Red Ink, Class Label | Registration Drive (stamps arrive as a mechanic); Courier's Bag |
| 3 | 3 runs | Rehabilitation, Steel Target | Seizure Notice; Unplanned Economy |

The strongest scaling pieces sit in the late tiers, so a veteran's runs can reach further than a first run, by a little.

## Left for later items

- **A second content wave**, P4.20, comes before release. v1 is a complete game meant to last many runs, and 24 Cadres is the first wave, not the release set. The second wave grows it to about 40 Cadres and 12 Campaigns once the balance harness (P4.16) can tune them.
- **Wild ranks** get their own item, P4.18. Model Worker, Mass Line and Industrialization all need a wild card to stand in for another, which means new rules for classifying hands, generating moves and all four bot tiers. It unlocks as a new mechanic between runs.
- **Households** are the starter decks, in P4.14: the family background you pick at the start of a run sets what you begin with, such as a stocked plot, coupons, or a Cadre that comes with Resentment.
- **Card designs** unlock with households and corruption stages, in P4.14.
- **Self-Criticism** (play with your hand shown) waits until the bots can use what they see. **Surplus Quota** (a Trio carrying a Trio) needs a new hand type.
- **Whole-hand swaps** are out. A landlord holds 20 cards against 17, so only Mutual Aid's small trade keeps hand sizes.

## Consequences

- `RunState` gains the norm steps, marks per deck card, hand levels, per-Cadre state (Rehabilitation's rank and Year, Stakhanovite's growth, Steel Target's count, Seed Grain's count), Reforms held, and the last round's play order. Run saves go to schema 6.
- New engine pieces: using a Campaign as a command that saves and replays, envelopes, a Reform slot in the state store, a pass counter, the rank picker, and the audit die.
- The bots do not use Campaigns. They must stay legal when Seizure Notice, Anonymous Letter, Mutual Aid, Appeal or a 4-card Straight happens to them.
- Every item ships with a golden test and its string keys. New art: 14 Cadres, plus Planned Allocation, The Informant, Peek and Red Ink, which have none. Campaigns, Directives, Reforms and envelopes get one frame each, with the name set in type.
- Build order: the audit die and overfulfilment first, then marks and saved levels, Directives, Campaigns, the 14 Cadres, Reforms, envelopes.
