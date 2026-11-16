class_name Arrival
extends RefCounted
## The arrival as the app runs it (ADR 0026): offered on a first launch, read as no
## profile save on disk when the app started, before anything could write one. It
## starts the tutorial run, follows the screens it plays on through its layer, and ends
## on any other screen. Finishing it, or skipping it, writes the profile's first save
## with the arrival seen; quitting part-way writes nothing, so it is offered again.
## Replayed from Settings it ends at the title and leaves the profile alone. It also
## decides when the one-time tooltips of a full run show.

## The screens the arrival plays on, and those its menu opens over the table.
const SCREENS: Array[String] = [
	"table", "set_summary", "store", "black_market", "dossier", "round_summary"
]

## The arrival under way, or null.
var director: TutorialDirector = null
## True when no profile save was on disk as the app started.
var first_launch: bool = false
## The overlay it plays on, which the app adds over its screens.
var layer: TutorialLayer = TutorialLayer.new()

var _app: DemoApp
## True while the arrival plays again from Settings.
var _replay: bool = false


func _init(app: DemoApp, first: bool) -> void:
	_app = app
	first_launch = first


## Where the content note leads: the Arrival page on a first launch, else the title.
## P4.17's surname step goes here, before the Arrival page: it keeps the chosen surname
## in hand and writes no profile, which the arrival's end or skip then writes.
func next_screen() -> String:
	return "arrival" if first_launch else "title"


func is_running() -> bool:
	return director != null


## True when the action may be taken now: always, but during the arrival only the step's
## own action, which the arrival then takes as done. A refused one changes nothing.
func allows(action: String, detail: Variant = null) -> bool:
	return director == null or director.attempt(action, detail)


## Starts the arrival at the table. replay plays it again, ending at the title.
func start(replay: bool = false) -> void:
	_replay = replay
	_app.controller.start(RunStarter.tutorial())
	director = TutorialDirector.new()
	director.finished.connect(_on_finished)
	layer.attach(_app, director)
	_app.show_screen(_app.table_id(), true)


## Skips it, from its page or its corner button once asked; then the title.
func skip() -> void:
	end()
	_remember()
	_app.show_screen("title", true)


## The app showed a screen: the arrival follows it, or ends on one it does not play on.
func shown(screen_id: String) -> void:
	if director == null:
		return
	if SCREENS.has(screen_id):
		layer.on_screen(screen_id)
	else:
		end()


## Lets the arrival's run go. It was never saved, so nothing is cleared.
func end() -> void:
	if director == null:
		return
	director = null
	layer.detach()
	_app.controller.drop()


## True when a one-time tooltip should show now: in a full run, never in the demo or the
## arrival, and only while the profile has not seen it.
func tip_due(tip_id: String) -> bool:
	var controller: RunController = _app.controller
	if director != null or not controller.has_run() or not controller.is_full_run():
		return false
	return not ProfileSeen.has(Saves.profile_service(), tip_id)


## A one-time tooltip was dismissed: the profile remembers it.
func tip_seen(tip_id: String) -> void:
	ProfileSeen.mark(Saves.profile_service(), tip_id)


func _on_finished() -> void:
	var replay: bool = _replay
	end()
	_remember()
	_app.show_screen("title" if replay else "run_setup", true)


## Writes the profile's first save, with the arrival seen, on a first launch only.
func _remember() -> void:
	if _replay or not first_launch:
		return
	ProfileSeen.mark(Saves.profile_service(), ProfileSeen.TUTORIAL)
	first_launch = false
