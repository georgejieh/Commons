# ADR 0043: The Handicap, honesty that falls with Famine, and the Tally Clerk

- Status: Accepted, 2026-11-25. The lead's direction for P5.2c, from the Plan's rows that no checklist item had built; the Handicap's face-up set-aside is the lead's ruling, and the names, numbers and details below are the agent's. The owner judges by playtest. Every number here is a starting value in data, to be tuned with the balance harness ([ADR 0027](0027-balance-harness.md)).
- Scope: a fifth official boss, a family trait that changes with a run meter and Qin's use of it, a private information Cadre, and what each adds to the table, the dossier, the save and the content stamp.

## Why this needs a decision

The Plan names three things nothing built:

- In its variant table, a boss from the two-player handicap rule: "you start each deal down N cards", The Handicap.
- In its villager table, Qin, the Survivor: "Defensive; turns dishonest when Famine is high". P4.5 seated Qin with a fixed honesty and left the condition "for later items"; none took it.
- In its deck-asymmetry table, under the deal: "see the kitty before bidding", a private upgrade beside The Informant and Peek.

Each touches a rule that later ADRs settled: the deck is a keyed structure every seat counts against ([ADR 0042](0042-deck-exchange.md)), a card out of the round is out of it for every seat that knows of it ([ADR 0038](0038-plot-swaps-last-one-round.md)), boss twists bind whoever they bind and whatever the player buys acts for the player's seat alone ([ADR 0039](0039-cadres-work-for-the-household.md)), and the owner wants villager traits open to mechanics an expansion has not thought of yet.

## The Handicap

**The rule.** "Each round, before the bid, cards drawn at random from your hand are set aside face up until it ends: {cards} this Year." It is a boss twist (`data/modifiers/bosses/the_handicap.tres`, `HandicapEffect`), an official in `data/run/boss_pool.tres` beside the other four, so it binds the player's seat, which holds every boss twist.

**How many.** `cards` 1 and `years_per_card` 3: the count is `cards + (Year - 1) / years_per_card`, so 1 card in Years 1 to 3, 2 in Years 4 to 6 and 3 in Year 7. Year 8's boss is always the New Landlord. The rules text fills in the count for the Year in play.

**Which cards.** The deal is made as always, 17 cards a seat and a kitty of 3. Then the `on_deal` hook draws the cards on the deal stream from the player's dealt hand, taken in card-ID order so the draw never depends on how the hand happens to be held. Any card may be drawn, a joker included, which can leave the round with no Rocket. The player never chooses. The hook runs after every other deal effect, since the boss joins the stack last, so Planned Allocation's bias has already acted on a full hand. A redeal deals again and draws again.

**Where they go.** Out of the round, as a card a plot swap sets aside is: `DealResult.set_aside` holds them, no hand holds them, and they are dealt with the next round's fresh deck. The kitty stays three cards, so the player is landlord with 20 less the count, or a peasant with 17 less it. Under Unplanned Economy, `DeckOrder.gather` already puts a deck card the round lacked at the end of the order. Marks stay with the slot in `CardMarks`, so a marked card set aside comes back marked.

**Who knows.** The cards are set aside face up in front of every seat, so every seat's count of the round drops them: the hook takes them off `DealResult.deck_counts`, the count `RoundState` hands every `SeatView` and `UnseenCards` counts against. No bot counts a set-aside card as unseen, the Expert's sampled worlds never deal one, and the hint counts as the bots do. This is ADR 0042's one rule, a seat counts against what it knows the round holds, with every seat knowing.

**At the table.** The run logs `CARDS_SET_ASIDE` after the deal, the player's seat and the cards' IDs. The table lifts the cards out of the player's hand, lays them face up in the middle under a stamped "Set aside" and a note naming them ("The Handicap: K of Spades set aside for the round."), holds a moment, and sweeps them off the table (`DealMoments`). With reduced motion, a replay or a skip there is no beat. The rules slip names the boss for the whole Set, and while the round holds cards it set aside, its line names them, so the fact is in view in every form of the slip and with motion off.

**The slip names every boss.** Until now no boss twist was on the rules slip or the Rules sheet, only on the Set intro. A boss twist is a rule in force for the whole Set, so both now list it, under its own head, after the round's debuffs: a boss is not a debuff and Appeal does not lift it. The slip's named and counted forms count it with the rest, and the table's worst case grows by the boss whose line stands tallest.

## Honesty that falls with Famine

**The trait.** A family definition may carry trait shifts (`FamilyDef.shifts`, each a `TraitShift`): while a run meter stands in a band or above it, one of the five personality traits takes a level in place of the family's own. A shift names the meter, the band, the trait and the level, and the dossier line that reports it (`seen_key`, with `{count}` and the band's least value as `{at}`). It is data, so an expansion's family takes any of the five traits against either meter with no new code. While a shift holds, the shifted level replaces the trait as drift has left it; once the meter falls below the band, the drifted level is back. Two shifts of one trait that both hold: the later one in the list wins.

**Qin's.** Famine at its high band (75, `data/run/meters.tres`) or above: honesty Low. Qin's own honesty is Mid (honesty 0.7, a lie adding half the true need); Low is honesty 0.3 and a lie adding the whole need (`data/bots/personality_table.tres`), so above the band Qin claims double the fair half seven times in ten.

**When it is read.** `RunLoop` applies the seated families' shifts at each round's start, for traits that act in play, and again just before the claims on the Commons, so a claim reads Famine as it stands when it is made: a Relief Grain used during the round counts. Only families with shifts are touched, so Deng's mirror and every other family's config are as they were. A run with no roster seats no family and shifts nothing.

**The dossier.** A claim above the fair half, made while one of the family's honesty shifts holds, is something the player saw: every claim is shown on the audit slip. The run counts them (`Observations.Kind.SHIFTED_CLAIMS`), and once the count is above zero the family's dossier shows the shift's line. For Qin: "Claimed more than a fair half with Famine at {at} or more: {count}", the band's least value filled in from the meter table. Nothing says so before it has happened, so the trait stays hidden until it shows.

**Saves.** The count is a new column of the saved observations, so run saves are schema 20: `RunRecord.migrate_from_19` pads every family's row with a zero.

## The Tally Clerk

**The rule.** "Shows you the kitty while the landlord seat is bid for." A private Cadre (`data/modifiers/the_tally_clerk.tres`), an information upgrade exactly as The Informant and Peek are: `InfoMarkerEffect`, no hooks, its `info` parameter turning on a flag, `InfoView.KITTY` (4). It changes nothing in play, so it has no seat to act for beyond the player's view.

**Numbers.** Sold at the black market (`data/run/market_pool.tres`), cost 5 under the black market's `price_percent` (120, `data/run/black_market.tres`) and rarity 1, as Peek; unlock tier 0, so a first run can meet it. Buying it adds the Resentment every black-market purchase adds (`private_purchase`, `data/run/resentment.tres`, through `RunLoop._market_bought`).

**What it shows.** `InfoReveal.bid_info` fills an `InfoView` with the deal's kitty when the player holds the flag; `RunLoop.bid_info()` returns it while the seat is bid for and null otherwise. The run logs `KITTY_SEEN` with the kitty's IDs after the deal, and after a redeal for the new kitty, only while the player holds the flag. The table lays the three cards face up where the kitty is revealed, under a note that only the player sees them, until the seat is chosen; the kitty's reveal then plays as always. With reduced motion, or on a replay, they are laid there still.

**The bots.** No bot's input changes: a bot bids from its own hand and the seat rules, and plays from its `SeatView`, and neither carries an `InfoView`. `tests/integration/test_tally_clerk.gd` plays seeded rounds with the Cadre and without it and holds that every villager's bid and play is the same, and that no refused bot action happens.

**Art.** The Tally Clerk has no picture. It shows the empty frame every Cadre without art shows (`ArtFrame`, `ScreenKit.ART.has_cadre`), on the shelf, the board and the collection. Its two pictures are left for the owner's art pass.

## The content stamp

The boss officials join `ContentStamp.drawn()`. A boss is drawn by its place in the pool, and the Handicap's numbers change every deal of its Set, so a save made under other bosses resumes at its Quota's start (ADR 0033). The Tally Clerk is in the black market's pool, which the stamp already reads. Family definitions are not drawn by slot, and a claim that differs on replay changes no command, so the families stay out of the stamp.

## Consequences

- A fifth official makes each one rarer: the Handicap meets a run about as often as each of the other four.
- The bots count right under the Handicap with no change of their own: the deal's count is already what they read.
- The black market's pool grows to 21 Cadres, so every run's shelves draw differently from the first visit, and the balance harness's numbers move with it.
- Qin above Famine 75 claims more and is caught more often. A caught lie adds to Qin's own Denunciation (P4.3), so a hungry village sends Qin to reeducation sooner.
- `tests/unit/test_handicap.gd`, `tests/integration/test_handicap_round.gd`, `tests/unit/test_trait_shifts.gd`, `tests/integration/test_hungry_claims.gd` and `tests/integration/test_tally_clerk.gd` hold the three, with golden values, and a bounded self-play for each where the bots are involved.
