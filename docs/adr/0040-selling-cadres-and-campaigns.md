# ADR 0040: Selling Cadres and Campaigns

- Status: Accepted, 2026-11-24. The owner's direction from their playtest of 2026-11-24; the design is the lead's, the details below are the agent's.
- Scope: both shops (the state store and the black market), the run's shop logic and its save.

## Why this needs a decision

The owner, after playing: "there needs to be ways to sell Cadres and Campaigns. Its less about getting the coupon back but more about changing up your cadres for different combos." Until now a Cadre left the board only to a boss's purge or to reeducation, and a Campaign only by being used. A full board made every later Cadre on the counter read "No room" for the rest of the run, so a build could not change course.

## Decision

**Where and when.** The player may sell any Cadre they hold and any Campaign they hold, at either shop, any number of times a visit. Nothing is sold at the table: the modifier stack changes only between rounds. While an envelope is open, a sale is refused like every other shop command.

**What a sale pays.** Half the item's present price at the counter it is sold to, rounded down, and never less than one coupon. The present price is the one the counter would ask for that item now: its listed cost at the counter's `price_percent`, rounded up, under any raise the books made (ADR 0022). The share is data, `ShopParams.sell_percent`, 50 at both counters. Each item has its own listed cost, which its kind and rarity set, so the sale follows them. The black market pays more for the same item, as it asks more; it still pays less than either counter asks, so buying and selling never makes coupons.

**What a sale does.**
- The item leaves for good. A Cadre's saved memo and counters go with it (`CadreMemos.keep_only`), so buying the same Cadre later starts fresh, as every purchase does.
- Nothing its purchase changed is given back: the Resentment a black-market purchase added stays, and the sale itself changes no meter. A private Cadre sold no longer counts toward the Resentment that held private Cadres add at a Quota's end, because it is no longer held.
- The place it held is free at once, so a Buy button that said "No room" offers the item in the same visit.
- Neither counter offers a sold item again that visit, through any reroll (`RunShop.withheld`, `CampaignCounter.withheld`, cleared when the next visit opens). The state store sells each Cadre once a run (`stock_per_item`); a sale counts that purchase back, so the store may stock the Cadre again from the next visit.
- The household's starting Cadre sells like any other.
- A Cadre that held state the shop reads, such as Back Door's free reroll, stops giving it at once: the shop's rules are read again after a sale, as after a purchase.

**Bound Cadres.** A Cadre a debuff or boss holds at that moment cannot be sold, and the Sell ticket says so ("Held back") in the manner of a Buy button's reasons. In the code as it stands nothing holds a Cadre at the shops: Confiscation's Cadres come back at the round's end, a purge and reeducation happen away from the counter, and Short Supply cuts the counter's slots, not the board. The check reads `RunDebuffs.confiscated_ids()` so that a later twist which holds a Cadre past a round is refused rather than broken.

**Core.** `RunShop.sell` and `CampaignCounter.sell`, with their own refusals (`NOT_HELD`, `CADRE_BOUND`), behind `RunLoop.player_sell_cadre` and `player_sell_campaign`, which go through `_shop_command` like a purchase. Each logs `CADRE_SOLD` or `CAMPAIGN_SOLD` with the coupons paid. `ShopDesk.sale` tells a screen what a held item fetches at that counter now, or 0 when it cannot be sold. The controller's `sell_cadre` and `sell_campaign` are the only way in.

**The save.** A sale is a recorded command, `sell_cadre` or `sell_campaign` with the index and the counter, which a save from inside the shop replays like a purchase; the checkpoint at the next Set holds its result. No field is added to the run's state, so the schema does not change and every older save loads as before (ADR 0033).

**Interface.** The player's own Cadres are on the shop's board and their Campaigns in its tray, in both shops. Hovering a held item's paper, or giving it the focus, shows a Sell ticket over the paper's foot that names what the sale pays ("Sell · 2"), beside the slip that explains it. The first press turns the ticket to "Sell for 2?" in place; the second sells. Leaving the paper puts the ticket back, so a stray click never sells, and there is no dialog and no undo. Enter or the gamepad's accept on a focused paper presses the ticket. The board and tray sit in the bottom-left sheet, away from every Buy button. A sale counts the coupons up and swells the freed place (`UiMotion`), and reduced motion shows the result at once.

**The balance harness** does not sell (ADR 0027). Its strategies are unchanged.

## Alternatives rejected

- **A full refund.** It would make every purchase free to undo, and the owner asked for changing builds, not for coupons back.
- **One price for every item of a kind and rarity.** Items carry their own listed costs; a separate table would drift from them.
- **Selling at the table.** The modifier stack would change in the middle of a round.
- **A confirmation dialog.** Two presses on the same ticket are as deliberate and keep the player's eye on the paper.
- **A Sell button always shown under every held item.** It would crowd the board and add a row to a page that fits 1080 with little room.

## Consequences

- A full board is no longer a dead end: a Cadre can be traded for one on the counter in the same visit.
- Selling and buying back the same Cadre in later visits loses half its price each time, so it is never a way to make coupons.
- A future debuff or boss that holds a Cadre across a shop visit is refused a sale with a reason, without further code.
