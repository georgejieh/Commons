# ADR 0018: Hidden corruption, and portraits from memory

## Status

Direction accepted by the project owner on 2026-11-04, and refined the same day. Implementation is deferred until the full game exists, because the effect can only be judged across a whole playthrough and many runs.

## Context

The Plan's horror layer follows the Famine and Denunciation meters. Those rise and fall within a run, so the board can recover. The ADR 0015 amendment then made every asset propaganda distorted by cosmic horror from the start.

After the demo, the owner set a longer arc, with Cookie Clicker as the reference. The game starts out looking nearly normal, with only a slight dark undertone. It gets darker and stranger as harm builds up over a playthrough and across playthroughs, until it is full cosmic horror. Villager memory adds to this: each run, a family's portrait changes with what that family remembers of you.

## Choice

1. **One hidden value, kept across all runs.** Corruption runs from 0 to 100% and lives in the profile save. It is one value for the whole profile, not one per run, so harm from earlier runs carries forward.
2. **Only harm the player causes raises it.** Each negative event caused by the player adds corruption. The same act by an AI villager does not count. The draft list, from the Plan's mechanics, to confirm when those systems exist:
   - over-declaring need at the Commons split;
   - free-riding: drawing from the Commons while banking little into it;
   - bombing your own teammate;
   - hiding grain in the private plot while Famine is high;
   - a villager starving while you hold a surplus;
   - denouncing a villager, or deposing one;
   - entrenching as landlord across Sets.
3. **The curve is exponential, with heavier events.** Each event adds `weight × (1 + growth × corruption)`. Early harm moves the value slowly, and the same harm moves it faster as corruption builds. Severe events, such as a death or a denunciation, have larger weights than petty ones. Weights, growth rate and the event list are tunable data.
4. **The look changes every 10%.** That gives ten stages:
   - Stage one, below 10%, is propaganda with a slight undertone and one wrong detail.
   - The last stage, 90% and up, is the full unplaceable cosmic horror of ADR 0015.

   Each key asset has a variant per stage: backdrops, card back, Cadre art, paper and UI chrome. Shader parameters ease between stages. A stage change lands at a run start or a round boundary, so the player notices it afterwards rather than watching it happen. The current demo art is a late-stage reference, and the early stages still need their own art.
5. **The meter layers sit on top.** Famine and Denunciation still decay the board within a run, as the Plan describes, starting from the current corruption stage. A first-profile run at high Famine looks gaunt but is still mostly propaganda. A deeply corrupted profile at calm meters still looks wrong.
6. **The collective win resets it.** The rare variant of The Secret Contract, in which the village never needed the contract, resets corruption to 0. That is the mostly collective run that survives Year 8 with both meters in check. Starting a new profile also resets it. Nothing else lowers it.
7. **It stays hidden.** No bar, number or hint shows corruption to the player. Builds for release expose it nowhere. Development builds get a debug override so each stage can be checked.
8. **Portraits come from memory.** A family's memory record of the player picks that generation's portrait expression: grudge, debts and favours owed, and what you did to them. The corruption stage distorts whichever face is chosen. To keep the art count manageable, each family has one base face, a few memory expressions, and per-stage overlays or shader work. A full set of variants per family, expression and stage would be too many.
9. **The horror-layer rules still hold.**
   - It never lies about game state.
   - The horror-intensity setting caps how far corruption is shown.
   - ADR 0015's never-used list still applies.

## Amendment, 2026-11-12: ending music follows the corruption stage

The project owner chose where the game's one vocal song goes. "Mandate In Ashes", an existing song by the owner's band Submontane, plays over the ending screens of a deeply corrupted profile. It is not an unlockable and has no menu of its own.

1. **Ending music is a stage asset.** The music over the ending, epilogue and credits screens has variants by corruption stage, like the assets in point 4. Early stages get a quiet cue that keeps the propaganda surface. The late stages get "Mandate In Ashes". The draft threshold is stage 8 and up, and it is tunable data.
2. **The epilogues carry the credits.** The ending sequence runs the ending card, then the per-villager epilogue lines, then the credits: the owner, the AI tools, fonts, sound sources and licences. That gives a long song enough screen time.
3. **The horror-intensity cap applies.** The setting in point 9 caps the stage used to pick the track, the same as for the art.
4. **Nothing announces it.** No jukebox, unlock message or menu entry appears. A hidden menu was rejected because an entry that appears at a threshold reads out the hidden value, which point 7 forbids, and because it would look like a reward for causing harm.
5. **No extra hint in the game.** The song is used as released. The game adds no notes, subtitles or annotations that explain its references, and its use must stay inside ADR 0015's never-used list on screen.

## Open questions, to settle when the full game exists

- The stage at which the ending music switches, and whether the middle stages get their own cue.
- What plays over the collective ending, which resets corruption to 0.
- Whether the song plays whole, or is edited to fit the ending sequence.

- The final event list and the weight of each event.
- The growth rate, tuned so a typical player reaches the late stages after a planned number of runs.
- Whether the reset is instant, or plays back through the stages.

## Consequences

- P3B.12 (dread layers) takes the corruption stage as its base, under the meter weights.
- The profile save stores corruption, and saves are versioned for it.
- Each listed event must leave a player-caused record that the corruption service can read.
- P4.5 and P4.17 feed each family's memory record into portrait choice.
- P3C.1 (style bible) defines all ten stages before any large-scale art generation, because stages multiply the art budget.
