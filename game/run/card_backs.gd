class_name CardBacks
extends RefCounted
## Which card back the player has chosen (ADR 0025, "Card designs"). The choice is a
## setting, per player, not part of the profile; what is open comes from the profile's
## finished runs. A design waiting for its art is never open. A choice no longer open falls
## back to the first design. Nothing here touches a run.

## Every card back design there is.
const POOL: CardBackPool = preload("res://data/ui/card_backs/card_backs.tres")
## The setting that holds the chosen design's ID.
const SETTING: String = "card_back"


## True when the design can be chosen after this many finished runs.
static func is_open(design: CardBackDef, finished_runs: int) -> bool:
	return not design.art_pending and finished_runs >= design.finished_runs


## The design to draw for a choice: the chosen one while it is open, else the first.
static func chosen(back_id: String, finished_runs: int) -> CardBackDef:
	var design: CardBackDef = POOL.back(back_id)
	if design != null and is_open(design, finished_runs):
		return design
	return POOL.backs[0]


## The design in use now, from the setting and the saved profile.
static func current() -> CardBackDef:
	return chosen(choice(), profile_runs())


## The saved profile's finished runs, which open the designs.
static func profile_runs() -> int:
	return Profile.read(Saves.profile_service()).finished_runs


## The chosen design's ID as the settings hold it.
static func choice() -> String:
	return str(Settings.value(SETTING))


## What a design not yet open says instead of its name: when it opens, or, once its runs
## are done, that it waits for its art.
static func locked_line(design: CardBackDef, finished_runs: int) -> String:
	if finished_runs < design.finished_runs:
		return UnlockSheet.runs_line(design.finished_runs - finished_runs)
	return TranslationServer.translate("cardback.pending")


## The seat panels' picture of the design in use, at the art's stage.
static func picture(design: CardBackDef) -> Texture2D:
	var first: CardBackDef = POOL.backs[0]
	return ArtStages.resolve(design.art if design.art != null else first.art)
