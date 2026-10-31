---
name: commons-bgm
description: Plan background music for Commons and write Suno prompts the user can paste, with style text, Exclude Styles, section tags and settings. Use for BGM, soundtrack, music cues, Suno prompts, music loops, stems, fixing a Suno result, and planning which tracks to download. Not for sound effects or villager voices.
---

# Commons background music

The user generates music in Suno on a Pro plan. Claude writes the prompts and plans the set, and the user generates, listens and downloads. Claude cannot hear, so never call a track good until the user says so.

Suno facts here were checked on 2026-10-30. Suno retired every older model on 2026-09-09 and changed its terms and download caps around then. If more than a quarter has passed, re-check the facts in "Suno facts" before relying on them.

## What the music must do

Music follows the board. It starts as warm, sincere village life, because the player must feel the idealism first. As the run decays it loses players rather than turning scary.

| Board state | Music |
| --- | --- |
| Both meters low | Warm folk melody, full small ensemble, unhurried and kind |
| Famine mid | The same melody, slower, fewer instruments |
| Famine high | One instrument, long silences |
| Denunciation mid | The same material, thinner and watchful |
| Denunciation high | Near stillness, room left for whispers and a slow clock, which are sound effects |
| Both high | Almost nothing. A crowd murmur that stops when the player plays is a sound effect |
| Landlord, any meters | Richer but hollow: the warmth is gone and the room is too large |

When landlord overlaps a high meter, the meter sets how much plays and the landlord sets the arrangement and room.

Stay out of the way of the sound layer. Drones, whispers, ticks, footsteps and crowd murmur belong to `commons-sfx`, so do not ask Suno for them.

## Production design

**Use stems for thinning, and separate cues for slowing.** One song split into stems stays in sync, so the game can fade instruments out as the board decays. Godot's `AudioStreamSynchronized` plays them together: keep faded layers running at zero gain so they return in the right place.

Muting cannot do everything. It cannot slow a melody or add rests, so "slower" and "long silences" need their own cues or edited arrangements. Stems also separate imperfectly. Pro's Auto Split gives up to 12 categories, and Split from Mix takes one instrument at a time. Picking from nearly 100 instruments needs Premier, and extraction costs credits. A solo layer can expose leakage that the full mix hid.

Build the score from a few masters:

1. **Village master:** the warm ensemble loop. Its stems cover the clean board and both decay paths.
2. **Landlord master:** the same key and melody idea, reharmonized.
3. **Decay cues:** slower and sparser versions for Famine, which stems cannot produce.
4. **One-offs:** title, tutorial, each shop, boss Sets, quiet ending cues.

Test one master before writing the rest, and listen to every planned reduced mix and the fades between them. If stems fail, fall back to separate tracks. Prompted BPM and key are only requests, so measure the audio, mark downbeats and phrase lengths, then use `AudioStreamInteractive` for transitions on a beat or bar.

**Lock a family.** Every cue states the same key and BPM unless it has a reason not to. Record them in `audio/music/CUES.md`, along with each final prompt, settings and the Suno track link.

**Loops take editing.** Suno does not guarantee a seamless loop, so a track may need several generations before one works; say so up front. Stems of one master must share one timeline and one loop interval, so never trim them separately or remove their leading silence. Fading both ends causes a recurring dip. Godot sets WAV `loop_begin` and `loop_end` in samples, and Ogg `loop_offset` in seconds. Listen to several full cycles of every mix.

## Suno facts

Stated by Suno:

| Item | Current rule |
| --- | --- |
| Model | `v6` for finals. `v6-wild` only to explore a sound |
| Variety | 0 (Off) for every engineered prompt, or Suno may rewrite the style text |
| Max Mode | Suggested for songs over two minutes. Costs more credits |
| Artist names | Never. Suno replaces them. Describe the sound |

Community findings, to treat as things to try:

| Item | Working practice |
| --- | --- |
| Instrumental | Use the switch and an `[Instrumental]` tag together. The switch alone can still produce vocals |
| Duration | About 10 s to 6:00 is a target, not a guarantee, and can cut abruptly |
| Style text | One plain sentence, roughly 300 to 400 characters, with the most important words first |
| Negatives | Use Exclude Styles. "No drums" in the style text can summon drums |
| Lyrics box | Section tags only. Text in parentheses can be sung |

**Downloads are the budget.** Pro gets 20 song downloads a month, reset on the billing date, and unused ones expire. One song plus all its stems counts once, and re-downloading is free. Extra downloads can be bought. So listen in Suno first, keep a list of keepers, and download only final picks. Spread the work over months if needed, and warn the user when a plan exceeds 20.

**Commercial rights follow the download.** Download through Suno's approved channels while subscribed. Rights in qualifying downloads survive cancellation. Suno's Remix feature, which uses other users' songs, is not commercial, so stay out of it. Editing our own tracks is a different matter. Suno promises no copyright in its output.

## Writing a prompt

**Style sentence, in this order:** genre and setting, mood in one or two words, three or four instruments, the performance or room, tempo, key, and "instrumental".

Each word must add a decision. "Sad, melancholy, sorrowful" is one idea stated three times. Say how the music behaves rather than how it feels: "the melody stops short and waits" beats "haunting".

**Exclude Styles:** a short list of bare musical terms, without "no". Add only what this cue would otherwise attract. The usual starters are `vocals, humming, vocalise, choir`; add `drums` when a cue has a reason to exclude them. Add more only after a result shows the problem.

**Lyrics box:** tags with short performance cues, and no prose.

**Loops:** ask for steady material with no clear beginning or end. "Unresolved" may stop the model writing toward an ending. Skip `[Intro]` and `[Outro]`.

**Layers:** for a stem master, name distinct instruments in different registers. This helps separation but does not guarantee it.

## Sound and sensitivity

- Erhu, dizi, pipa, yangqin and sheng are all fair choices, in plain arrangements with one or two lead voices. A list of instruments is not a setting, so decide the ensemble once for the whole score and review it by ear.
- Avoid the stock caricature riff and "oriental" or "exotic" as style words. Pentatonic writing itself is fine, and a restrained gong can be too.
- No real anthems, revolutionary songs or model-opera melodies, as project policy. They carry political weight, and rights vary. Do not name them in a prompt, even as a reference.
- Leave choirs out by default, to keep space for the voices. Use one only if the user wants it.
- Early cues stay sincere. Do not make the warm cues secretly sinister.
- Avoid horror clichés: music-box lullabies, detuned children's choirs, reversed cymbals, sudden stingers. The plan's horror is absence.
- Music takes part in the P5.5 sensitivity read.

## What to return

Return each cue in this format, ready to paste:

```text
CUE: <id, board state, how the game uses it>
MODEL: v6 | VARIETY: 0 | MAX MODE: on or off | INSTRUMENTAL: on | DURATION: <target>
WEIRDNESS: <value> | STYLE INFLUENCE: <value>

STYLE:
<one sentence>

EXCLUDE:
<comma list>

LYRICS BOX:
<tags only>

LISTEN FOR: <what decides keep or reject>
```

Start Weirdness at 30 to 45 and Style Influence at 80 to 90 for instrumentals. These are community starting points, so adjust them from results.

## Fixing a result

Change one thing per pass, and ask the user what they heard.

| Problem | Fix |
| --- | --- |
| Style ignored | Check Variety is 0, then shorten the style sentence |
| Humming or vocals | Add to Exclude Styles, confirm the switch and tag |
| Too busy | State density, and name fewer instruments |
| Too slow or too long | State BPM and duration. v6 is reported to lean slow and long when left open |
| Wrote an ending | Add "unresolved", remove closing tags, or trim the file |
| Too cinematic | Exclude `cinematic, orchestral, epic`, and name a small room |
| Generic "Chinese" pastiche | Remove the instrument list down to one lead, describe the room and the players |

## After the user picks a track

1. Confirm it fits the download budget, then ask the user to download it, with stems if it is a master.
2. Put files in `audio/music/` and log them in `audio/sources/manifest.csv`, the shared log for music and effects, with columns `file,type,source,pack_or_url,author,license,plan,model,prompt_or_patch,generated,downloaded,edited`. Record both the generation and download dates. This supports the itch.io AI disclosure.
3. Trim, set loop points, and match loudness on the music bus using `audio-design`.
4. Use `godot-audio` for playback. The user judges the loop by ear in the game.
