# UI language

Commons' visual language for P3B.0, in the propaganda-poster direction ([ADR 0015](../docs/adr/0015-art-direction.md)). The reference board in `design/reference/` is private: 24 store-page screenshots, four per game, which are gitignored, excluded from exports, and never traced or used as image-model input. This file records what each reference solves and Commons' own answer to it, from the Plan's divergence table.

## What each reference solves

| Reference | Problem it solves | How it solves it | What Commons takes |
| --- | --- | --- | --- |
| Balatro | Reading a score as it builds | A fixed left column holds the target, the running score and the hand's two factors as two big colored numbers. Played cards sit center stage while each one adds its value | Show the score in visible stages, one modifier at a time, and give each factor one color that never changes |
| Luck be a Landlord | Making escalating pressure feel physical | The rent due and the turns left are always on screen, and the whole frame is one loud, flat color | Keep the Quota and the rounds left in view at all times |
| Inscryption | An opponent in the room and a table you sit at | A first-person view across a table, with the opponent's face above the board and props that tell you where you are | Put the villagers across the table from you, as people, not as panels |
| Slice & Dice | A whole fight on one screen | Allies in one column and enemies in the other, with each unit's state packed into a single row | Fit a whole trick on one screen: every seat's last play stays visible until the trick ends |
| Cobalt Core | Legibility at a glance | Few colors per element, a strong outline, and the numbers players act on drawn large | Draw the numbers you act on large, Grain and Zeal first, on plain grounds |
| Wildfrost | Cute art over grim systems | Soft, friendly characters with clear stat badges, so the danger lives in the numbers | The clean board looks warm and sincere, and the dread comes from decay, not from how the board starts |

## Commons' answers

**Table.** You look across a three-seat table from your own seat. The two villagers sit at the far left and far right, each with a portrait, a card-count badge and a speech line. The landlord's seat has a red paper banner. Your hand fans along the bottom edge. Each seat's current play lands in front of that seat, so you can read a trick by where the cards sit.

**Scoring.** Each play is written into a work-point ledger, one row per play, in a narrow ledger book on the right. A row shows the hand type, then Grain in wheat ochre times Zeal in vermilion, then a red ink stamp with the total. Modifiers add their steps to the row one at a time, so you see what changed the score. The Set's progress is tallied at the foot of the page against the Quota, the way an accountant totals a sheet.

**Cadres.** Cadres are portrait cards pinned to a notice board on the wall behind the table, in slot order from left to right. A Cadre's pin flashes when it changes a score.

**Colors as labels.** Grain is wheat ochre, Zeal is vermilion stamp ink, and coupons are ration-paper green. The landlord is lacquer red with gold trim. Every other surface is warm cream paper, with ink-black text and lines. No color is reused for a second meaning.

**Texture.** Printed poster and paper grain, with slight print misregistration on large color blocks. There's no CRT frame. The dread layers (P3B.12) later bleach, crack or redact this paper, so it has to read as paper first.

**Meters.** Famine is the granary barrel and the wall roster of names. Denunciation is the posters and eyes on the wall. In the demo they are two labelled gauges at the top of the room, until the dread layers arrive.

**Type.** A condensed poster face for titles and numbers, and a plain readable face for rules text. Both must be licensed for embedding. Choosing them is P3C.1 work. The demo uses Godot's default font at the right sizes.

## Screens the demo needs mocked up first

1. Table: round play, from your seat.
2. State store: three Cadres on a counter, with prices in coupons, a reroll and your notice board.
3. Set intro: the Quota, the Set type and the debuff ladder, one card per round, with round 1 always clean.

Each mockup has to pass the side-by-side check against the references: no copied layout, color scheme, typography or asset.
