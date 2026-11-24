# ADR 0038: Plot swaps last one round

- Status: Accepted, 2026-11-24. The owner's direction from their playtest of 2026-11-24; the lead chose the option. Supersedes the card-identity choice of [ADR 0014](0014-plot-card-identity.md) and keeps its kitty rule.
- Scope: what a private-plot swap does to the plot, the hand and the deck, and everything that assumed ADR 0014's answer.

## Context

ADR 0014 made a swap permanent: the deck card swapped out of the hand was reissued as a plot card, and the plot card swapped in was gone once its round was over. The owner met that in play on 2026-11-24 and read it as a bug: "if you swap out cards, the private plot doesnt return to your plot for next Quota and the card in your private plot is what you swapped out". They expect the plot to be their own standing bench of cards, which is what the Plan calls it: a personal pile outside the shared deck, where the deckbuilding happens. Under ADR 0014 a good plot card bought at the black market could be lost for a 3 the deal happened to give.

## Options

1. **Keep ADR 0014.** The plot changes with every swap. Rejected: the owner reads it as broken, and it makes buying plot cards a gamble on keeping them.
2. **Swaps last one round** (ADR 0014's option 3). The plot card comes into the hand for the round and is back in the plot when the round is over, played or not. The deck card it replaced sits the round out and is dealt with the next round's fresh deck.
3. **Swaps last one round, but a played plot card is spent.** Rejected: it brings back the loss the owner objected to, for the cards they most want to play.

## Choice

**Option 2.** The plot itself is never changed by a swap.

- **The swap.** `PlotSwap.apply` puts a copy of each chosen plot card into the hand, under the plot card's own ID (1000 and up) and with its marks, through `RoundState.exchange`. The hand card it replaces is dropped from the round. Nothing is reissued, so `CardInstance.reissued` and `CardMarks.forget` are gone.
- **Kitty.** ADR 0014's kitty rule stands: the swap runs after the landlord takes the kitty, and a kitty card may be swapped out. A kitty card swapped out also leaves the public kitty, as a card moved by `RoundState.trade` already does, so no seat is told the landlord still holds it.
- **Identity.** An ID still names one physical card for the whole run. A plot card in the hand is that same card for one round, not a second one: within a round every held or played ID is different, and the deck's 54 IDs never meet a plot ID. `RunState.next_plot_id` now only grows when a card is made for the plot (the black market's stall, an envelope, a household or an heirloom); a swap leaves it alone.
- **The card that sits out.** It is simply not in that round. Its saved marks stay in `CardMarks`, so it is dealt the next round with them. Under Unplanned Economy, `DeckOrder.gather` already puts any deck card the round lacked at the end of the order, and leaves plot cards out.
- **Marks made during the round.** The hand holds a copy, so nothing the round does to its own cards reaches the plot. A mark made through `CardMarks.stamp` or `CardMarks.make_model` on the copy finds the plot's card by its ID and marks it too, as it did for any copy a view held; so a plot card marked while in the hand comes home with that mark.

## What else this touches

- **Saves.** The checkpoint's shape is unchanged, so the schema stays at 18 and no migration is needed. A save made under ADR 0014 loads: deck cards it reissued into the plot are plot cards with plot IDs, and stay plot cards. A save made mid-Quota replays its commands under this rule. If a later swap in it names a card only ADR 0014 put in the plot, the replay fails and [ADR 0033](0033-saves-across-content-changes.md) resumes the run at its Quota's start.
- **Shared Kitchen** ("You may make only {swaps} private-plot swap each round") and **Plot Seized** ("You can't swap with your private plot. When this first comes into force, one card in your plot, drawn at random, is destroyed for the run") were already about the plot and the round's swaps; both stay true. Plot Seized acts at the round's start, before the swap, so the card it destroys is never in a hand.
- **Capacity and the swap upgrade.** "Your private plot holds one more card" and "Each round, you may swap one more card" stay true. The swap upgrade's tip now says the card comes back.
- **The Plan's "cards that return to the plot after scoring" upgrade** was never built. Every plot card now returns, so it is not needed.
- **Reeducation** still empties the plot ([ADR 0019](0019-reeducation-setback.md)); a swap never could have saved a card from it.
- **Player-facing text.** `tip.plot`, `market.plot.tip` and `market.upgrade.swaps.tip` say the card goes back to the plot when the round ends. The one-time tip's text is [ADR 0026](0026-tutorial.md)'s, so its table carries the new line.
- **Tests.** `tests/integration/test_private_plot.gd` checks that within every round no ID is held or played twice and the 54 deck IDs are each in play or set aside by that round's swap, that the plot is the same card for card and mark for mark through two Quotas of swaps, that the set-aside card is dealt again, that a kitty card swapped out leaves the round and the public kitty, and that a plot ADR 0014 filled still loads and swaps. `tests/integration/test_card_marks.gd` checks that a swap moves no mark either way.
