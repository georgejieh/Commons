# ADR 0031: Leaving the landlord's seat to others costs Famine

- Status: Accepted, 2026-11-16, by the agent under the design authority ADR 0021 records.
- Scope: one new source of Famine, the number the run keeps for it, and the run save's schema. Found while tuning under ADR 0027.

## The problem

The Plan says of the bid: "Early on the peasant route is clearly stronger; the run's systems slowly make the landlord route more tempting." Nothing in the game did the second half. A player who never bid lost only what the seat would have scored.

The balance harness (ADR 0027) showed what that left out. Its target is that the mixed strategy survives more often than private, and private more often than collective. Collective, which never takes the seat, survived 23 to 34% of runs in the four measurements after rewards were raised, and private between 0 and 13%. Every number ADR 0027 lists for tuning was tried:

- **Targets.** A Quota's score varies widely from run to run (the tenth of runs at the bottom score a quarter to a half of the target, the tenth at the top two to six times it). Raising targets 20% lowers the share met by about 5 points, and for all three strategies together.
- **Rewards.** Moving coupons from meeting a Quota to beating it changed collective by 3 points and mixed by 2, inside the noise of 61 seeds.
- **Meter sources and prices.** These decide how private dies, and did not touch collective.

None of them can separate a player who never bids from one who sometimes does, because none of them reads the seat.

## Decision

1. **The run counts Quotas in a row that ended without the player having held the landlord's seat in any round.** Holding it for one round, by a call, a grab, a rebid or keeping it from the round before, sets the count to zero. A round's holder is the seat its `SEAT_KEPT` or `SEAT_LOST` event names, read by `YearClass.held_seat`, and the count is `RunState.seatless_sets`.
2. **Past a grace, each such Quota adds Famine.** With a grace of G Quotas and a count of N, a Quota costs N less G steps, at most the most, and nothing while N is G or less. A step is the `stood_by` row of the meter table, so the Famine added is the steps times that row. The grace and the most are `seat_grace_sets` and `seat_max_steps` in `data/run/default_run.tres`: 3 and 4, with a row of 1, so the fourth Quota in a row adds 1 Famine, the fifth 2, the sixth 3, and every one after 4.
3. **It is applied at the Quota's end**, after the missed-target row, starvation, villagers' reeducation and the record of styles and risen villagers, and before Resentment is counted, through the same meter path as every other source (`RunMeters.apply_amount` and the meter change hook), so a Cadre, Reform or debuff that changes Famine changes it too. Starvation has already been checked by then, so the Famine this adds can starve a family only at a later Quota's end. A run it takes to the death threshold ends as a Famine death.
4. **The count is saved with the run.** The run save moves to schema 14; `RunRecord.migrate_from_13` starts an older save's count at zero, and a count that is missing, negative or not whole makes the save damaged.
5. **The player is told.** The loop logs a `STOOD_BY` event on the last free Quota (value 0) and on every Quota that pays (value the steps, amount the Famine added), so the presentation never works the rule out. The Quota's summary names the cost when it is paid and warns on the last free Quota, except the run's last Quota, which has no next one. The Famine keyword's text lists the source with its numbers, written out by hand, so it must be changed with the data.

The first version tried was simpler: 3 Famine whenever one villager kept the seat through a whole Quota, the test that already marks a villager as risen. It fired on 62% of collective's Quotas, but also on 38% of mixed's and 27% of private's, and mixed lost more survival than collective did (47.5% to 21.3%, against 23.0% to 11.5%). A cost that grows with the run of Quotas is what tells the two apart: a player who never bids is always at the most, and one who takes the seat now and then rarely leaves the grace.

With the rule at a grace of 3 and a most of 4, and the other numbers tuned around it, the same 61 seeds gave mixed 50.8%, private 21.3% and collective 6.6%, each gap past the 90% intervals.

## Why this rule

- It is the Plan's own sentence. The longer the seat is left to others, the more it costs to leave it.
- It makes the bid a choice with a cost on both sides. Taking a held seat adds Resentment; leaving it adds Famine.
- It reads the one thing the three strategies differ on most.

## Consequences

- A run played without ever bidding is now very hard to survive. The collective ending is still reachable by a player who takes the seat only as often as the grace asks.
- Mixed and private pay it too, when the cards or a risen villager keep them out of the seat for several Quotas.
- The tutorial and the demo are short enough that the grace covers them: the demo has three Quotas, so its third can reach the grace but never pass it, and the summary does not warn on it because it is the run's last.
- The numbers live in `data/run/default_run.tres` and the `stood_by` row of `data/run/meters.tres`. The measurements that set them are in `docs/CHECKLIST.md` under P4.16.
