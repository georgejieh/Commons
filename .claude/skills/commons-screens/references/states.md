# States, the HUD and tooltips

## States to force

Draw and frame these before calling a screen done. Use the game's real names and awkward real numbers, never round placeholders.

| Kind of screen | States that break it |
| --- | --- |
| Any | Keyboard focus on each control, a pressed button, a disabled one, the largest text size, the smaller window, the longest family name |
| The table | A 20-card hand, a hand of one, every seat having passed, a Bomb on the pile, two meters moving at once, a debuff and a Campaign shown together, the largest score the tally can reach |
| Lists and collections | Nothing yet, one entry, a full page, more than a page, a new entry, a locked entry |
| Stores and stalls | Cannot afford, already owned, sold out, the last coupon, a price at its longest |
| Envelopes and rewards | The routine result, the best result, nothing gained, a second reward arriving during the count |
| Results and endings | Won, lost, a Quota met exactly, a Quota missed by one, a new best |
| Tutorial | Each step with its text hidden, a step skipped, the player doing the wrong thing first |

Where the walk cannot reach a state by playing, give the screen a way for a tool to set it, as the playtest tools do for corruption stages.

An empty list is a state with its own design: a line saying what will appear here and how. A blank sheet reads as a fault.

## The HUD

For each thing shown at the table, answer three questions. If any has no answer, the thing is not ready.

1. What does it tell the player, and what would they do differently for knowing it?
2. When does it appear, when does it go quiet, and when does it leave?
3. Does anything else already show this? If so, merge them.

Then:

- **Sort by how often it is needed.** Needed to choose every play: always shown, at the edges, largest. Needed once a round: shown when it matters. Needed once a run: on its own page.
- **A thing that never changes is not information.** If a notice reads the same from the first round to the last, the player learns to ignore it and then misses the day it matters. Change it when its subject changes, or take it away until then. Stale information misleads.
- **Label every number,** or hang it on the thing it counts.
- **The middle of the table is for the cards.** Only a passing callout lives there.
- **Rank the corners.** Four corners of equal weight read as noise. One cluster leads.
- **Adding costs something.** Before a new badge, chip or line goes on the table, say what it sits beside and what leaves or shrinks to make room.
- **Notices queue.** One at a time, and the same notice twice within half a second is one notice with a count.

## Tooltips and slips

- A slip or tooltip stands right beside the thing it explains, touching it or within `SlipPlacer.REACH`, on the side with room (above or below first, then right or left), wholly inside the window. It never covers the thing itself or that thing's own button. It keeps off other buttons when a spot just as close does, and it may cover other papers and text: it is gone when the pointer leaves, so it stays where the eye is and never jumps to a far edge. Keyboard and gamepad focus place it the same way.
- A slip sits above the HUD and below a modal.
- A slip does not explain its own subject again. Grain's slip does not mark the word Grain.
- One level of nesting at most, and the second opens beside the first, not over it.
- A slip is the fallback for a mark that did not explain itself. If most players would need it to read an icon, redraw the icon.
- Whatever a slip says must also be reachable without a mouse.

## Choices

- Do not ask the player to choose between things that lead to the same place.
- While choosing something to gain, the player can see what they already hold.
- A disabled choice says why, where it stands.
