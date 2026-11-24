# ADR 0026: The arrival: a tutorial that is played, not read (P4.15)

- Status: Accepted, 2026-11-15, by the agent under the design authority ADR 0021 records. The owner judges by playtest, and the "about 10 minutes" check in the checklist is theirs.
- Scope: when the tutorial is offered, how it is scripted, every move of both rounds, what each step says, the one-time tooltips in real runs, and what it may write.

## Why this needs a decision

The checklist says what the tutorial must cover and that the player acts in every step. It does not say how a scripted round sits on an engine built for seeded deals and thinking bots, what the moves are, or what the steps say.

## How it is built

- **A third kind of run.** `RunIdentity` gains the kind `TUTORIAL` beside full and demo. A tutorial run is never saved and never writes the profile: no memory, no corruption, no finished run, no generation. Finishing or skipping it is what writes the profile's first save, with the tutorial marked seen.
- **Everything is authored.** The run has a fixed seed. Each round deals a fixed order of the 54 cards through `Dealer.deal_in_order` (seat 0's 17 cards, seat 1's, seat 2's, then the kitty). The villagers' bids, plays, passes and claims come from lists kept as data, and so do the faces the audit dice show. The Quota has two rounds, a target they cannot reach, no debuff ladder, and 10 starting coupons. All of it is data.
- **Scripted villagers** answer through the same `Bot` methods the loop always calls for a bid, a play and a need. A scripted move that is not legal when its turn comes is a bug: the scripted test fails on it and on any refused bot action.
- **Steps.** A step names one action the player must take (a bid, an exact set of cards, a pass, a need to declare, a button), what to highlight, the line that prompts it and the line that follows it. The table accepts only that action. Anything else does nothing and the prompt pulses once. Steps are data; one small controller in the game layer walks them.
- **Skip.** A "Skip" button is on every tutorial screen. It asks once, then goes to the title.
- **The speaker.** Wang, the neighbour from the next house, says every line, on a paper slip with his portrait beside the thing it points at. Each slip is at most two sentences.

## When it is offered

Whether a profile save exists is read once, when the app starts, before anything can write one. With none, after the content note (and after the surname step once P4.17 adds it, which keeps the surname in hand and does not write the profile itself): one page, "Arrival", with **Sit in** and **Skip**. Quitting part-way leaves no profile, so the page is offered again next time. Finishing leads to run setup for the first real run; skipping leads to the title. Settings gains **Replay the arrival**, which ends at the title.

## The script

Seats: the player is seat 0, Wang seat 1, Zhao seat 2, as in the demo. Play runs 0, 1, 2. The landlord leads, and after two passes the last player to play leads.

**Arrival page.** "The cart leaves you at the brigade office. Wang from the next house says there is a game tonight, and you should sit in."

### Round 1: a peasant, with Wang, against Zhao

The player's 17 cards: a 9; 10 J Q K A; a pair of 5s; four 3s; three 4s and a pair of 6s. Bold moves are the player's steps.

| Trick | Moves in order |
| --- | --- |
| Bid | **Player passes (step 1).** Wang passes. Zhao calls and takes the kitty. |
| 1 | Zhao leads a 7. **Player plays the 9 (2).** Wang passes. Zhao plays a K. **Player passes (3).** Wang plays a 2. Zhao passes. **Player passes (4).** Wang leads. |
| 2 | Wang leads 4 5 6 7 8. Zhao plays 5 6 7 8 9. **Player plays 10 J Q K A (5).** Wang passes. Zhao passes. The player leads. |
| 3 | **Player leads the pair of 5s (6).** Wang passes. Zhao plays a pair of queens. **Player plays the four 3s (7).** Wang passes. Zhao passes. The player leads. |
| 4 | **Player leads 4 4 4 with 6 6 and is out (8).** The peasants win. |

| # | The player must | Wang says | Then |
| --- | --- | --- | --- |
| 1 | Pass on the bid | "Someone has to be landlord. Let Zhao have it tonight: pass." | "Zhao took the seat and the three spare cards. You and I are the peasants, on the same side." |
| 2 | Play the 9 | "Zhao led a 7. Play one card that is higher." | "A higher card of the same kind takes it." |
| 3 | Pass | "Zhao's king beats your 9. Pass, and let me try." | "My 2 took it." |
| 4 | Pass | "It is ours now. Pass again, and keep your cards." | "Two passes, so I lead." |
| 5 | Play 10 J Q K A | "Zhao beat my five in a row with a higher five. Yours runs higher still: play it." | "Same length, higher cards." |
| 6 | Lead the pair of 5s | "Everyone passed, so you lead. Play your pair of 5s." | "Zhao answered with queens." |
| 7 | Play the four 3s | "Four of a kind is a bomb. Play yours on his queens." | "Nothing he holds answers that." |
| 8 | Lead 4 4 4 with 6 6 | "Three of a kind can carry a pair. Play them together and you are out." | "You are out first, so our side wins the round." |
| 9 | Open the Rules sheet, then close it | "Open Rules. It lists every hand and what it scores." | "Close it when you have looked. It is always at the table." |
| 10 | Declare the true need | "As peasants, what we scored went into the Commons. Claim your household's need, and no more." | The dice roll, and the player's shows a 1. "Your die came up 1, so they checked your claim. It was true, so nothing happened." |

### Round 2: the landlord, alone

The player's 20 cards with the kitty: 3 4 5 6 7 8 9; 8 9 10 J Q K A; three 2s and a pair of 4s; a 5.

| Trick | Moves in order |
| --- | --- |
| Bid | **Player calls (step 11)** and takes the kitty. Wang passes. Zhao passes. |
| 1 | **Player leads 3 4 5 6 7 8 9 (12).** Wang passes. Zhao passes. The player leads. |
| 2 | **Player leads the 5 (13).** Wang plays an ace. Zhao passes. **Player passes (14).** Wang leads. |
| 3 | Wang leads 6 6 6 with 3 3. Zhao passes. **Player plays 2 2 2 with 4 4 (15).** Wang passes. Zhao passes. The player leads. |
| 4 | **Player leads 8 9 10 J Q K A and is out (16).** The landlord wins. |

| # | The player must | Wang says | Then |
| --- | --- | --- | --- |
| 11 | Call the seat | "Tonight you take the seat: call." | "The three spare cards are yours. You play alone now, against both of us." |
| 12 | Lead 3 to 9 | "The landlord leads. Start with your long straight, 3 to 9." | "Seven cards gone in one play. Neither of us can answer it." |
| 13 | Lead the 5 | "You lead again. Get rid of the 5." | "My ace takes it." |
| 14 | Pass | "Keep your 2s together. Pass." | "So I lead." |
| 15 | Play 2 2 2 with 4 4 | "I led three 6s with a pair. Play your three 2s with a pair." | "Three 2s beat any three." |
| 16 | Lead 8 to A | "We both passed. Play your last straight." | "As landlord you kept all of it yourself." |

### The Quota's end and the shops

| # | The player must | Wang says | Then |
| --- | --- | --- | --- |
| 17 | Press Continue on the Quota's report | "Two rounds were not enough for the Quota. Press Continue and watch the room." | Famine rises, and the room is shown for a moment as it looks when Famine is high. "When the brigade misses a Quota, Famine rises." |
| 18 | Buy the one Cadre on the counter | "Coupons buy help at the state store. Buy Iron Rice Bowl." | "A Cadre stays with you and works every round." |
| 19 | Go behind the store and buy the plot card | "There is another counter behind the store. Go round, and buy the card for your private plot." | Denunciation rises, and the room is shown for a moment as it looks when Denunciation is high. "Someone saw you back there. Buying privately raises Resentment, and Resentment becomes Denunciation." |
| 20 | Press "Begin your first year" | "That is all I can show you. Press the button and your first year starts." | To run setup. |

The Famine at 17 is the game's own rule for a missed Quota. The Denunciation at 19 is a scripted amount (data), because in a real run Resentment turns into Denunciation only at a Quota's end. Each room is the real board at that meter's high band, held for about two seconds with the meter named in a caption, and then the board returns to its true state.

## One-time tooltips in real runs

Each shows once per profile, the first time its subject appears in a full run, as a paper slip the player dismisses. The profile's `seen` list remembers them.

| Subject | When | Text |
| --- | --- | --- |
| Private plot | The first time the plot swap is offered | "Your private plot. Before the first play you may swap plot cards into your hand, up to the number shown, and each one goes back to your plot when the round ends." |
| Debuffs | The first Quota page that lists a debuff | "From round 2, each round of a Quota adds a debuff. They stack until the Quota ends." |
| Villager memory | The first time a family that remembers the player is seated | "Families you fed, bombed or denounced remember it. The memory fades a little each run, and it changes how they play with you and against you." |

## Two existing lines this corrects

The Quota page says debuffs "apply only to you", and the table's strip is headed "Debuffs on you only". Since ADR 0023, Work-Point Audit touches every claim and Redistribution moves every hand. The Quota page's line becomes "Later rounds add debuffs. They stack until the Quota ends.", and the strip's heading becomes "Debuffs".

## Consequences

- A scripted test plays the whole tutorial with the authored inputs. It fails if any scripted villager move is refused, if any step accepts an action it did not ask for, if any slip is longer than two sentences, or if the two deals are not 54 different cards each.
- The tutorial uses the demo's two villagers, Wang and Zhao, and none of the roster.
- Iron Rice Bowl and the plot card in steps 18 and 19 are placed on the counters by the script; the tutorial's shops draw nothing else.
- The cloud playtest gains the tutorial's frames, started with a `--tutorial` flag beside `--demo`.
- P4.17's surname step must not write the profile before the tutorial ends.

## Amendment, 2026-11-20: the light and the slip's home

The owner's playtest found the hand-drawn red ring round a step's target ugly, and found Wang's slip lying over the play's sum and the score while a step taught them.

- **The target is lit, not ringed.** A gilt frame with a breathing vermilion halo hugs the button or the card itself. It swells once when it moves and stands still under reduced motion. On a play step the cards are already put up as chosen, so the light is on Play; a card the player has put down again is lit in its place.
- **At the table the slip has one home,** beside Wang's seat, over the Cadre board's slots, which are empty through the arrival. It no longer moves to each target, so it never lies on the hand, the trick, the prompt or the place the score is counted. Other screens place it beside the target as before, and while the rules card is open it stands beside the card's Close button.
- **A one-time tip stands in the middle of the screen,** or of the right half where the screen's own sheet fills the left.
