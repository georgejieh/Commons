# ADR 0027: The balance harness and its three players (P4.16)

- Status: Accepted, 2026-11-15, by the agent under the design authority ADR 0021 records.
- Scope: what the harness plays, how its three strategies decide, what it reports, and how the checklist's target is read. Tuning the game's numbers against the report is done under this ADR and recorded in the checklist, not here.

## Why this needs a decision

The checklist asks for a headless simulator with a bot-controlled player following three named strategies, and for mixed to win more often than private, private more often than collective, and collective more than never. It does not say what the strategies do. A run has many decisions besides card play: whether to take the seat, what need to claim, what to buy in two shops, when to use a Campaign, what to keep from an envelope, what to swap from the plot. The ordering only means something if those are written down.

## What it plays

A full run through the same start path the game uses, with no window and no profile: eight Years, the village roster, base stake, Poor Peasants, every unlock tier open (so the whole content set is measured), starvation and every rule of a real run. The player's cards are played by the Hard bot in all three strategies, so the strategies differ only in the choices below.

## The three strategies

| Choice | Collective | Private | Mixed |
| --- | --- | --- | --- |
| The landlord seat | Never calls or grabs | Calls whenever the bot would, and grabs a held seat whenever the bot would call | Calls when the bot would; never grabs a held seat |
| Need | Claims the true need | Claims the most the panel allows | Claims the true need, or 50% more while one face of the die audits |
| State store | Each visit: first the cheapest Directive it can afford, once; then, while coupons last, the dearest Cadre, else a Reform, else an envelope, else a Campaign | Each visit: the cheapest Directive it can afford, once, and nothing else | The cheapest Directive it can afford, once, from everything it holds; then as collective, keeping back the coupons its data says (none since the third measurement) |
| Black market | Never enters | Buys the dearest Cadre it can afford, then a Parcel, then a plot card, then plot upgrades | Buys one thing a visit, the dearest it can afford with what was kept back, while Resentment is under 40 |
| Deck stall and the state store's desk (amendment below) | Last at the store, after a Campaign: the dearest card it affords that ranks above the deck's weakest card, then the desk's mark | Never | As collective |
| The black market's desk (amendment below) | Never | Its stamp, after a Cadre and before a Parcel | Within its one thing a visit |
| Rerolls | Never | Once a visit if nothing was affordable | Never |
| Envelopes | Keeps the first item it can take | The same | The same |
| Campaigns | Uses each as soon as its rule allows, except Anonymous Letter and Seizure Notice, which it never uses | Uses each as soon as its rule allows | As collective |
| Plot swap | None | Swaps its lowest hand cards for its highest plot cards, as many as allowed | The same as private |
| Cadre that needs a rank | The rank it holds most of | The same | The same |

"The bot would" is the Hard bot's own bidding decision for that hand. Each rule is data where it has a number (the coupons kept back, the Resentment limit, the over-claim).

The first version of this table left Directives out, and no strategy's score grew: Directives are how a hand type's Rate rises, and every real player buys them. All three now buy one a visit. Private still buys nothing else the state sells. The second measurement showed mixed holding its 4 coupons back from the Directive too: with a Quota paying 3 to 5 coupons it almost never had the 7 a Directive then took, and its hand levels stood still (a sum of 15 at the start, 20 by the fifth Year, against collective's 38). The coupons kept back are for the black market, so they now come out of what is left after the Directive.

The third measurement set the reserve itself to none. Kept back, about a third of mixed's coupons went to the black market, where everything costs half as much again and several Cadres only show information a bot cannot use. Mixed then held fewer Cadres than collective through the middle Years and survived less often. With nothing kept back it buys at the market only what the store left it coupons for. The number stays in data.

These are caricatures on purpose. Collective is the player who trusts the village, private the one who takes everything, mixed the one who takes what is cheap and stops before it costs. The game's thesis is that the middle path is the only one that lasts, so the harness measures exactly that.

## What it reports

For each strategy over the same list of seeds: the share of runs that survive the eighth Year, each ending's share, deaths by meter and the Year they came in, the mean Year reached, the share of Quotas met, mean coupons at the end, mean final Famine, Denunciation and Resentment, and the count of villagers who starved. It also reports, for each strategy and each Quota of the run in order, how many runs reached it, the share that met it, and the median score against the target, because the first measurement showed the target curve itself was the question. One CSV row per run and one summary in Markdown, in `reports/`. Any illegal action, refused command or script error fails the run, not just the report.

## Amendment, 2026-11-25: the deck's goods

The design lead's ruling, for the goods the shops gained after this ADR: the state store's deck stall ([ADR 0042](0042-deck-exchange.md)) and a marking desk in each shop ([ADR 0041](0041-marks-on-deck-cards.md)). Until now the harness never bought them, so its numbers said nothing about them.

- **What is whose.** The deck stall and the state store's desk are collective goods: they change the deck every seat is dealt from, and an enhancement scores for whoever plays the card. The black market's desk is a private good: its stamp scores for the player alone, and the game charges it a private purchase's Resentment (`private_purchase`, 3), as it does every purchase there.
- **Who buys.** Collective buys from the deck stall and then the state store's desk, after everything else it buys there. Private buys the black market's stamp, in its market order after a Cadre. Mixed buys both under its existing limits: the state store's goods in collective's order from what it does not keep back, the stamp only as its one black market purchase of the visit and only under the Resentment limit.
- **Which card comes in.** Only a stall card that ranks above the deck's weakest card in the plain order is offered to a strategy; of those, the dearest the budget affords, the first on the shelf on a tie. It goes in place of the deck's weakest card: the first slot of the lowest rank the deck holds, the card the Requisition envelope's keep replaces too.
- **Which card a desk marks.** The highest-ranked deck card in the plain order that carries no mark of the desk's kind (no enhancement at the state store, no stamp at the black market), the lowest slot on a tie. The desks refuse no joker, so a joker comes first; a use never replaces an enhancement.
- **Deterministic.** None of this draws: the same seed plays the same run.
- **Reported.** Their coupons are spent rows of their own in the report (deck stall cards, and desk marks at either counter, which the black market row no longer counts), and the runs CSV gains `deck_spent` and `marks_spent`, the coupons a run spent on each, with a mean of each in the summary.

## How the target is read

"Mixed > private > collective > 0" is judged on survival of the eighth Year, and holds only when each gap is larger than the sampling error: the lower end of one strategy's 90% interval must clear the upper end of the next. The report always says how many seeds it stands on.

The nightly workflow runs it in a job of its own for five hours, with Expert villagers sampling 12 deals, and fails when the ordering does not hold. This ADR first asked for at least 300 seeds a strategy; a hosted runner does not finish that many in the six hours a job may take, so the nightly takes as many as its budget gives. At the levels measured on 2026-11-16 (mixed 51%, private 21%, collective 7%) the narrowest gap, private over collective, needs about 150 seeds to hold on most nights, and at 61 seeds it held by a fraction of a point.

## Tuning

When the ordering does not hold, the numbers move, not the strategies. The order of reach: Quota targets and their growth, the meter sources (what a missed Quota, a caught lie, and Resentment cost), shop prices and rewards, then single items that dominate. Each measured set of changes is recorded with its before and after rows, in the message of the commit it lands in.

Ten measurements in, the numbers alone had not given the order: targets, rewards and prices moved all three strategies together, and collective stayed above private. The order came from one new rule, a Famine cost for Quotas in a row without the landlord's seat ([ADR 0031](0031-the-unheld-seat.md)), with the numbers tuned around it. The measurements are in `docs/CHECKLIST.md` under P4.16.

## Consequences

- The harness needs a way to play a run with no profile and every tier open, which the start path gets as an explicit option.
- A run is about 24 Quotas of Hard-bot play, so the nightly run is sized by time: the harness takes a time budget and reports how many seeds it finished. Villagers at the Expert tier search with no deadline here (ADR 0030), which is slow, so the harness may lower how many deals they sample and says so in its report.
- The strategies are code in `tools/`, never in the game: no shipped build can play itself.
