# ADR 0022: Cheating, unofficial builds and the licence after v1

## Status

Two parts, decided differently:

- **The design of the two systems** is accepted, 2026-11-14, under the design authority the owner gave that day. They are scheduled as P4.19 and P5.8.
- **The licence** is proposed. It is the owner's decision, it is hard to undo, and nothing changes before v1 ships. The repository stays proprietary until then.

This is background for the owner, not legal advice.

## Context

The owner asked for three things on 2026-11-14:

1. After v1, a permissive licence: anyone may change the source and do what they like with it, with proper attribution.
2. A build that is not the official one should say so in the game and point at the original, so attribution appears even when a modder leaves it out.
3. Cheating is never blocked. The game is offline and single-player. It should notice, warn the player and answer inside the game, with something funny or malicious. Only deleting the save resets it.

What research found, with the limits stated plainly:

- **Code cannot enforce any of this.** A signature shows that the checked bytes match one made with our private key. Someone who changes the program can remove the check, or swap in their own public key. So a check can only tell "signed by us" from "everything else".
- Godot can verify a signature at run time. `Crypto.verify` takes a hash type, a hash, a signature and a public `CryptoKey`, and `FileAccess.get_sha256` hashes a file. Godot's own documentation suggests this pattern for patch packs. We use an RSA key and pass SHA-256 explicitly.
- A build made with a release export template can be told apart with `OS.has_feature("template") and not OS.is_debug_build()`.
- I found no documented call that returns the running pack's path. The Linux export has its pack beside the executable, both inside the AppImage we ship, and the Windows export embeds it, so the Windows check hashes the executable.
- Godot's pack encryption needs custom-built export templates, and the key ships inside the binary. It is a poor fit for an open project and is not used.
- A memory editor such as Cheat Engine works by scanning for a known value, narrowing the matches as the value changes, and writing to the address left. Light answers include a hidden second copy of each value that must agree with the first, a decoy, and a checksum on saves. They catch simple edits. They do not stop someone who controls the program and its files.
- Games have answered cheats and piracy inside the fiction before. Game Dev Tycoon's developers released a cracked copy in which the player's studio is ruined by piracy, and Serious Sam 3 had a check that could send an unkillable scorpion after players of unauthorized copies.

## The unofficial build

**The seal.** The release workflow hashes what it exported and signs the hash with a private key held as a repository secret. The signature ships beside the game, and the public key is in the source.

At start, on a thread, the game hashes itself and checks the signature. A build is one of three things:

| Build | How it is known | What the player sees |
| --- | --- | --- |
| Official | Release build, signature matches | Nothing extra |
| Unofficial | Release build, signature missing or wrong | A paper tag on the title screen and a line in the credits: "This is a modified version of Commons. The original is at" and the link |
| Development | Run from the editor or a debug build | Nothing extra |

An unofficial build plays exactly like an official one. Modding is welcome once the licence allows it, and the tag is information, not a penalty.

The text and the link ship in the source, so a fork that changes nothing else credits the original by itself. A modder who removes the tag has taken a deliberate step. Whether that breaks the licence depends on the licence chosen below: under Apache or MIT it does not, as long as the attribution is kept somewhere.

## Cheating: the books

The fiction already has the answer. In the Great Leap Forward, officials inflated their grain reports, and those reports helped persuade the centre to set grain demands far too high. The game does the same: **it never refuses a false figure. It accepts it as official, and plans from it.**

**Three ways the game notices**, all in `game/`, so `core/` stays pure:

1. **The second book.** After every command the controller keeps a masked copy of the figures that matter: coupons, Quota progress, Famine, Denunciation, Resentment and the norm. Before the next command it compares. A difference means something changed the numbers while nobody acted.
2. **The seal on the save.** Saves carry a keyed checksum. The key is in the source, so it stops hand edits and nothing more. A save that fails the check still loads if its shape is valid.
3. **The bait.** The save folder holds a plain text file, `private_ledger.txt`, with one line: the household's coupons. Change the number and the game takes it.

**What happens**, the first time and every time after:

- A notice takes the screen, in the state's voice: the brigade's books and the household's did not agree, the brigade's books have been corrected to match, and the household is congratulated on its results.
- **A raised figure becomes the plan.** If progress or coupons went up, the norm is raised to match what was reported, so every later Quota is set from the false result. Shop prices rise by the same proportion as the coupons did.
- **A lowered meter goes dark.** If Famine, Denunciation or Resentment went down, the screen shows the reported figure from then on, as "None reported". The true meter returns to what it was and keeps counting where the player cannot see it. Setbacks and deaths arrive without warning.
- **An entry goes in the file.** The profile save records it. The file follows the family into every later run.

**While the file has an entry:**

- Every run starts with the norm already raised, 10% for each entry, up to double.
- Villagers have lines about the work team's visit, and the title screen carries the file's stamp.
- Corruption (ADR 0018) gains a stage that cannot be reached any other way, past the last one: every figure the screen shows is a success, and the true ones appear only in the small ledger.

**The only reset** is deleting the profile save.

**False alarms are the real risk**, because the penalty is permanent. So:

- The second book is resealed on every load, replay and migration, and compared only between commands on the same run.
- The whole test suite, the cloud playtest, the tournament and the balance harness run with the detectors on and must record zero entries.
- A development build logs a mismatch and does nothing else.
- A save from before this feature has no seal and is not an offence.

## The licence after v1

Apache-2.0 and MIT, the two common permissive licences, do not make a modified build show anything inside the game. One little-known permissive licence does. The tag is built into the code either way.

| Choice | What a fork must do | What it costs |
| --- | --- | --- |
| **Apache-2.0 for code, with a NOTICE file. CC BY 4.0 for art, music and text. A short trademark policy for the name and logo.** Recommended. | Pass on the licence. Mark changed files as changed. Keep the copyright and attribution notices in the source, and reproduce the NOTICE attributions in a NOTICE file, the documentation, or a credits display. The licence gives no permission to use the game's name or marks beyond saying where the work came from. | The in-game tag is a default and a request, not a term. A fork may move the credit to a file. |
| Attribution Assurance License (AAL) for code, the rest the same | Show the author's name and link prominently each time the program starts. It is OSI-approved and is not copyleft. | It is the only option here that makes the on-screen credit a term, and it is obscure: OSI files it as redundant with more popular licences, and few people will have read it. |
| MIT for code, the rest the same | Keep the copyright line and the permission notice in copies. | It needs no NOTICE file and says nothing about trademarks. |
| CPAL-1.0, or GPLv3 with an added attribution term | Both can require attribution in the running program. | Both are copyleft: a fork must publish its source under the same licence. That is not "do what you like". |

Things to know before choosing:

- **The credits screen should print the NOTICE attributions.** That is one of the places Apache allows, so a build made from the source carries them without anyone doing anything. Showing them does not cover Apache's other conditions.
- **AAL is the literal match for the request**, if the on-screen credit must be a condition and not a default. Apache is the safer, better-understood choice. The tag and the seal work the same under both.
- **Art and music made with AI may carry little or no copyright.** In US law, purely AI-generated expression is not protected. The Copyright Office's position is that prompts alone do not make an author, and that human selection, arrangement and editing can be protected case by case. Where an output has no copyright, CC BY creates no duty to credit. Creative Commons advises against putting its licences on public-domain material, so license the human contributions and say plainly which assets are generated. Keep the records of the human edit pass (P3C.7).
- **Creative Commons advises against its licences for software**, and names game art and music as a fit. Code and assets get different licences, which is normal.
- **A sole rights holder can offer the work under new terms.** That does not withdraw licences already given, and it does not cover third-party fonts, engine code or add-ons, which keep their own. Outside contributions complicate a later change unless their terms already allow it, so decide whether contributors sign an agreement before accepting any.
- **Opening the source cannot be taken back** for the versions released under the new licence.

## Consequences

- P4.19 builds the detectors, the notice and the consequences, after P4.14 gives it the profile save.
- P5.8 builds the seal, the tag and the signing step in the release workflow. The owner creates the signing key and adds it as a repository secret.
- P5.9 is the owner's licence decision, after v1.
- Saves gain a checksum, which is a schema change.
- `docs/ARCHITECTURE.md` gains both systems when they are built.

## The books as built (P4.19, first half, 2026-11-16)

Calls made while building, which the section above did not settle:

- **A changed figure is a command.** A save is a checkpoint and the commands since. The detector puts the true figures back and sends a `books` command with what it found, so the correction is in the record and a reload replays it.
- **What a raise is.** A raised coupon figure raises later targets and both shops' prices by reported over true, a true count of none taken as one. A raised progress figure raises later targets by the gain as a share of the target in force. Raises compound over corrections and round up. They are kept as their own percentages, apart from overfulfilment's steps.
- **Later Quotas only.** A correction made during a Quota raises the targets of the Quotas after it, never the one in play.
- **Caps, as data:** corrections raise targets and prices by at most 900% each over a run; reported coupons stop at 999,999 and reported norm steps at 999, and progress at the largest score the game holds.
- **Prices** means every price in both shops: rerolls and the plot upgrades too.
- **A lowered coupon or progress figure** is accepted and is still an offence. **A raised meter** is accepted with all a real rise brings; one raised to its limit ends the run as that meter does. **A lowered norm** goes dark as a meter does.
- **A broken seal** has nothing to correct: it is an entry and a notice. A hand edit of the profile that empties the file costs one entry for the broken seal. The key is in the source, so the seal stops hand edits and nothing more, as this ADR says.
- **The bait** is held to the number the save last wrote there and the one before it, since a crash can fall between the two writes. It is not checked before a run's first save, or beside a save restored from its backup.
- **Each entry adds 5 corruption**, growing as every corruption event does, and raises a later run's targets 10%, up to double.
- **Who can get an entry:** a full run with a profile, in a release build. The demo, the arrival, the balance harness, tools, tests and every development build log one line and change nothing.
- **For P5.0:** when Expert's search leaves the command thread, the second book must be sealed again after its play is applied.

## Limits found in review (2026-11-17)

The Phase 4B review read the detectors for false alarms. Three points stand as they are, on purpose or for now:

- **A norm reported higher counts at once.** "Later Quotas only" above is about what a correction adds. A figure the household reports against itself is taken as presented, so a higher norm raises the target of the Quota in play, as a higher Famine counts at once.
- **Two copies of the game writing one save at the same instant** can leave one copy's save beside the other's ledger, and the next command then files a ledger entry nobody earned. One copy after the other is handled: each reads the save on disk before it judges. Both at once needs two commands inside the few milliseconds between a save and its ledger. No lock stops a second launch yet; release readiness (Phase 5) should add one.
- **One of the two files put back alone**, by hand from a copy or by a folder sync that restores an old ledger, reads as a changed ledger. That is a file changed from outside the game, which is what the ledger is there to see, but a player who only restored a backup did not mean it. Left for the owner's call.

## The screen as built (P4.19, second half, 2026-11-17)

- **One notice for the whole app**, over whatever screen the player is on, built from live events only. It shows the first time and every time, and play waits until it is acknowledged.
- **A dark figure's true value is never printed**, in the notice either: its line gives the reported value alone.
- **A dark norm hides the Quota's target, the bar's fill and its seal.** The progress still shows.
- **A dark meter gives no cue of any kind:** no bar, no pulse, no sound, no dread on the board, no change in the music. The setback or the death still plays.
- **The stage past the last** needs an entry in the file and corruption at its last stage; corruption alone never reaches it, and horror intensity, which caps the art, does not cap it. There the Quota reads "Fulfilled ahead of plan", coupons "Ample supply" and every meter "None reported", and a Quota truly missed is recorded as fulfilled on its report. The small ledger shows the figures at the table and in both shops, with a figure that went dark still dark there.
- **The title's stamp** names the household's file and how many entries it holds. **The history screen** lists them, oldest first, and says the file is kept. Nothing in the game says how to clear it.
- **Villagers' lines** about the work team ride a pass, at a chance of 0.04, in a run that began with an entry.
