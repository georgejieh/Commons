class_name ScreenId
extends RefCounted
## The ids the scene switcher knows each screen by, which App maps to its scene. It names
## nothing else, so a tool run without the autoloads can name a screen too. The ids are
## strings, not an enum: they key App's table of scenes, print as themselves in the logs
## and the walks' frame names, and the tutorial's steps name their screen by id in data.

## The title, where a session starts and every run ends up.
const TITLE: String = "title"
## The sheet before each Set: its type, target, seats and debuff ladder.
const SET_INTRO: String = "set_intro"
## The card table, where every round is played.
const TABLE: String = "table"
## The Quota report after a Set.
const SET_SUMMARY: String = "set_summary"
## The state store between Sets.
const STORE: String = "store"
## The close of the demo's one Year.
const YEAR_SUMMARY: String = "year_summary"
## Volumes, motion, card backs and the family's name.
const SETTINGS: String = "settings"
## The table actions' keys, opened from Settings.
const CONTROLS: String = "controls"
## The window's mode and size, opened from Settings.
const WINDOW: String = "window"
## The credits and licences, from the title.
const CREDITS: String = "credits"
## The demo's last page.
const DEMO_COMPLETE: String = "demo_complete"
## What the player has seen each villager do this run.
const DOSSIER: String = "dossier"
## The content note shown once, before the first title.
const CONTENT_NOTE: String = "content_note"
## Run setup: the households and the stake, picked before a run starts.
const RUN_SETUP: String = "run_setup"
## The last finished round, opened from the table's menu.
const ROUND_SUMMARY: String = "round_summary"
## The black market behind the state store, built from the store's script.
const BLACK_MARKET: String = "black_market"
## The report served in place of the store after mid Denunciation.
const REEDUCATION: String = "reeducation"
## How a full run ended.
const ENDING: String = "ending"
## Every item either shop sells, open or locked.
const COLLECTION: String = "collection"
## What each Quota left behind, and the family's past generations.
const VILLAGE_HISTORY: String = "village_history"
## The first launch's offer to sit in on the arrival.
const ARRIVAL: String = "arrival"
## The family's name, asked on a first launch.
const SURNAME: String = "surname"
