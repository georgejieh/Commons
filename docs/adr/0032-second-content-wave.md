# ADR 0032: The second content wave (P4.20)

- Status: Accepted, 2026-11-17, by the agent under the design authority ADR 0021 records. The owner judges by playtest. Every number here is a starting value in data, to be tuned with the balance harness (ADR 0027).
- Fact check: the historical notes under "Names" and the claims about earlier records were checked on 2026-11-17 by GPT-6.1-Sol, a second model family; all were confirmed, and four notes were made more exact from its sources.
- Scope: 16 Cadres, 3 Campaigns and 2 households added to the first wave of ADR 0021, the unlock tiers they sit in, and what the wave has to do for the collective path.

## Why this needs a decision

ADR 0021 left a second wave for P4.20: v1 is a complete game meant to last many runs, and 24 Cadres is the first wave, not the release set. The checklist asks for about 40 Cadres and 12 Campaigns, more households, and the balance targets of P4.16 still holding.

Two things shaped the choices.

**Each way of playing needs a second piece.** The first wave gave most builds one Cadre: Straights have two, Trios, suits and low cards one each, and Pair Runs, Airplanes, high cards, Singles and Model cards none. A build made of one Cadre and a Directive is thin.

**The collective path has nothing that lowers a meter.** The nightly balance run of 2026-11-16 (549 seeds a strategy) had 7 collective runs survive the eighth Year, all as The Lean Years with Famine near its limit, and no run of any strategy reached The Commons. The Commons needs a peasant's run that ends with Famine and Denunciation below their middle band and Resentment at 10 or less (ADR 0024). Famine only ever rises: 10 for a missed Quota, 3 for a Commons shortfall, and 1 a step, up to four steps, for leaving the seat to others three Quotas running (ADR 0031). Resentment has no way down either, and the mixed runs that survive end with a median of 24. So the ending that resets corruption (ADR 0018) is not rare, it is out of reach. The wave gives the collective path its own tools: relief for Famine earned at the table as a peasant, and a way to bring Resentment down that costs something.

The targets stay what they were: mixed above private above collective above zero at the base stake. The collective tools are meant to make The Commons possible for a player who builds for it, not to make standing by a winning plan.

## Cadres (16, for 40 in all)

A collective Cadre is sold at the state store and applies to every seat where its text is about plays. A private one is sold at the black market at 150% and applies to you.

| Cadre | Tag | Effect | Builds toward | Cost | Tier |
| --- | --- | --- | --- | --- | --- |
| Night School | Collective | Singles and Pairs gain 0.5 Zeal. | Small plays | 4 | 1 |
| Iron and Coal | Collective | Each spade and club scores 2 more Grain. | Suits | 4 | 1 |
| Advanced Cooperative | Collective | Cards ranked J to A score 4 more Grain. | High cards | 5 | 2 |
| Double-Share Plough | Collective | Pair Runs may be 2 pairs long. | Pair Runs | 5 | 2 |
| Open Accounts | Collective | Each round you declare no more than your need, Resentment falls 1. | The collective path | 4 | 2 |
| Tractor Station | Collective | Every Airplane, with or without wings, gains 1 Zeal. | Airplanes | 5 | 3 |
| The Gleaners | Collective | When the peasants win a round, its Commons gains 5% for each card left in the landlord's hand. | The Commons | 5 | 3 |
| Public Granary | Collective | Each round the peasants win with you among them, Famine falls 1. | The collective path | 6 | 4 |
| Five-Year Plan | Collective | Every play gains 0.1 Zeal for each Year of the run so far. | Scaling | 6 | 4 |
| Back Door | Private | The first reroll of each black market visit is free. | Coupons | 4 | 1 |
| Informer's Reward | Private | When an audit catches a villager's lie, you earn 2 coupons. | Coupons, audits | 4 | 2 |
| Forged Seal | Private | Your stamped cards add no Resentment when they score. | Stamps | 5 | 3 |
| Loudspeaker | Private | Your 2s and jokers played as Singles gain 2 Zeal. | Control | 5 | 3 |
| Rent Book | Private | Each round you win as landlord adds 0.2 Zeal to your plays as landlord, for the run. Each adds 2 Resentment. | Scaling, the seat | 6 | 4 |
| Grain Speculator | Private | Each step of overfulfilment pays 2 coupons, not 1, and adds 1 more Resentment. | Coupons, the norm | 5 | 5 |
| Prize Exhibit | Private | Model cards score triple Grain, not double, when you score them. | Model cards | 5 | 5 |

Notes on the rules:

- **Double-Share Plough** lowers the shortest Pair Run from 3 pairs to 2 for every seat, as Shock Brigade does for Straights. Four cards of two neighbouring ranks were no hand before, so nothing that was legal changes its reading.
- **Public Granary and Open Accounts** are the first effects that lower a meter or Resentment. Both stop at 0. A meter that falls back below a band re-arms that band's setback by the margin the meter table already has.
- **Open Accounts** counts a round in which the player declared, as a peasant, a need no higher than their true need. A round as landlord declares nothing and counts for nothing.
- **Five-Year Plan** counts the Year in play: 0.1 in Year 1, 0.8 in Year 8. It applies to every seat, so the landlord across the table gains it too.
- **Rent Book** grows like Steel Target: the count is the Cadre's own memo, saved with it, and is lost if the Cadre is.
- **Grain Speculator** leaves the norm's own rise as it is: 3% a step.
- Where an effect here cannot be built on the hooks as described, the build may change the mechanism and keep the intent, and says so in this ADR.

## Campaigns (3, for 12 in all)

| Campaign | Tag | Sold at | Effect | Cost | Tier |
| --- | --- | --- | --- | --- | --- |
| Self-Criticism | Collective | State store | Resentment falls 6. Denunciation rises 2. Use on your turn, or in either shop. | 3 | 1 |
| Relief Grain | Collective | State store | Famine falls 6. Use on your turn, or in either shop. | 4 | 2 |
| False Report | Private | Black market | This Quota's progress rises by 15% of its target. The norm rises one step, and Resentment 2. Use on your turn. | 4 | 3 |

- **Relief Grain** mirrors Grain Loan, which sells Famine for coupons. Neither can be bought more often than the counter stocks it.
- **False Report** is the inflated figure inside the rules: the same ratchet as beating a Quota, taken on purpose. It is a Campaign like any other and has nothing to do with ADR 0022's file, which answers figures changed from outside the game.

## Households (2, for 6 in all)

| Household | Tier | Starts with, beyond the 4 coupons | Cost |
| --- | --- | --- | --- |
| Mutual Aid Team | 2 | Open Accounts | Famine starts at 10 |
| Returned Soldier | 4 | Loudspeaker, and 2 coupons | Denunciation starts at 10 |

A household is still only a starting position (ADR 0025): a Cadre in the first slot and a price on a meter.

## Unlock tiers

The wave adds a sixth tier, 5, open after five finished runs. ADR 0021's table gains the rows above. A run outside the profile still opens tiers 0 to 3 only (ADR 0029), so the demo and the arrival meet none of the tier 4 and 5 pieces, and the pieces at tiers 1 to 3 join their pools.

Tier 0 gains nothing: a first run already has 11 Cadres to meet, and the wave is for the runs after it.

## Villagers

No family is added. The roster has 14 families and the sent-down youth, five of them joining over the first five runs and one after a landlord's ending (ADR 0025), and nothing measured says it is thin. The owner's playtest decides.

## Names

The names are period terms used as names only, with no quoted slogan, and the P5.5 sensitivity read covers them:

- The double-wheeled, double-share plough was a farm tool the state promoted in the mid-1950s.
- Advanced producers' cooperatives were the larger collectives of 1956 and 1957, before the communes, in which members' land and main tools became the cooperative's property.
- Tractor stations hired machinery out to cooperatives under contract, on the Soviet pattern. China had 383 by the end of 1957, so most villages never saw one.
- Gleaning is gathering what a harvest leaves in the field.
- Self-criticism was a routine of political meetings, and often not a voluntary one.
- "Going through the back door" is the common phrase for getting something through connections, with the sense that the access is improper.

## Art

Each new Cadre needs its two pictures, the innocent one for stage 0 and the last stage's, made and logged the way P4.11's were (`art/STYLE.md`, `art/sources/manifest.csv`). Campaigns are drawn in code. Cadre pictures are already loaded on demand with a small cache (`ArtLibrary.picture_cache`), so the pool's size does not raise the table's texture memory.

## Consequences

- Sixteen effect scripts, three Campaign effects and two household Resources, each with a golden test and its strings, and the content validation test over the larger pools.
- The balance harness's strategies meet the new pieces in their shops. Its drivers must be able to use the two new collective Campaigns, or the collective path's tools go unmeasured.
- A meter and Resentment can now fall. The meter bands' re-arming, the dread on the board and every screen that shows them must follow a fall as they follow a rise.
- The tiers grow to six, and the collection shows the new pieces locked until their tier.
- The run save does not change shape unless a Cadre's memo needs a new key; if it does, the schema moves with a migration.
- After tuning, the nightly run's report is the evidence: the order holds with intervals that do not overlap, and whether any run reaches The Commons is recorded either way.

## Measured (2026-11-17)

No number in the wave was changed after it was built. The nightly workflow's run 44112976684 played 729 seeds a strategy on the wave's rules and data (commit e2c02e0), and its check passed: the order of [ADR 0027](0027-balance-harness.md) holds with intervals that do not overlap.

| Survived the eighth Year | Collective | Private | Mixed |
| --- | ---: | ---: | ---: |
| Before the wave, 549 seeds | 1.3% (0.7% to 2.3%) | 20.0% (17.4% to 23.0%) | 39.9% (36.5% to 43.4%) |
| After the wave, 729 seeds | 2.1% (1.4% to 3.1%) | 17.8% (15.6% to 20.3%) | 33.5% (30.7% to 36.4%) |

- **The Commons is reached.** 22 of the 729 mixed runs (3.0%) ended there, with a mean Famine of 36 and a mean Resentment of 3. No run of any strategy had reached it in the 549 seeds before the wave. No collective or private run reached it.
- **Resentment is the last bar.** 59 mixed runs ended as a peasant with both meters under 50. The 22 at 10 Resentment or less got The Commons; the other 37 stood between 13 and 42 and got The Secret Contract. The simulated players use a Self-Criticism as soon as they hold one and never keep one for the end, as a player after this ending would.
- **Collective alone still dies of Famine** (97.9% of its runs, at a mean Year of 4.9). That is [ADR 0031](0031-the-unheld-seat.md) working as meant: The Commons comes from taking the seat when it is offered and living collectively otherwise, not from refusing it every time.
- **Mixed survives less often than before the wave,** 33.5% against 39.9%. The two intervals meet at their ends, so the fall is likely real: the larger pool offers the Cadres a build needs less often. It is still well clear of private. Left for the owner's playtest and the next balance pass.
- A harness rule that had collective and mixed buy a Self-Criticism before a Cadre while Resentment stood above 10 was tried on 48 seeds and changed nothing, since the store offers one Campaign a visit. It was not kept.
- The fixes of the Phase 4B review came after this run. Two of them touch play: a confiscated Cadre is held again at its round's end, and the bots' hand memo tells two wild ranks apart. Neither moves a number in data.

## As built (first part, 2026-11-17)

Every item does what its row says. Where the hooks could not carry it as described, the mechanism changed and the intent did not:

- **A new hook, `need_settled`,** runs after the Commons is split and audited. Nothing before it told an effect what the player declared or whom the audit caught. Open Accounts and Informer's Reward use it. "No more than your need" reads on screen as no more than your fair half of the Commons, which is what a need is in this game.
- **Public Granary's fall is taken before the round is scored,** so a Quota's report still counts only its own rises.
- **The Gleaners' gain multiplies the Commons** whenever the peasants win, whoever holds the Cadre, and stacks with Model Commune.
- **Loudspeaker reads printed ranks:** a wild card standing in as a 2 does not count.
- **Rent Book counts the play that empties the landlord's hand,** and keeps its count in its memo.
- **Grain Speculator** pays 1 more coupon and adds 1 more Resentment a step; the norm's own 3% a step is untouched.
- **Back Door** is read when the black market opens and again after a Cadre is bought, so it works on the visit it is bought in if no reroll was made yet.
- **False Report raises the norm for later Quotas only,** as beating a Quota does. That needs a number in the run save, `reported_steps`, so run saves are schema 18 with a migration that adds 0. The consequence above that the save would not change shape did not hold.
- **Prize Exhibit and Poor Peasants' Association:** a low Model card scores its printed Grain three times by Prize Exhibit, and the Association's doubling still works from Model's double, not the triple. Left as it is until a playtest says otherwise.
- **Rarity follows cost** (4 common, 5 uncommon, 6 rare), as in the first wave.
