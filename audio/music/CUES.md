# Commons music cues

The score for P3C.9, following the `commons-bgm` skill. The project owner generates every track in Suno (Pro plan) and listens before anything is downloaded. Claude writes the prompts and wires the game. Suno facts were checked on 2026-10-30.

## The family

Every cue uses the same key and tempo unless it says otherwise, so cues can change on a bar line without a jolt.

| Setting | Value |
| --- | --- |
| Key | G major, mostly pentatonic melody |
| Tempo | 84 BPM, 4/4 |
| Ensemble | Dizi (lead), erhu (countermelody), yangqin (harmony), plucked low strings (bass), woodblock and small hand drum (percussion) |
| Room | A small wooden hall, close and dry |

## Stems and the game

Each master is split into five stems with the same names the game uses: `melody`, `counter`, `harmony`, `bass` and `percussion`. The game plays them together in one `AudioStreamSynchronized` (`game/audio/music_player.gd`), so they never drift. The dread layers thin the music by fading stems by volume only, so a faded stem comes back in step:

| Board | Stems faded | Cue |
| --- | --- | --- |
| Both meters low | None | `village_master` |
| Famine rising | `percussion`, `counter` | `village_master`, then `famine_mid` (layer weight 0.5), then `famine_high` (0.85) |
| Denunciation rising | `melody`, `percussion` | Current cue |
| Both high (struggle) | `counter`, `harmony`, `bass` | Current cue, left nearly empty |
| Landlord, Famine below mid | None | `landlord_master` |

Whispers, the clock, crowd murmur, chatter and room tone are sound effects (P3C.8), not music. The thresholds live in `data/audio/music_score.tres`.

**Loops.** Stems of one master share one timeline and one loop. Never trim them separately or cut their leading silence. Set WAV `loop_begin` and `loop_end` in samples, or Ogg `loop_offset` in seconds, from the measured downbeats, then write the measured BPM into the cue's data. A cue change waits for the next bar line of the cue playing.

## Plan and download budget

The score follows the hidden corruption stage (ADR 0018). Every stage has three cues, and all thirty restate one tune: the stage 0 village melody. The decay comes from losing players, room and resolution. No scary instruments are added.

| Role | Plays | Stems |
| --- | --- | --- |
| `village_sN` | Peasant play. The meters thin it by fading stems | Yes, stages 0 to 5 |
| `landlord_sN` | While the player holds the landlord seat: the same tune, reharmonized, the room too large | Yes, stages 0 to 5 |
| `famine_sN` | High Famine. Slower, with rests, which stems cannot do | No |

A stage with no cue of its own yet plays the nearest earlier stage's cue. Ship stages in order.

One-offs (title, tutorial, state store, black market, boss, ending) come after stage 4.

Downloads: 30 stage cues plus 6 one-offs is 36. Pro allowed 20 a month when checked on 2026-10-30, so allow two months. Generations don't count, so try 4 to 8 takes of each master and download only the keeper.

**Order of work:**
1. Generate stage 0's village master and judge its loop and stems.
2. Generate stage 0's landlord and famine cues against it.
3. Only then start stage 1.

For stages 1 and up, if Suno can make a cover or variation of your own stage 0 keeper that keeps the melody, start from that and paste the stage's style sentence. Your own songs are fine to reuse; the Remix feature on other users' songs is not licensed for commercial use.

## Cue 1, the prototype

```text
CUE: village_master, both meters low, looped under play and split into five stems
MODEL: v6 | VARIETY: 0 | MAX MODE: on | INSTRUMENTAL: on | DURATION: about 2:30
WEIRDNESS: 35 | STYLE INFLUENCE: 85

STYLE:
Warm village folk instrumental for a small wooden hall, unhurried and kind, dizi melody over erhu countermelody, yangqin chords and plucked low strings, light woodblock and hand drum, steady and unresolved so it can loop, 84 BPM, G major, instrumental

EXCLUDE:
vocals, humming, vocalise, choir, cinematic, orchestral, epic

LYRICS BOX:
[Instrumental]
[Verse] dizi carries the tune, erhu answers softly
[Verse] yangqin and low strings keep a steady walk
[Verse] same tune, light woodblock, no build
[Verse] erhu takes the tune, dizi answers

LISTEN FOR: a melody you'd hum after one pass; each instrument clear in its own register (that helps the stem split); steady energy with no intro, outro or big build; no vocals or humming. Then run Auto Split and solo each stem: keep it only if the dizi, erhu, yangqin, low strings and percussion each come out clean enough to play alone.
```

## Corruption stage cues

### Shared settings

Every cue uses these settings unless its row says otherwise:

```text
MODEL: v6 | VARIETY: 0 | INSTRUMENTAL: on
MAX MODE: on (masters), off (famine) | DURATION: about 2:30 (masters), about 2:00 (famine)
WEIRDNESS: 35 for stages 0 to 4, 40 for stages 5 to 9 | STYLE INFLUENCE: 85
```

**Exclude Styles:**
- Stages 0 to 5: `vocals, humming, vocalise, choir, cinematic, orchestral, epic`
- Stages 6 to 9: the same list, plus `horror, dark ambient, drone, music box`. Drones and whispers are sound effects in this game, so they're kept out of the music.

### Lyrics box by role

Use only the tags. Don't add `[Intro]` or `[Outro]`.

```text
village:
[Instrumental]
[Verse] the tune in full
[Verse] the tune again, same energy
[Verse] the tune, no build
[Verse] the tune, unresolved

landlord:
[Instrumental]
[Verse] the tune slowly, low strings hold long chords
[Verse] the tune, the hall rings
[Verse] the tune, no build, no percussion

famine:
[Instrumental]
[Verse] the tune slowly, solo
[Break]
[Verse] half the tune
[Break]
```

### Style sentences

Paste one sentence into Style.

**Stage 0. Sincere.** Tempo 84 (famine 66).
- **village_s0** is Cue 1 above.
- **landlord_s0:** Village folk instrumental in a large empty hall, rich but hollow, the same dizi melody slowed and reharmonized over low plucked strings and long yangqin chords, erhu holding sustained notes, no percussion, unresolved so it can loop, 84 BPM, G major, instrumental
- **famine_s0:** Sparse village folk instrumental, tired and patient, solo erhu playing a simple pentatonic tune slowly with long rests between phrases, a few soft yangqin notes, small wooden hall, unresolved so it can loop, 66 BPM, G major, instrumental

**Stage 1. Rehearsed.** Tempo 84 (famine 66).
- **village_s1:** Warm village folk instrumental, sincere and a little too careful, dizi melody over erhu countermelody, yangqin chords and plucked low strings, light woodblock, every note played evenly as if rehearsed, small wooden hall, steady and unresolved so it can loop, 84 BPM, G major, instrumental
- **landlord_s1:** Village folk instrumental in a large hall, stately and hollow, dizi melody slowed over long low string chords and yangqin, erhu sustaining under it, no percussion, too much room around every note, unresolved so it can loop, 84 BPM, G major, instrumental
- **famine_s1:** Sparse village folk instrumental, polite and tired, solo erhu playing a simple pentatonic tune slowly, long rests, a few quiet yangqin notes, small wooden hall, unresolved so it can loop, 66 BPM, G major, instrumental

**Stage 2. One detail off.** Tempo 84 (famine 66).
- **village_s2:** Warm village folk instrumental, cheerful on the surface, dizi melody that ends each phrase a beat early and waits, erhu countermelody, yangqin chords and plucked low strings, light woodblock, small wooden hall, steady and unresolved so it can loop, 84 BPM, G major, instrumental
- **landlord_s2:** Village folk instrumental in a large empty hall, grand and hollow, dizi melody slowed over long low string chords and yangqin, erhu holding one note slightly too long each phrase, no percussion, unresolved so it can loop, 84 BPM, G major, instrumental
- **famine_s2:** Sparse village folk instrumental, worn out, solo erhu playing a simple pentatonic tune slowly and stopping short of the last note, long rests, a few yangqin notes, unresolved so it can loop, 66 BPM, G major, instrumental

**Stage 3. Never home.** Tempo 84 (famine 60).
- **village_s3:** Village folk instrumental, polite and uneasy, dizi melody whose phrases never land on the home note, erhu countermelody, yangqin chords and low plucked strings, sparse woodblock, a bare hall a little too large, steady and unresolved so it can loop, 84 BPM, G major, instrumental
- **landlord_s3:** Folk instrumental in a vast bare hall, heavy and hollow, dizi melody slowed over low string chords that never resolve, yangqin ringing a long time, no percussion, unresolved so it can loop, 84 BPM, G major, instrumental
- **famine_s3:** Sparse folk instrumental, exhausted, solo erhu playing a pentatonic tune very slowly with phrases left unfinished, long silences, bare hall, unresolved so it can loop, 60 BPM, G major, instrumental

**Stage 4. Stiff.** Tempo 84 (famine 60).
- **village_s4:** Village folk instrumental, stiff and dutiful, dizi and erhu playing the melody together in rigid unison, yangqin chords and low plucked strings, no percussion, a bare hall, steady and unresolved so it can loop, 84 BPM, G major, instrumental
- **landlord_s4:** Folk instrumental in a vast bare hall, ceremonial and empty, slow dizi melody over low string chords like a procession, yangqin far away, no percussion, unresolved so it can loop, 84 BPM, G major, instrumental
- **famine_s4:** Very sparse folk instrumental, solo erhu playing fragments of a pentatonic tune very slowly, long silences between them, bare hall, unresolved so it can loop, 60 BPM, G major, instrumental

**Stage 5. Half pace.** Tempo 84 (famine 54). These are the last masters with stems.
- **village_s5:** Sparse village folk instrumental, quiet and watchful, dizi playing the melody at half speed over steady plucked low strings, erhu and yangqin only on held notes, no percussion, a large bare hall, steady and unresolved so it can loop, 84 BPM, G major, instrumental
- **landlord_s5:** Sparse folk instrumental in a vast stone hall, cold and stately, slow dizi melody over a few deep low string chords, yangqin notes left ringing, no percussion, unresolved so it can loop, 84 BPM, G major, instrumental
- **famine_s5:** Near silent folk instrumental, solo erhu playing a few notes of a pentatonic tune very slowly, long silences, vast bare hall, unresolved so it can loop, 54 BPM, G major, instrumental

**Stage 6. Fragments.** Tempo 72 (famine 54). No stems.
- **village_s6:** Sparse folk instrumental, hushed, dizi plays the opening phrase of a simple pentatonic tune and stops, long rests, single yangqin notes and low plucked strings, a large empty hall, unresolved so it can loop, 72 BPM, G major, instrumental
- **landlord_s6:** Sparse folk instrumental in a vast stone hall, grand and empty, low string chords far apart, dizi playing pieces of a slow tune, long rests, unresolved so it can loop, 72 BPM, G major, instrumental
- **famine_s6:** Near silent folk instrumental, solo erhu, a few notes of a pentatonic tune then long silence, vast empty hall, unresolved so it can loop, 54 BPM, G major, instrumental

**Stage 7. Alone.** Tempo 72 (famine 48).
- **village_s7:** Very sparse folk instrumental, solo erhu in a large stone hall, a simple pentatonic tune broken into pieces, a low plucked string note now and then, long silences, unresolved so it can loop, 72 BPM, G major, instrumental
- **landlord_s7:** Very sparse instrumental in a vast stone hall, deep low string chords held a long time, a distant dizi plays a slow broken tune, long silences, unresolved so it can loop, 72 BPM, G major, instrumental
- **famine_s7:** Almost silent instrumental, solo erhu plays two or three notes of a tune and stops, very long silences, vast empty hall, unresolved so it can loop, 48 BPM, G major, instrumental

**Stage 8. Held too long.** Tempo 60 (famine 48).
- **village_s8:** Very sparse instrumental, erhu and one low plucked string, a simple pentatonic tune slowed with each note held too long, long silences, a vast empty hall, unresolved so it can loop, 60 BPM, G major, instrumental
- **landlord_s8:** Very sparse instrumental in an enormous empty hall, one low string chord at a time, a slow dizi note held until it fades, long silences, unresolved so it can loop, 60 BPM, G major, instrumental
- **famine_s8:** Almost silent instrumental, solo erhu holding single notes of a tune, very long silences, enormous empty hall, unresolved so it can loop, 48 BPM, G major, instrumental

**Stage 9. Half a tune.** Tempo 60 (famine 48).
- **village_s9:** Almost silent instrumental, a single dizi in a vast empty space plays the first half of a simple pentatonic tune and stops, very long silence, unresolved so it can loop, 60 BPM, G major, instrumental
- **landlord_s9:** Almost silent instrumental in an enormous empty hall, a single low string chord, then a single dizi note, then very long silence, unresolved so it can loop, 60 BPM, G major, instrumental
- **famine_s9:** Almost silent instrumental, a single erhu note held and fading, then very long silence, enormous empty hall, unresolved so it can loop, 48 BPM, G major, instrumental

### Listen for

- **Every cue:** the stage 0 tune is still recognisable. There are no vocals, no humming and no stingers. The loop has no intro, outro or build.
- **Masters, stages 0 to 5:** each stem solos cleanly after Auto Split.
- **Stages 6 to 9:** the silences are real silence, not a drone or reverb wash. If Suno fills them, raise the rests in the lyrics box with more `[Break]` tags, or trim the take.

These sentences are a first pass. After you've heard stage 0, I'll retune the later stages to what Suno actually did with it.

## Log

Each kept track gets a row in `audio/sources/manifest.csv` (columns `file,type,source,pack_or_url,author,license,plan,model,prompt_or_patch,generated,downloaded,edited`), with its final prompt, settings, Suno link, and both the generation and download dates.

| Cue | Suno link | Generated | Downloaded | Measured BPM | Loop (samples) |
| --- | --- | --- | --- | --- | --- |
| `village_master` | | | | | |
