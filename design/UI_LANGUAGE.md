# UI language

Commons' visual language for P3B.0, in the propaganda-poster direction ([ADR 0015](../docs/adr/0015-art-direction.md)). The reference board in `design/reference/` is private: 24 store-page screenshots, four per game, which are gitignored, excluded from exports, and never traced or used as image-model input. This file records what each reference solves and Commons' own answer to it, from the Plan's divergence table. The "problem it solves" column is a design reading, not a measured result. The reference descriptions were cross-checked with GPT-6.1-Sol on 2026-11-03.

## What each reference solves

| Reference | Problem it solves | How it solves it | What Commons takes |
| --- | --- | --- | --- |
| Balatro | Reading a score as it builds | A fixed left column holds the target, the round score and the hand's two factors as two big colored numbers (Chips in blue, Mult in red). The scoring cards and then other effects resolve one at a time while the factors change | Show the score in visible stages, one modifier at a time, and give each factor one color that never changes |
| Luck be a Landlord | Making escalating pressure feel physical | The rent due and the spins left stay visible in normal play, over a bold, flat background | Keep the Quota and the rounds left in view during play |
| Inscryption (Act I cabin) | An opponent in the room and a table you sit at | A first-person view across a table, with the opponent above the board, mostly in shadow, and props that are part of the room | Put the villagers across the table from you, as people, not as panels |
| Slice & Dice | A whole fight on one screen | Heroes in a column on the left and enemies on the right, each unit's status in one compact row | Fit a whole trick on one screen: every seat's last play stays visible until the trick ends |
| Cobalt Core | Legibility at a glance | In its store screenshots, interface elements are outlined and the key readouts are easy to pick out. Where things sit on the ships matters as much as the numbers | Draw the numbers you act on large, Grain and Zeal first, on plain grounds |
| Wildfrost | Cute art over grim systems | Cute companions with stat icons on each card, including a countdown to when the card acts, in a hostile winter setting | The clean board looks warm and sincere, and the dread comes from decay, not from how the board starts |

## The look, after the owner's refinement

The art reads as Mao-era propaganda at a glance and as something worse the longer you look ([ADR 0015](../docs/adr/0015-art-direction.md), amendment). The sun every poster turns toward is a vast lidless eye; its rays end in pale hands; crowds share one blank, smiling face; shadows have too many arms. Nothing names a real nation: no emblems on the flags, no stars, no leaders, no slogans, no characters. The interface stays plain ink and paper so the art carries the dread, and the dark room around the table (one weak lamp, eyes beyond it) carries it during play.

## Commons' answers

**Table.** The screen is the play area, not a whole table seen from above, the way Hearthstone and MTGO frame their boards (the project owner's direction, 2026-11-03). A dark wooden rail runs around the screen edge, so it reads as the edge of a table rather than a wall or a playmat. Inside it, the two villagers sit along the top edge as compact portraits with their name, card count, role and last words. Each has a lane in front of them where their current play lands. Your hand fans along the bottom rail, and your own play lands in a lane above it. The landlord's portrait has a gold frame and a red LANDLORD tag.

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

## Sign-off

On 2026-11-04 the project owner approved the table, state store and Set intro mockups and completed the side-by-side review against `design/reference/`, finding no copied layout, color scheme, typography or asset. Other screens reuse the approved screens' parts through `ui/screens/screen_kit.gd` rather than having mockups of their own.
