# ADR 0018: Corruption that only deepens, and portraits from memory

## Status

Direction accepted by the project owner on 2026-11-04. Implementation is deferred until the full game exists, because the effect can only be judged across a whole playthrough and several runs.

## Context

The Plan's horror layer follows the Famine and Denunciation meters. Those rise and fall within a run, so the board can recover. The ADR 0015 amendment then made every asset propaganda distorted by cosmic horror from the start.

After the demo, the owner set a longer arc, with Cookie Clicker as the reference. The game starts out looking nearly normal, with only a slight dark undertone. Through a playthrough, and over many playthroughs, it gets darker and stranger until it is full cosmic horror. Villager memory adds to this: each run, a family's portrait changes with what that family remembers of you.

## Choice

1. **Corruption is a third axis, and it never goes down.** It has two parts:
   - **Run corruption** rises as the current run goes on.
   - **Profile corruption** rises with runs played. It is stored in the profile save and is never reduced.

   Together they set a baseline stage for the whole presentation, and the meter layers sit on top of it. A first run at high Famine looks gaunt but is still mostly propaganda. A late profile at low meters still looks wrong.
2. **Art comes in stages.** Each key asset gets a variant per corruption stage: backdrops, card back, Cadre art, paper and UI chrome. Shader parameters blend continuously between stages.
   - The opening stage is propaganda with one wrong detail.
   - The final stage is the unplaceable cosmic horror of ADR 0015.
   - The current demo art is a late-stage reference. The opening stages still need their own art.
3. **Portraits come from memory.** A family's memory record of the player picks that generation's portrait expression: grudge, debts and favours owed, and what you did to them. Corruption distorts whichever face is chosen. To keep the art count manageable, each family has one base face, a few memory expressions, and corruption applied as overlays or shader work. A full set of variants per family, expression and stage would be too many.
4. **The horror-layer rules still hold.**
   - It never lies about game state.
   - Changes land at run starts and round boundaries.
   - The horror-intensity setting caps how much corruption is shown.
   - ADR 0015's never-used list still applies.

## Open questions, to settle when the full game exists

- Which progress counts toward each part, and the curve of each.
- How many stages there are.
- Whether some endings speed up profile corruption.
- Whether anything except a new profile resets it.
- Whether stage thresholds unlock content or endings.

## Consequences

- P3B.12 (dread layers) takes corruption as an input under the meter weights.
- The profile save stores profile corruption.
- P4.5 and P4.17 feed each family's memory record into portrait choice.
- P3C.1 (style bible) defines the stages before any large-scale art generation, because stages multiply the art budget.
