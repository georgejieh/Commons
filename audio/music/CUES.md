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

Pro gives 20 song downloads a month. A song with all its stems counts once. This plan needs 10:

| # | Cue | Board or use | Stems |
| --- | --- | --- | --- |
| 1 | `village_master` | Clean board, and both decay paths through stems | Yes, prototype first |
| 2 | `landlord_master` | Landlord seat: same melody idea, reharmonized, the room too large | Yes |
| 3 | `famine_mid` | Famine mid: slower (66 BPM), fewer instruments | No |
| 4 | `famine_high` | Famine high: one erhu, long rests (60 BPM) | No |
| 5 | `title` | Title screen | No |
| 6 | `tutorial` | First-launch tutorial (P4.15) | No |
| 7 | `state_store` | State store | No |
| 8 | `black_market` | Black market | No |
| 9 | `boss` | Boss Sets | No |
| 10 | `ending` | Endings and epilogues | No |

The skill says to test one master before writing the rest, so only cue 1 is written below. The others follow once the owner has heard it, split it and judged the stems.

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

## Log

Each kept track gets a row in `audio/sources/manifest.csv` (columns `file,type,source,pack_or_url,author,license,plan,model,prompt_or_patch,generated,downloaded,edited`), with its final prompt, settings, Suno link, and both the generation and download dates.

| Cue | Suno link | Generated | Downloaded | Measured BPM | Loop (samples) |
| --- | --- | --- | --- | --- | --- |
| `village_master` | | | | | |
