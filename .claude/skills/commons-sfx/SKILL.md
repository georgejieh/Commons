---
name: commons-sfx
description: Source, design, render and check sound effects for Commons, from CC0 and royalty-free libraries or by synthesis, with license tracking. Use for sound effects, SFX, foley, UI sounds, ambience, audio feedback, drones, or auditing game sounds. Not for music, which is commons-bgm, or villager voices, which are P3B.13.
---

# Commons sound effects

You cannot hear. Measurements catch technical faults, and they cannot tell you whether a sound is good. So use tested sources, measure every file, and hand the user a preview. Never call a sound good before the user has listened to it. Their verdict outranks every metric.

## The sound of the game

Commons is a table in a village, heard close up. Sounds are paper, card stock, wood, ink stamps, grain, cloth and small rooms. It is not a casino, an arcade or a horror film.

- **Grounded first.** Most sounds should be recorded material. A stamp is a real stamp on real paper.
- **Dry and close.** Small room at most. A large room is reserved for the landlord's isolation.
- **Weight comes from scale.** A Bomb is a hard slap of cards with a low thud, and a Rocket is that and more. No explosions, lasers, sirens or arcade coins.
- **Scoring is a ledger.** Pen scratches, stamps and paper turns, with a small rising pitch across a run of entries instead of casino chimes.
- **Absence over spectacle.** Silence is a sound. When in doubt, take sounds away.

## Sensitivity limits

These follow the plan's guardrail and apply on every horror setting.

- No screaming, crying, retching, beatings, gunshots or sounds of bodies.
- No sounds of starving people. The plan's stomach-like low drone stays an abstract drone.
- No recorded slogans, loudspeaker speech or real political audio. Any speech is P3B.13 gibberish.
- Crowd murmur stays wordless and never sounds like a mob attacking someone.
- No flashes of loud noise to startle the player. The horror creeps.
- Whispers and crowd murmur use invented, voice-bank material from P3B.13, so no recorded voices and no imitation Mandarin.
- The horror-intensity setting scales every horror sound. Effects take part in the P5.5 sensitivity read.

## Choose a source

Use the first one that fits. Check each pack's own license file when you take from it.

| Order | Source | Use for | License |
|---|---|---|---|
| 1 | Kenney audio packs | UI, cards, simple foley | CC0, no attribution |
| 2 | Sonniss GameAudioGDC bundles | Realistic foley and ambience | Royalty-free, no attribution; limits below |
| 3 | Freesound, CC0 only | Specific materials | CC0 |
| 4 | Synthesis with `scripts/sfx.py` | UI ticks, drones, abstract cues | Yours |

Synthesized foley tends to sound like a toy, so start paper, cloth, wood and footsteps from recordings. Synthesis is a good sweetener on them.

**Licenses we do not use:** anything with NC or SA terms, and Sampling+. A donation button may count as earning money, so NC is out. CC BY needs the user's approval and a credits entry. No AI-generated sound effects without the user's approval, because they add disclosure and rights questions.

**Sonniss rules (GDC bundle license, version 2.0, effective 2026-08-27; the sound store has a different license):**

- The license published on the download date applies, and it overrides an older copy in the archive. Save a copy with the download date.
- Sounds may ship inside the finished game.
- Never redistribute them as sounds, and that includes modified versions. Keep raw and derived standalone files out of any public repository.
- The license bans AI training. Our stricter project rule: do not feed them to any AI audio tool.

**Freesound care:** CC0 is only as good as the uploader's claim. Skip uploads that sound lifted from a film, game or commercial library. `freesound.py` needs a free `FREESOUND_API_KEY`, which the user sets themselves. Never ask for the key in chat. It downloads the HQ preview, an OGG, so check it holds up before relying on it.

**Downloads:** large packs are the user's call. Name the file, source and size before downloading. Put each pack in its own folder under `audio/sources/raw/`.

## Log every sound

Every shipped file gets a row in `audio/sources/manifest.csv`, the shared log for music and effects, with columns `file,type,source,pack_or_url,author,license,plan,model,prompt_or_patch,generated,downloaded,edited`. No row, no ship. Credits go in the game's credits screen if the license asks for them.

## Project layout

```text
audio/sources/SOUND_STYLE.md   sound list, loudness, decisions
audio/sources/manifest.csv     source and license of every file
audio/sources/raw/             downloaded packs, gitignored
audio/patches/<name>.json      synthesis patch, the editable source
audio/preview/                 scratch listening files, gitignored
audio/sfx/<name>.wav           final files the game loads
```

Create `SOUND_STYLE.md` from `templates/SOUND_STYLE.md` the first time, and fill it from this skill and the event list in code. Add one line under Decisions each time the user rejects or changes a sound, so the next sound does not repeat it.

## Tools

Python scripts live next to this file. Run them with `py` through the Bash tool, and quote paths, because the user's home folder contains a space. They are vendored unmodified at a pinned commit (see `NOTICE.md`), so do not edit them; they ship nowhere.

| Script | Job |
|---|---|
| `scripts/doctor.py` | Measure level, loudness, brightness and faults. `--png` draws a spectrogram |
| `scripts/sfx.py` | Render a JSON patch of synth and sample layers. Read `references/synth.md` first |
| `scripts/slice.py` | Cut clean single hits out of a recording |
| `scripts/preview.py` | Lay sounds out in sequence for listening |
| `scripts/freesound.py` | Search and fetch CC0 recordings. Needs `FREESOUND_API_KEY` |

`recipes/` holds two tested patches to start from. `ffmpeg` is not installed, so `doctor.py` and `slice.py` read only standard WAV files until the user approves installing it. Patches and the doctor report LUFS on every sound; for short sounds, treat that as a rough guide under the rules in the loudness section.

## Workflow

1. **Find the event.** Name the game event and how often the player hears it. A sound heard 500 times a run must be quieter, shorter and softer than one heard once.
2. **Pick the source** using the order above. Audition by listing candidates; the user picks by ear.
3. **Shape it.** Trim, fade and match loudness. For recordings use `slice.py`. For layered sounds use a patch. Keep each sound short: UI 15 to 80 ms, card and stamp actions 80 to 300 ms.
4. **Make variants** for anything frequent, ideally four real takes rather than one pitched four ways. Play them round-robin. Runtime pitch variation is cosmetic, so it uses the `cosmetic` random stream.
5. **Check it.** Run `doctor.py <file> --png` and review each FAIL and WARN in context, because silence and drones can trip generic checks. A one-shot has its attack at the start and a tail that dies away. A loop does not.
6. **Hand it over.** Give the user a sequence or file path to listen to. Change one thing per pass, and describe it in sound terms.
7. **Wire it** to the named audio event on the sound-effects bus, using `audio-design` and `godot-audio`.

## Loudness ladder

These are relative priorities, loudest first: hero (Bomb, Rocket, Quota met or failed), gameplay (card played, deal, score entries), UI (hover, click, menu), ambient loops (room tone, drones).

LUFS meters use 400 ms and longer windows, so they mean little on a 15 ms click. Do not force short sounds to a LUFS number. Set their balance by peak level and by ear, with sounds repeating in context, and use runtime gain for the final mix. Keep file peaks at or below -1 dBFS, and put a limiter on Master because sounds add up. Overall loudness is measured on representative gameplay; see `audio-design`.

## Delivery

WAV, 16-bit, 44.1 kHz, mono by default. Use stereo where width helps, such as ambience. Set loop mode for loops in Godot's Import dock. Short effects stay WAV. Long ambience can be OGG.

## Horror states

Board-state sounds are data in the dread layers (P3B.12). They fade in, mostly at round boundaries, and never change what a sound tells the player about game state. A Bomb stays recognizable at every horror level, and legal-move and error sounds never change meaning.
