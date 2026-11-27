# ADR 0019: What reeducation does

## Status

Accepted, 2026-11-05. The project owner chose A with 1.

## Context

The Plan says that at mid Denunciation "you are sent to reeducation for a Set: you lose your private plot and return changed". The checklist says the same: "sends you to reeducation for the next Set (lose the private plot's contents, return with a changed modifier)".

The documents leave two questions open:

1. **What is missed.**
   - Sitting out a whole Set is one reading. The P3B.9 shell copy took this one.
   - The run-state table reads differently. `SET_END → REEDUCATION → SET_INTRO`, recorded in ARCHITECTURE.md, treats reeducation as taking the place of the shop visit after a Set.
2. **What "changed modifier" means.** Nothing in the Plan defines it, and no reeducation content exists yet.

## Options

**What is missed:**

- **A. The shop visit.** Reeducation takes the place of the store after the Set in which Denunciation crossed mid. The next Set is played as normal.
- **B. A whole Set.** The next Set is skipped. It pays nothing, and missing its Quota costs nothing. When the skipped Set is the boss, the Year ends. This is harsher, and it changes what the Year's Sets mean.

**What changes:**

- **1. One held Cadre is exchanged.** It is swapped for a Cadre the player does not hold, drawn at random and placed in the same slot. Nothing happens when the player holds no Cadre.
- **2. A reeducation mark is added.** This is a permanent debuff-like modifier, drawn from a new pool. It needs authored content (P4.11 or P4.12).
- **3. Nothing changes beyond the lost plot.**

## Choice

**A with 1**:

- It matches the run-state table that is already built.
- It uses content that already exists.
- It keeps "return changed" in the game itself, not only in its text.

The exchange is drawn on the `events` stream.

## Consequences

- `RunLoop.open_shop()` enters `REEDUCATION` in place of `SHOP` when reeducation is owed. It then waits on `Awaiting.REEDUCATION`, and `next_set()` leaves.
- `Reeducation.change_cadre` holds the exchange rule, so a different choice changes one function and the screen's copy.
- Choosing B means changing `next_set()` so it skips a Set, plus the Year's reward rules.
- Choosing 2 means adding a modifier pool and a field in `RunInventory`.
