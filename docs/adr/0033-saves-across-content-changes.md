# ADR 0033: A save from other content resumes at its Quota's start

- Status: Accepted, 2026-11-17, by the agent. Both reviewers of Phase 4B raised it independently; the owner judges by playtest.
- Scope: what happens to a run save when the game it is loaded by is not the game that wrote it.

## Why this needs a decision

A run save is a checkpoint and the commands since (`RunRecord`, in `docs/ARCHITECTURE.md`). The checkpoint is the whole run at the start of a Quota, or at its end. Everything after it is rebuilt by sending the commands again: the deal, the debuff ladder and both shops' stock are drawn again from the run's streams.

A command names a slot: "buy the Cadre in slot 1". That is true only against the pools the command was made with. The second content wave ([ADR 0032](0032-second-content-wave.md)) added 16 Cadres and 3 Campaigns to tiers a run already had open. A save made in the store the day before then replays its purchase against a different shelf. It either buys a Cadre the player never chose, with no sign that anything changed, or it sends a command the run refuses, and Continue fails for good.

No release has shipped, so no player has such a save. The game is meant to grow by expansions, and each one would do this to every save made mid-Quota or mid-shop.

## Decision

**A save is stamped with the content it was written against.** The stamp is the game's version and a hash of everything a run draws by slot: every definition in the Cadre, Campaign, Directive, Reform and debuff pools, with its plain values, and the numbers that size both shops, the ladder and the plot counter. It is kept beside the save, under its seal, as the ledger's numbers are. `ContentStamp` (`game/run/content_stamp.gd`) makes it.

**A save whose stamp is not this build's resumes at its checkpoint.** The commands since, and the villagers' decisions written for them, are left out. The run stands at the start of its Quota, or where the Quota ended if the save was made in the shops, with everything it held then. A save with no stamp, from before this ADR, is treated the same way.

**A save whose commands no longer apply resumes at its checkpoint too.** Replay can still fail between two builds of one version, when a rule changed and the data did not. Continue used to fail then. Now it falls back to the checkpoint.

## What the player loses

At most the Quota in play, or the purchases of one shop visit, and only on the first Continue after an update. Coupons spent in that visit come back with the checkpoint, so nothing is paid for twice.

## What this does not cover

- **A definition that is removed.** A checkpoint names what the household holds by ID. Content is added and tuned, never removed or renamed; a removal needs a migration of its own.
- **The checkpoint itself.** Its fields are covered by the schema version and the migrations, as before. Run saves stay at schema 18: the stamp sits beside the data, not in it.
- **Tampering.** A player who edits the stamp gets what the stamp is for, a restart of the Quota. The seal already answers edits to a save ([ADR 0022](0022-the-file-and-unofficial-builds.md)).

## Alternatives rejected

- **Saving every shelf's stock in the checkpoint.** It fixes the shops and nothing else: the ladder, the deal hooks and every tuned number still replay differently. It would also need a schema change for each new kind of shelf.
- **A version number alone.** Two builds between releases share a version, and those are the builds the owner playtests.
- **Refusing the save.** A run of several hours is worth more than one Quota.

## Consequences

- `RunController.resume_saved` reads the stamp before it replays. `RunRecord.resume` is unchanged and still returns null on a command that does not apply.
- The first Continue after any change to a pool or its numbers restarts the Quota in play. That includes every balance pass.
- `tests/integration/test_content_stamp.gd` covers a save of this build, one of another, one with no stamp, a round in play, a command that no longer applies, and what the stamp reads.
