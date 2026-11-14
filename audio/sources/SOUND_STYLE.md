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
| UI and ambient | -26 | button click, meter drone |

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

## Decisions
<!-- one line per change and why, newest last -->
- 2026-11-05 all: first pass for P3C.8. A pass is a knuckle knock, the way players pass at a real table. A won round is stamped, a lost one is struck through in pencil.
- 2026-11-05 round_lost: doctor warns of 52% energy in 2-5 kHz; a pencil lives there, and it plays once per round, so it stays low-passed at 2.6 kHz rather than dulled further.
