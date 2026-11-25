# Sound style: Commons

Read this before making or changing any sound for this project. Every new sound should feel like it belongs to the same family as these. The rules behind it are in `.claude/skills/commons-sfx/SKILL.md`.

## Identity
- **Game:** a single-player roguelike deckbuilder on Fight the Landlord; the player plays cards at a village table.
- **Style:** grounded. Recorded paper, card stock, wood and ink; synthesis only for UI ticks and abstract drones.
- **Mood:** close, dry, plain, a little uneasy. Not a casino, an arcade or a horror film.
- **Engine:** Godot 4.7.2 (effects in `audio/sfx/`, wired through `data/audio/sfx_bank.tres`).

## Palette
- **Sources:** Kenney Casino Audio and Impact Sounds (CC0), Freesound CC0 recordings, `sfx.py` synthesis.
- **Materials in the world:** playing cards on a wooden table, knuckles on wood, a rubber stamp, a pencil on a ledger.
- **Music key / tempo:** G major, 84 BPM (`audio/music/CUES.md`). Effects carry no pitch that fights it.
- **Space:** dry. No reverb on any effect yet.
- **Not used:** Sonniss GDC bundles. The repository is public and the license bars redistributing the sounds, raw or derived, so they cannot be committed.

## Loudness ladder (file LUFS; short sounds balanced by peak and ear)
| Tier | LUFS | Sounds |
|---|---|---|
| Hero | -14 to -16 | rocket, bomb |
| Gameplay | -20 to -23 | card play, deal, round won and lost, store buy, trick won |
| Quiet gameplay | -27 | pass knock |
| Heavy score | -17 to -20 | total landing, big total landing (also the Quota met) |
| Score steps | -23 to -25 | score ticks, small stamp, handbell, dull gong, dice bowl |
| UI and ambient | -26 | button click, meter drone, brush stroke |
| Ambience loops | -27 to -31 (file), then -6 to -10 dB at runtime | the nine beds under the table |
| Quietest | -30 to -32 | paper flick, soft tap (heard constantly: hover, swells, a villager's wind-up) |

## Sound list
| Name | Event in code | Files | Status |
|---|---|---|---|
| deal | `dealt`, `redealt` (`TableSounds`) | `deal.wav` | needs the owner's ear |
| card play | `card_played` | `card_play_01`-`04` | needs the owner's ear |
| pass | `passed` | `pass_01`-`03` | needs the owner's ear |
| trick won | `trick_won` | `trick_won_01`-`03` | needs the owner's ear |
| bomb | `bomb_played` | `bomb.wav` | needs the owner's ear |
| rocket | `rocket_played` | `rocket.wav` | needs the owner's ear |
| round won | `round_won` | `round_won.wav` (stamp) | needs the owner's ear |
| round lost | `round_lost` | `round_lost.wav` (pencil strike) | needs the owner's ear |
| button click | `button_click` (every `BaseButton`, `AudioMixer`) | `click_01`-`03` | needs the owner's ear |
| store buy | `store_buy` (`StoreScreen`) | `store_buy_01`-`02` (stamp) | needs the owner's ear |
| meter crossing | `meter_rose` (`TableSounds`, placeholder marks 25/50/75) | `meter_rose.wav` | needs the owner's ear |
| abacus bead | `score_tick`, `score_roll`, `motion_count` (`ScoreSequence`, `UiMotion.count`) | `score_bead_01`-`03` (synth) | needs the owner's ear |
| small stamp | `score_rate`, `score_zeal`, `motion_stamp` | `score_stamp_01`-`02` (synth) | needs the owner's ear |
| total stamp | `score_land`, `score_land_heavy`, `quota_met` | `score_land`, `score_land_heavy` (synth) | needs the owner's ear |
| handbell | `score_chime`, pitched up a step per change | `score_bell` (synth, G5) | needs the owner's ear |
| dull gong | `score_cut`, `quota_missed`, pitched down a step per cut | `score_gong` (synth) | needs the owner's ear |
| paper flick | `motion_fly`, `motion_enter`, `motion_settle` | `paper_flick_01`-`02` (synth) | needs the owner's ear |
| brush stroke | `callout_cut`, `motion_wipe` | `brush_stroke` (synth) | needs the owner's ear |
| dice in a bowl | `dice_roll` | `dice_bowl` (synth) | needs the owner's ear |
| soft tap | `motion_pulse`, `motion_hover`, `motion_wind` | `soft_tap_01`-`02` (synth) | needs the owner's ear |
| room | under every board, taken away by the landlord seat | `ambience_room` (loop, 12 s, 11025 Hz) | needs the owner's ear |
| hollow room | landlord seat | `ambience_hollow` (loop, 11 s, 11025 Hz) | needs the owner's ear |
| table chatter | clean board, thins with Famine | `ambience_chatter` (loop, 12 s, 11025 Hz) | needs the owner's ear |
| wind in the roof | Famine mid and up | `ambience_wind` (loop, 14 s, 11025 Hz) | needs the owner's ear |
| belly drone | Famine high | `ambience_drone` (loop, 16 s, 11025 Hz) | needs the owner's ear |
| paper and far footsteps | Denunciation mid, lower at high | `ambience_rustle` (loop, 16 s, 22050 Hz) | needs the owner's ear |
| whispers | Denunciation high | `ambience_whispers` (loop, 13 s, 22050 Hz) | needs the owner's ear |
| slow clock | Denunciation high | `ambience_clock` (loop, 8 s, 22050 Hz) | needs the owner's ear |
| far crowd | both meters high; hushes when the player plays | `ambience_crowd` (loop, 15 s, 11025 Hz) | needs the owner's ear |

## Decisions
<!-- one line per change and why, newest last -->
- 2026-11-05 all: first pass for P3C.8. A pass is a knuckle knock, the way players pass at a real table. A won round is stamped, a lost one is struck through in pencil.
- 2026-11-05 round_lost: doctor warns of 52% energy in 2-5 kHz; a pencil lives there, and it plays once per round, so it stays low-passed at 2.6 kHz rather than dulled further.
- 2026-11-24 scoring and motion: the owner asked for a sound with every animation and a slot machine's run when a play scores (playtest of 2026-11-24). Synthesized by `tools/make_sfx.py`, since no CC0 pack is vendored in the repository and nothing was downloaded: an abacus bead per card, a small stamp for Rate and Zeal, a handbell a pentatonic step higher for each Cadre or mark that fires, a dull gong a step lower for each cut, beads for the total's roll and a stamp to land it. Motion sounds only fill a silence (`Audio.fill`). Paper flick and brush were darkened after the doctor warned of 2-5 kHz energy. 199 KB in all.
- 2026-11-25 ambience: the board states' beds, synthesized by `tools/make_ambience.py` with nothing downloaded and heard by nobody yet. Chatter, whispers and crowd are formant babble from patches, not the voice bank, because the vendored renderer reads only 44.1 kHz WAV and the bank is 22.05 kHz; no recorded voice is in them. The loops are PCM, not QOA, so the seam the test measures is the seam that plays (3.4 MB in all; QOA would cut it about fivefold). The clock ticks once a second against the music's 84 BPM, while Denunciation has faded the percussion.
