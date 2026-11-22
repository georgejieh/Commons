# Motion and feel

`art/STYLE.md` (Motion) says what moves like paper, cloth and ink. This file says how long, how often and how to check. Every number here is a place to start; the real ones live in `data/ui/motion_presets.tres` and are tuned by playing.

## How often sets how long

Ask of every animation how often the player sees it.

| Seen | Examples | May take |
| --- | --- | --- |
| Many times a minute | Hover, selecting a card, focus moving | Under 0.15 s, and never blocks the next input |
| Every turn | A play landing, a pass, a meter moving | 0.2 to 0.4 s |
| Every round | The score tally, a purchase, the kitty | 0.6 to 1.2 s, and a click skips to the end |
| Once a Set or rarer | A Quota met, a boss, an ending, a rare envelope | Up to about 1.5 s of the whole screen |

Something seen a hundred times an hour gets almost nothing. Something seen once a session can take a second.

## Who acted

- **The player's own action answers at once.** The state changes on the click. Put the weight after it, in the landing and the settle, which delay nothing.
- **Another seat's action gets a wind-up.** The player did not choose it, so they need a beat to look: the seat's cards lift, or its name tag marks, before the cards leave. Without that beat a fast table cannot be followed.
- **One timing for one kind of play.** A Single always takes the same time, a Bomb always the same longer time. Random variation reads as a fault and cannot be learned.
- **A refusal is small and instant.** An illegal selection gets a short shake of the selection and a dull sound, never a dialog.
- **Information read under pressure does not animate in.** What the player needs to choose a play is simply there.

## Rewards

A reward that changes nothing the player can see was not a reward.

- **Three beats:** a held breath before, the result landing past its size and settling, then the count. The second beat is the short one.
- **A ladder.** Decide what a routine result, a good one and a great one each get, and keep the top rung for what happens about once a run. If every envelope gets the gold seal, the gold seal means nothing.
- **A budget per event.** At most three sounds layered, a few moving things, the screen clear again inside a second and a half.
- **One long effect.** A screen may have one effect that takes its time. When a moment reads weak, replace its effect with a better one; do not stack a second on top.
- **Count where it can be watched,** and let a click jump to the final value.
- **Show what it changed.** After the moment, the thing gained is visibly in its new place: in the ledger, on the board, in the hand.

## Arriving and leaving

- A page's pieces arrive in order and are whole in about a second (`UiMotion.enter`).
- Arrivals may land past their size and settle. Departures do not: they are short and plain, and whatever the click does happens on the click, not when the departure ends.
- Leave room for a landing that overshoots. A piece already at the edge of its frame will be cut by it.

## Godot traps

- **Inside a Container, never tween `position`.** The Container sets position and size again each time it sorts. `UiMotion` changes scale and opacity for that reason. If a piece has to travel or turn inside a Container, use the offset transforms of 4.7 (`offset_transform_enabled`, see `godot-ui-control`), which the Container leaves alone, and add the move to `UiMotion`, not to the screen.
- **A pivot in pixels goes stale.** `pivot_offset = size / 2` is the centre only until the Control is resized, and a Control in a Container has no size in `_ready`. Use `pivot_offset_ratio = Vector2(0.5, 0.5)`.
- **Return to the resting value, not to a literal.** Remember the scale a piece had before the first effect and go back to that, or a second hit during the first creeps it larger.
- **One tween for one property.** Stop the running tween before starting another on the same property, and set the final value where an effect ends.
- **Set the start state after you know the tween will run.** A piece made invisible for an entrance that never starts stays invisible, and a headless walk will not notice.
- **One switch for reduced motion.** Every tween asks `UiMotion.reduced()` or goes through `UiMotion`. A switch with one exception is not a switch. Tool scripts cannot name `UiMotion`, since it needs an autoload; they read the flag from their arguments.
- **Digits.** Oswald's digits are of different widths and the font has no tabular figures. A number that rolls in Oswald needs a box sized for its widest value and a fixed alignment, or it must be drawn digit by digit in equal cells. Courier Prime is already fixed-width.
- **A piece that is fading in is fainter than its resting contrast.** Do not judge contrast from a frame taken mid-entrance, and pulse the paper, not the ink.

## Checking motion

A still at rest proves nothing about motion, and neither does reading the tween code.

- Give the moving piece a clock that a tool can hold, as `TitleWord.clock` does, and take a frame at several fixed points: the start, the peak, just after the peak and at rest. Two to eight frames tell what one cannot.
- At the peak: is the hero the largest, brightest thing on the screen?
- At rest: is every piece exactly where the layout puts it? Compare with a frame taken under reduced motion; they should match.
- Under reduced motion: is every fact still shown?
- Then give the owner a thirty-second script. A reaction of "slow" or "I missed it" is a result. Change one named number and say which.
