# ADR 0025: Between runs: the profile, the full run, households, lineage, stakes and corruption (P4.14)

- Status: Accepted, 2026-11-15, by the agent under the design authority ADR 0021 records. The owner judges by playtest.
- Scope: everything that outlives a run, the wiring that lets the app play a whole run, and two roster rules those depend on (a villager's death, and deposing). Builds on ADR 0018 (corruption), ADR 0021 (unlock tiers, households) and ADR 0024 (endings).

## Why this needs a decision

The Plan names four things that carry across runs: lineage, village history, unlocks and stakes. ADR 0018 adds corruption and ADR 0021 gives content its unlock tiers. What is missing is the saved shape, the numbers, and the rules that join them. Three gaps came out while writing this:

- The title still starts the one-Year demo. Nothing starts a full run with the village roster, and Continue always resumes with the demo's settings.
- No rule ever kills a villager or deposes one. The roster has both states, and the endings, the history and corruption all read them, but nothing sets them.
- A warm memory does nothing at the table: a family's `pull` is clamped at zero, so a family the player fed plays exactly like a stranger.

The owner's pillars for this part: power grows a little between runs through unlocks; when the player gets stronger the game gets harder because of it; the look of the game changes across playthroughs.

## The profile

One file, `user://profile.json`, separate from the run save, as today. Its schema moves from 1 to 2 with a migration. Deleting or losing the run save never touches it. It holds:

| Field | What it is |
| --- | --- |
| `memory` | The village's memory of the player (as today) |
| `generation` | How many runs the family has started. A new run is the next generation |
| `finished_runs` | Full runs that reached an ending or a death |
| `wins` | Full runs that survived the last Year |
| `history` | One record per finished run, newest last, capped at 50: the run's ID, its generation, outcome ID, class, the Year it ended in, the household, the stake, and the surname keys of the families that died |
| `lineage` | What the last finished run left the next one: a kind and its values |
| `stake` | The highest stake unlocked |
| `corruption` | 0 to 100, as a float, clamped after every change |
| `seen` | One-time tooltips already shown (P4.15) |
| `surname` | The family's surname (P4.17 writes it) |

**Writing it once.** Two files cannot be written as one transaction, so the profile itself remembers what it has taken. Every run gets an ID when it starts (the seed and the start time, kept in `RunState`). A finished run is recorded only if `history` does not hold its ID. Corruption and memory are committed per Quota: the profile keeps, for the run in progress, the ID and the last Quota committed, and takes a Quota's memory and corruption only if it is later than that. A crash between the two files then repeats nothing and loses at most one Quota's corruption.

**What does not count.** Only a full run moves `finished_runs`, `wins`, `history`, `lineage`, `stake` and `corruption`. The demo, the tutorial (P4.15) and the balance harness (P4.16) never write them. An abandoned run adds no history entry and leaves no lineage; the memory and corruption of the Quotas it finished stay.

## The full run

- **New Run** on the title starts the eight-Year run (`data/run/default_sets.tres`) with the village roster, through `Roster.start()` with the families the profile has unlocked. It starts with 4 coupons before the household's own.
- The run save records which kind of run it is, with its household, stake, and the count of finished runs it started with, so **Continue** rebuilds exactly the run that was saved.
- The demo stays as a second, shorter run for the cloud playtest and for development. It is started only by the `--demo` command-line flag, never from a menu. The playtest tool passes the flag.
- When a run finishes, the ending page shows, the profile takes the record, and "Return to title" clears the run save.
- The pause menu gains **Abandon run**, with a confirm. It clears the run save.

## Villagers who die, and villagers who are deposed

Both are needed here and neither exists.

- **Starvation.** At a Quota's end, if Famine is in its high band, one of the two families seated that Quota dies: the one fed less often at the Commons split in that Quota, by its `fed` count in the Quota's summary, the later seat on a tie. Its roster state becomes dead for the rest of the run, and the log records it. A sent-down youth fills the seat when fewer than two families can sit, as the roster already rules. A boss never dies this way.
- **Deposing.** A risen villager who comes back as a boss and whose Quota the player meets is deposed: out of the boss pool for the run, and out of the village until the next Year starts.
- **Denouncing.** A villager caught by an audit that the player's Anonymous Letter forced counts as denounced by the player. This fills the memory's `DENOUNCED` count, which nothing fills today.

The next run's roster starts whole again: death and deposing last one run. The family that died is the previous generation, and its heirs remember (the memory carries).

## Unlocks

- **Content.** Every Cadre, Campaign, Directive, Reform and envelope carries `unlock_tier`. A tier is open when the run's starting count of finished runs is at or above it, so all four tiers (ADR 0021) are open after three finished runs, won or lost. The filter covers every way an item can be offered or handed over: both shops' stock, the envelopes on offer and their contents, and the Cadre that reeducation gives in exchange. It is applied where the pools are handed to the run, from the count saved with the run, so loading a save rebuilds the same pools. Debuffs have no unlock tier; the ladder is unchanged.
- **Villagers.** The families the checklist already lists join the roster by finished runs: Xu 1, Zhou 2, Ma 3, Feng 4, Tang 5, and Deng after any landlord ending.
- **The collection page** shows every kind, grouped. A locked item is a blank sheet with only its tier ("Opens after 2 more runs"): no name, no rules, no tooltip.

## Households

A household is the family background picked at run setup. It is the starter deck: it sets what the run begins with, and nothing after that. Four to start, as data (`HouseholdDef`):

| Household | Tier | Starts with, beyond the 4 coupons | Cost |
| --- | --- | --- | --- |
| Poor Peasants | 0 | Nothing | None |
| Middle Peasants | 1 | A plot holding two cards drawn from 10 to K | 5 Resentment |
| Shopkeepers | 2 | 6 more coupons | 10 Resentment |
| The Old Family | 3 | Landlord's Ledger | 15 Resentment and 10 Denunciation |

A stronger start is paid for in what the village holds against the family, which is the pillar: the player's own advantage is what makes the game harder. The cost also bears on The Commons, whose limit is 10 Resentment at the run's end: Middle Peasants leave 5 to spare, Shopkeepers none, and The Old Family is over it from the first deal. Landlord's Ledger is a private Cadre, so it also adds its usual Resentment at every Quota's end while held.

## Lineage

Each run is the next generation of the same family. The last finished run leaves one thing to the next, by the class it ended in. Class itself never carries.

| Last run ended | Kind | The next run starts with |
| --- | --- | --- |
| Landlord, any ending | Material | An heirloom: one Model plot card, a rank drawn from J to A |
| Peasant, any ending but Labeled | Social | One loyal family |
| Labeled | The label | 15 more Denunciation, and nothing else |
| The Commons | Social, doubled | Two loyal families |
| A death | Nothing | Nothing |

- **A loyal family** is chosen when the run ends: among the families not dead, deposed or in reeducation, the one with the lowest weighted grudge, the earlier in roster order on a tie. If its grudge is not below zero, nobody is loyal and the lineage is empty. The Commons takes the two lowest. In the next run, after the usual carry-over, that family's memory is set to four feedings and nothing else.
- **Loyalty at the table.** A family's warmth is its negative grudge over `full_grudge`, from 0 to 1, the mirror of `pull`. As a teammate, a warm family's cooperation rises by `warmth × loyal_cooperation` (data). As an opponent it changes nothing: loyalty is not throwing the game. This applies to every warm family, not only an inherited one, so feeding the village now pays at the table.
- **Starting numbers add up.** Household, lineage and stake amounts of the same thing are summed.
- The run setup page says what was inherited, in one line. The heirloom goes into the plot first and the household's cards after it; together they never pass the plot's capacity of 4.

## Stakes

A ladder of harder rule sets. Winning a full run at the highest unlocked stake unlocks the next. The player picks any unlocked stake at run setup. Each stake keeps every rule of the stakes below it. Six to start, as data (`StakeDef`):

| Stake | Name | Adds |
| --- | --- | --- |
| 0 | Base | Nothing |
| 1 | Second Harvest | Every Quota's target is 10% higher |
| 2 | Tight Books | The state store shows one fewer Cadre |
| 3 | Short Rations | Famine starts each run at 10 |
| 4 | Watchful Eyes | Denunciation starts each run at 10, and one more die face audits, under the usual cap of five |
| 5 | The Third Year | Every debuff ladder has 1 more point of severity to spend |

A stake changes only numbers the game already has: the Quota targets, the store's slots, the starting meters, the audit's base faces, and the ladder's budgets. Each is handed to the run as its own copy of the data, never by changing a shared resource. Every number is for P4.16 to tune.

## Corruption

ADR 0018 stands, with its provisional event list replaced by the one below. Free-riding and hiding grain are gone from the list because the game has no clean record of either; black-market buying in a famine and the two hostile Campaigns take their place.

- **Events and weights** (data). Each is an attribution rule, stated as such: the game counts the circumstance, and does not claim to prove the cause.

| Event | Weight |
| --- | --- |
| Declaring more need than the true need | 1 |
| Being caught doing it | 2 more |
| Bombing a play your teammate made | 1 |
| Using Anonymous Letter or Seizure Notice | 2 |
| Being the landlord in every round of a Quota | 2 |
| A black-market purchase while Famine is in its high band (a reroll is not a purchase) | 2 |
| A family starving while you hold 8 or more coupons | 6 |
| A family sent to reeducation in a Quota where you bombed it or denounced it | 4 |

- **Growth.** Each event adds `weight × (1 + growth × corruption / 100)`, with `growth` 3 to start: the same act costs four times as much near the top as at the start. ADR 0018 wrote the formula without saying whether corruption was a fraction; this is the reading. Events in one Quota are applied in the order they happened. The target for P4.16 is that an ordinary player reaches stage 5 in about six runs and stage 9 in about twelve.
- **Stage.** `min(floor(corruption / 10), 9)`. `ArtStages.stage()` reads it from the profile. The horror-intensity setting caps the stage the art shows: at intensity `i` from 0 to 1, no art above stage `round(9 × i)`. The stage in use is latched when a run starts and at each round's start, never inside a round.
- **Reset.** The Commons sets corruption to 0, after that run's last events are applied, so nothing from the run survives the reset. The next run opens at stage 0. The reset is instant and nothing announces it. Deleting the profile also resets it. Nothing else lowers it.
- **Hidden.** No number, bar or hint. Release builds expose it nowhere. A development build takes `--corruption N` to set the value for the session, beside today's `--corruption-stage N`.

## Village history

The history page keeps what it shows today for the run in progress, and adds the family's past generations from `history`, newest first: the generation, the ending's title, the class, the Year, and the families that died, as a plain line each ("Generation 3. Lean Years. Not at roll call: Li, Chen."). Names are kept as surname keys, so a sent-down youth is still named after their run is gone. It is a record: no new prose beyond those fields.

This is less than the Plan promises. Graves, monuments and rumours on the table backdrop are art, and go to the art pass; "altered starting conditions" are what lineage and memory do.

## Card designs

A card back is a cosmetic choice in Settings, and nothing about it changes play. One exists, with art at three corruption stages. This amends ADR 0021, which tied card designs to households and corruption: two more backs unlock at 2 and 5 finished runs. Both ways a back is drawn follow the choice: the picture on the seat panels, and the code-drawn back on moving cards, which takes its inks from the chosen design. The mechanism ships with this item. The two new backs ship when their art does, and until then Settings shows them as locked sheets.

## Build order

1. Deaths, deposing and denouncing; loyalty at the table.
2. The profile's new shape and migration, run IDs and once-only commits, and the full run in the app with `--demo`, Continue and Abandon.
3. The unlock filter, villager unlocks, and the collection page.
4. Households, lineage and stakes, with the run setup page.
5. Corruption: events, the profile value, stages read from it, the intensity cap, the reset.
6. The history page.
7. Card designs: the mechanism and the Settings row.

## Consequences

- The run save moves up a schema for the run's ID and kind, the household, the stake and the starting count of finished runs.
- `ArtStages.stage_override` stays for tests and the playtest tool.
- The app, the demo, the tutorial (P4.15) and the balance harness (P4.16) all start runs through one place, which takes the set, the household, the stake, the lineage and whether the profile is written.
- Starvation makes high Famine cost a neighbour as well as a meter. P4.16 has to check it does not turn a hard run into a lost one by emptying the table.
- Until the two card backs have art, "unlocking new card designs" is a mechanism without content. The checklist carries the art.
