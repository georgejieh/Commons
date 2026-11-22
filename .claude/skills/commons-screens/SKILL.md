---
name: commons-screens
description: Design, build, animate or review any screen, HUD element, menu, reward moment, tooltip or tutorial step in Commons so it reads as this game and feels good to use. Use for UI layout, UX, motion and animation, game feel at the table, score and reward moments, reading playtest frames, and whenever the owner says something is flat, boring, confusing, too fast, ugly, or asks to "make it more interesting". Not for game text (commons-prose), sound effects (commons-sfx) or music (commons-bgm).
---

# Commons screens

The owner judges by playing and often cannot say what is wrong, only that something is flat or confusing. This skill turns that into checks you can run and numbers you can change.

`art/STYLE.md` says what the game looks like and how its three materials move. It wins on look. This skill is how to decide, check and fix a screen. `godot-ui-control` and `godot-animation` hold the engine API.

## The loop

1. **Name the job.** One sentence: what the player decides or learns on this screen. Then name its one hero, the thing the eye lands on first. A screen with two heroes has none.
2. **Name the one decision only Commons would make.** Ask whether you would have built the same screen for any card game. If yes, find the one thing that belongs to a brigade office in a bad year and put the boldness there. Keep the rest quiet.
3. **Build with what exists.** `UiMotion` and `MotionPresets` for motion, `ScreenKit` for sheets and text themes, `TextSize.px` for every font size, the string table for every word. A new tunable goes in a data Resource.
4. **List the states and force them.** The default state is the least informative one. [references/states.md](references/states.md) has the list for each kind of screen.
5. **Look at it.** Run the cloud playtest and read the frames as images. Nothing opens on the owner's screen. Motion is read as several frames held at fixed points of its clock, never judged from the tween code.
6. **Score it** against [references/review.md](references/review.md). Write down the three weakest points and a change for each, in values and not adjectives. Change, shoot again, read again.
7. **Stop at three rounds.** If it still falls short, the idea is wrong, not the polish. Go back to step 1.

A builder marks their own work kindly. When a whole screen or a moment is finished, give its frames and the rubric, and nothing else, to a fresh subagent and take its lowest marks seriously.

## When the owner cannot say what they want

Never answer "make it more interesting" by adding decoration. Find which check failed.

| They say | Usually means | Look at |
| --- | --- | --- |
| Flat, boring, nothing happening | No hero, or a routine result and a great one look the same | Review points 1 and 2; the reward ladder in [references/motion.md](references/motion.md) |
| Too fast, I missed it | Another seat acted with no wind-up, or a fact was carried by motion alone | Timing by actor in [references/motion.md](references/motion.md) |
| Too slow, it drags | A motion seen every few seconds has a long animation, or input waits on it | Timing by frequency |
| Confusing | A number with no label, an element that never changes, or two things of equal weight | HUD rules in [references/states.md](references/states.md) |
| Ugly, off | Uneven padding, text off its baseline, a halo on paper, a piece touching its frame | Review point 4 |
| Cheap, like an app | A box around everything, one type size, nothing that could only be this game | Review point 10 |

Then steer by showing, not by asking them to describe:

- **Ask for a reference, not a description.** A game, a screenshot or a clip, and "what in it?". Take its mechanism and leave its look. Write the mechanism as one sentence a stranger could check ("the choice is the only saturated thing on a darkened frame"), not as an adjective ("clean").
- **Offer two versions.** Build both, differing in one named decision, behind a playtest flag. Frame both in the cloud and let the owner pick. A pick teaches more than any answer.
- **Give a thirty-second script.** "Open the store, buy the cheapest thing, watch the stamp." Say what they should see. Their reaction to a script is a result.
- **Turn the reaction into a number.** "It drags" becomes one named value in `MotionPresets` changed by a stated amount. Say which number moved.

## The rules in short

Hierarchy and layout:

- One hero, a few second-rank pieces, the rest plainly lesser. Squint at the frame: one shape should win.
- Vermilion and gold are signals. Each means one thing, and neither is spent on dressing. Grime and corruption never use them.
- Nothing that carries meaning is told by colour alone. The grayscale walk must still read.
- One padding inside a kind of sheet. A label and its value share a baseline. Prices stand in one column.
- Ink on paper has no halo (`ScreenKit.ink_theme`). Text over art has one (`ScreenKit.halo_theme`).
- Grime stays quieter than anything the player must read or choose.

What is on screen and when: see [references/states.md](references/states.md).

Motion and feel: see [references/motion.md](references/motion.md). The short version: how often a thing is seen sets how long it may take; other seats wind up and the player does not; a great result must not look like a routine one; every fact survives with motion off.

Teaching:

- One new idea a step, and only ideas this game owns. Nobody needs teaching that a button is pressed.
- Show the thing done before saying it. Read the step with its text hidden: can it still be followed?
- A short line at a time. If a step needs a paragraph, the step is wrong.
- A hint comes when the player stalls, not before they try.
- The highlight is the thing itself made ready (lifted, edged in gold), in the game's own language. Never a drawn circle or arrow from outside the fiction.

## Before calling it done

- Every state on the list was forced and framed.
- The frames were read, and the review bar was met or the shortfall is written down.
- Layout tests cover it at every text size and at both window sizes.
- Reduced motion shows every fact, and the grayscale walk still reads.
- What was not checked is said plainly. Never describe as working what was not seen.
