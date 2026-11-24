# ADR 0039: Cadres work for the household

- Status: Accepted, 2026-11-24. The owner's direction from their playtest of 2026-11-24; the lead wrote the rule, and this records it and how it is built.
- Supersedes: the Plan's key design rule that an unlocked variant applies to everyone at the table, including the AI, unless the Cadre says otherwise, and the sentence of ADR 0032 that a collective Cadre "applies to every seat where its text is about plays".
- Scope: whose seat every Cadre acts for, how mixed rank orders compare in one trick, what the bots read, and the rules text. Directives, Reforms, Campaigns, card marks, debuffs and boss twists are unchanged.

## Context

The owner, after playing the build:

> My concern is that because there is a communal deck and cadres also buff NPCs, this causes a problem. [...] if the stamps are part of the combo, then my cadres effecting everyone also lets the NPCs use the combos as well, which takes away part of the fun. [...] cadres really shouldnt effect NPCs. [...] for cadres that doesnt manipulate points but other mechanics (i.e. 3s are larger than 2s) that helps you win tricks, its a problem.

Under the old rule fourteen Cadres carried a `table_wide` flag. Their rule and rank hooks built every seat's rules and rank map, and their scoring hooks scored every seat's plays: a villager holding the cards of the player's combo got the player's Cadre with them. The communal deck stays, because sharing it is the game's commentary; the Cadres the player buys stop working for the other side.

## The rule

1. **A Cadre never changes what a villager may play or what a villager's cards beat.** Every rule hook (`build_ruleset`) and rank hook (`build_rank_map`) of a Cadre builds the holder's seat alone. The holder is always the player's seat.
2. **A collective Cadre's scoring pays on its holder's plays and, while the holder is a peasant, on the teammate's.** It feeds the Commons they share. It never pays on a play by the holder's opponents: not on the landlord's while the holder is a peasant, and not on either peasant's while the holder is landlord. The definition says so with `counts_for_teammate`, which only a collective Cadre with a scoring hook may set. A private Cadre scores its holder's plays alone, as before. Iron Rice Bowl is collective but its text speaks of "your plays" and caps "your Rate", so it stays the holder's alone.
3. **A collective Cadre's round and economy effects that speak of the peasants act only while the holder is one.** The Gleaners pays nothing to a landlord holder. Model Commune and Public Granary already asked this. Seed Grain counts the player's met Quotas, whoever sat where.
4. **Everything else stays.** The communal deck, card marks (Model, stamps), enhancements and wild ranks are as they were. Debuffs and boss twists act on whoever they act on now. Red Ink's `for_anyone` switch, which no data set, is gone: under rule 2 a private Cadre cannot pay another seat.

### What a villager may do against a rule Cadre

Shock Brigade lets the holder play a Straight of 4 cards, and Double-Share Plough a Pair Run of 2 pairs. A villager has no such hand. They may not lead one, and they may not answer one in kind: a hand answers a chain only at a length its own rules allow. Against one, a villager passes, or plays a Bomb or the Rocket, which beat any plain hand. A chain of the usual length is answered as always, by the holder or a villager.

## Mixed rank orders in one trick

A rank map gives each seat's order as 0 to 14, and moving a rank shifts the ranks between it and its target. One seat's map read against another's breaks that: with the old maps, a holder's promoted 3 stood level with a villager's 2 and could not beat it, and every rank it passed (the holder's 4 to 2) stood a step weaker than the same rank of a villager's, so the holder's Ace no longer beat a villager's King. Rehabilitation and Class Label, private already, had the same fault in a smaller way: a Rehabilitated 7 tied a villager's 8 rather than beating it.

Options:

- **Compare both plays in one seat's map**, the leader's or the holder's. Then a villager's 3 would beat the holder's 2 in the holder's map, so the Cadre would work for the villager again.
- **Put every rank map on a finer scale.** About 180 reads of a rank map in 47 files compare it with printed ranks or add to it, and the bots' weights are tuned on the 0 to 14 values.
- **Keep the order and add standings** (chosen). Beside each seat's order, SeatRules builds its standings: the same order on a scale where printed ranks stand `Standing.STEP` (16) apart, built by running the same rank hooks again. RankShift drops a moved rank into the gap just above its target and moves nothing else, and ReversedRanks turns standings over about the same middle. Within a seat both orders agree; across seats, ranks no effect moved stand level with every other seat's. Only a play's comparison key reads standings: the round reads, generates and rekeys plays with them, and everything that reads one seat's cards (the bots' plans, the hand's sort, the notes on changed cards) keeps the order it had. `Pattern.same_reading` compares a play's shape and main rank, not its key, so a plan made on a seat's order still finds its legal move.

So, with Promotion of the Masses held: the holder's 3 beats any villager's 2 and loses to a joker, every other card of theirs stands level with a villager's of the same rank, and a villager's 3 is still the lowest card. With Cultural Revolution held: after any bomb the holder's order turns over until the trick ends and the villagers' does not, so the holder's 8s bomb beats a villager's 9s bomb but their Ks do not, and the villagers answer in plain order. Turned over, the holder's 3 stands level with a villager's Big Joker; only bombs and the Rocket are played after a bomb, so that never decides a trick.

## The bots

The round decides what is legal, from each seat's own rules and standings, so a bot only ever chooses among legal moves. What it forecasts about other seats now reads those seats too:

- `BotTable.of_seat` carries every seat's rules, order and standings, before and after a bomb in the trick. A table made from one seat's rules alone, as the tournament makes, plays every seat so, as before.
- Rollouts, which Expert's search plays out, decide each seat under its own table, and turn orders over when a bomb lands, as the round does.
- Whether a group is a control asks each opponent's rules and standings, and whether a lead is the top of its kind compares each opponent's standing of a rank with the bot's own.
- Whether a teammate's card is weak reads the teammate's order.

## The text

Each Cadre's rules text says whose plays it acts on: "your" for the holder's. A collective scoring Cadre ends with one line, "While you are a peasant, this counts for your teammate's plays too.", in place of "This applies to everyone at the table." Shock Brigade and Double-Share Plough say a villager can beat their short hands only with a Bomb or the Rocket. The flag is `counts_for_teammate`, read by `RunController.counts_for_teammate`, and the table's strip no longer lists held Cadres under the rules for the whole table: their cards are on the board, and a Reform's table rule is the only thing left there.

## Consequences

- The owner's combo stays theirs: a villager holding cards of it plays and scores them as plain cards.
- The collective Cadres are weaker than before when the player is landlord, and the landlord route gains a little: the player's scoring Cadres no longer pay the two peasants against them. The balance harness (ADR 0027) measures it.
- Directive hand levels, Industrialization's bigger bombs, Mass Line's and Model Worker's wild ranks, and Model cards still act for every seat. They are outside this rule and were reported to the lead to decide.
- Nothing saved changes. Definitions are not saved, and no Cadre's memo holds a count that read another seat.
