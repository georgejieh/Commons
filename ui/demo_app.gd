class_name DemoApp
extends Control
## The game's root (ADR 0017): the run controller, the hand model, the scene switcher
## and the screen host. Screens get the app in open() and reach the run only through
## its controller. New Run starts the full eight-Year run, or the one-Year demo when the
## app was launched with --demo after -- on the command line (ADR 0025). On a first
## launch, with no profile save, it asks the family's name (ADR 0028), then offers the
## arrival (ADR 0026): a scripted first evening at the table, played over its own layer,
## never saved, that writes the profile's first save, with that name, when it ends.

const DEMO: DemoParams = preload("res://data/run/demo.tres")
## The command-line flag that makes New Run start the demo.
const DEMO_FLAG: String = "--demo"
## The setting that is true once the content note has been seen.
const CONTENT_NOTE_SEEN: String = "content_note_seen"
## The demo seats' voices, by villager name.
const DEMO_VOICE: String = "res://data/ui/voices/%s.tres"
const SCREENS: Dictionary[String, String] = {
	"title": "res://ui/screens/title_screen.tscn",
	"set_intro": "res://ui/screens/set_intro_screen.tscn",
	"table": "res://ui/table2d/table_screen.tscn",
	"set_summary": "res://ui/screens/set_summary_screen.tscn",
	"store": "res://ui/screens/store_screen.tscn",
	"year_summary": "res://ui/screens/year_summary_screen.tscn",
	"settings": "res://ui/screens/settings_screen.tscn",
	"controls": "res://ui/screens/controls_screen.tscn",
	"window": "res://ui/screens/window_screen.tscn",
	"credits": "res://ui/screens/credits_screen.tscn",
	"demo_complete": "res://ui/screens/demo_complete_screen.tscn",
	"dossier": "res://ui/screens/dossier_screen.tscn",
	"content_note": "res://ui/screens/content_note_screen.tscn",
	"run_setup": "res://ui/screens/run_setup_screen.tscn",
	"round_summary": "res://ui/screens/round_summary_screen.tscn",
	"black_market": "res://ui/screens/black_market_screen.tscn",
	"reeducation": "res://ui/screens/reeducation_screen.tscn",
	"ending": "res://ui/screens/ending_screen.tscn",
	"collection": "res://ui/screens/collection_screen.tscn",
	"village_history": "res://ui/screens/village_history_screen.tscn",
	"arrival": "res://ui/screens/arrival_screen.tscn",
	"surname": "res://ui/screens/surname_screen.tscn",
}

## Screens of a run, off the table, where Escape opens the menu. The table has its own.
const MENU_SCREENS: Array[String] = [
	"set_intro", "set_summary", "store", "black_market", "year_summary"
]

## True when New Run starts the demo. Tools set it before the app enters the tree.
var demo: bool = OS.get_cmdline_user_args().has(DEMO_FLAG)
var controller: RunController = null
var hand: HandModel
var switcher: SceneSwitcher = null
var post: PostProcess = null
## The arrival (ADR 0026): offered on a first launch, and the one-time tooltips. Screens
## ask it whether an action is allowed.
var arrival: Arrival
## The state's notice when the books are corrected (ADR 0022), over every screen.
var notice: BooksNotice = null
## The folder the last session's files were copied to when it did not close (ADR 0037),
## until the title has told the player; empty otherwise.
var kept_crash: String = ""
var _wipe: ColorRect = null
var _wipe_layer: CanvasLayer = null
var _menu: PauseMenu = null

@onready var _host: Control = $Screens


func _ready() -> void:
	_apply_text_size()
	# The window takes the player's mode before anything shows in it, the gate's notice too.
	add_child(DisplayWindow.for_app(self))
	# A launch of the game itself first asks whether another copy is open, or the last one
	# stopped (ADR 0037); a tool or test that builds the app opens it at once.
	if not LaunchGate.guards(self):
		_open()
		return
	var gate: LaunchGate = LaunchGate.new()
	gate.opened.connect(_open)
	add_child(gate)


## Opens the app. kept is the folder the last session's files were copied to when it did
## not close, which the title tells the player of, or empty.
func _open(kept: String = "") -> void:
	kept_crash = kept
	# Read before anything can write a profile save.
	arrival = Arrival.new(self, not ProfileSeen.exists(Saves.profile_service()))
	# Made here, not before: an app that never opens, as after Quit on the "already open"
	# notice, leaves nothing outside the tree.
	controller = RunController.new()
	switcher = SceneSwitcher.new()
	post = PostProcess.new()
	notice = BooksNotice.new()
	_wipe = ColorRect.new()
	_wipe_layer = CanvasLayer.new()
	_menu = PauseMenu.new()
	add_child(controller)
	add_child(switcher)
	add_child(post)
	Settings.changed.connect(_on_setting)
	_wipe.color = CommonsTheme.STYLE.ink
	_wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wipe.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wipe.modulate.a = 0.0
	_wipe_layer.layer = PostProcess.LAYER - 1
	_wipe_layer.add_child(_wipe)
	add_child(_wipe_layer)
	add_child(arrival.layer)
	add_child(_menu)
	# Over the arrival's layer, which draws above every piece a screen lifts.
	_menu.z_index = TutorialLayer.DRAW_ORDER + 1
	_menu.wire(self)
	add_child(notice)
	# Every tooltip stands beside what it explains, off it and its button.
	add_child(TipPlacer.new())
	notice.watch(controller)
	hand = HandModel.new(controller)
	var scenes: Dictionary[String, PackedScene] = {}
	for screen_id: String in SCREENS:
		scenes[screen_id] = load(SCREENS[screen_id])
	switcher.setup(_host, scenes)
	show_screen(_opening_screen(), true)


## The art held for the session goes with the app.
func _exit_tree() -> void:
	ArtStages.release()


## Escape opens the menu on a run's screens away from the table (the table handles its
## own, first).
func _unhandled_input(event: InputEvent) -> void:
	if _menu == null or not event.is_action_pressed("ui_cancel") or _menu.visible:
		return
	if MENU_SCREENS.has(switcher.current_id()):
		_menu.open()
		get_viewport().set_input_as_handled()


func menu_is_open() -> bool:
	return _menu != null and _menu.visible


## The first screen of this launch: the content note until it is seen, then where the
## arrival leads.
func _opening_screen() -> String:
	if not bool(Settings.value(CONTENT_NOTE_SEEN)):
		return "content_note"
	return arrival.next_screen()


## Shows a screen and hands it the app. replace drops the way back.
func show_screen(screen_id: String, replace: bool = false) -> Node:
	_play_wipe()
	return _opened(switcher.replace(screen_id) if replace else switcher.push(screen_id))


## Builds the screen shown again, keeping the way back, and hands it the app.
func reopen() -> void:
	_opened(switcher.reload())


## Screens cut through a quick ink fade, like a page turning under a lamp.
func _play_wipe() -> void:
	if UiMotion.reduced():
		return
	Audio.fill(AudioEvents.MOTION_WIPE)
	_wipe.modulate.a = 1.0
	var tween: Tween = _wipe.create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_wipe, "modulate:a", 0.0, UiMotion.PRESETS.wipe_time)


## A new text size (ADR 0034) reaches everything drawn from the theme at once; pieces that
## set their own sizes take it when their screen is built again.
func _on_setting(key: String) -> void:
	if key == TextSize.SETTING:
		_apply_text_size()


## The project's fallback theme takes the size too, for anything drawn outside the app.
func _apply_text_size() -> void:
	theme = CommonsTheme.build()
	var fallback: Theme = ThemeDB.get_project_theme()
	if fallback != null:
		fallback.default_font_size = TextSize.px(CommonsTheme.STYLE.body_size)


## Goes back one screen. Returns false at the bottom of the stack.
func back() -> bool:
	if not switcher.back():
		return false
	_opened(switcher.current())
	return true


## Hands the screen just shown the app, and tells the arrival which it is.
func _opened(screen: Node) -> Node:
	if screen.has_method("open"):
		screen.call("open", self)
	arrival.shown(switcher.current_id())
	return screen


## The table's screen.
func table_id() -> String:
	return "table"


## Starts the demo, or with full the eight-Year run with the village's roster, as the
## household and at the stake run setup chose. False when the profile has not unlocked
## them, and nothing starts.
func new_run(seed_value: int, full: bool = false, household: String = "", stake: int = 0) -> bool:
	var request: RunRequest = RunRequest.new(
		RunRequest.FULL if full else RunRequest.DEMO, seed_value
	)
	if full:
		request.household = household
		request.stake = stake
	KeptSeat.forget()
	if not controller.start(request, Saves.run_service(), Saves.profile_service()):
		return false
	GameLog.run_started("full" if full else "demo", seed_value)
	return true


## Continues the saved run as the kind it was saved as.
func continue_run() -> bool:
	if not controller.continue_saved(Saves.run_service(), Saves.profile_service()):
		return false
	GameLog.run_resumed(controller.run.run_seed())
	return true


## Leaves the run for good, for the title: abandoned from the menu, or finished on its
## ending. Its save is cleared and nothing more is recorded (ADR 0025); the memory of
## the Quotas it finished, and a finished run's record, are already in the profile.
func leave_run() -> void:
	KeptSeat.forget()
	# The arrival is never saved: leaving it must not touch a real run's save.
	if not arrival.is_running():
		if controller.has_run():
			var over: bool = controller.awaiting() == RunController.AWAIT_RUN_OVER
			GameLog.run_ended(controller.run.run_seed(), "finished" if over else "abandoned")
		# The run is let go before its save is cleared, so a villager still thinking
		# cannot hand in a play afterwards and write the save back.
		controller.drop()
		Saves.run_service().delete()
	show_screen("title", true)


## Continues the saved run on the screen it stopped at.
func resume_to_screen() -> void:
	if not continue_run():
		return
	show_screen(screen_for(controller.awaiting()), true)


## The screen that shows what the run waits on.
func screen_for(awaiting: int) -> String:
	match awaiting:
		RunController.AWAIT_SET_OVER:
			return "set_summary"
		RunController.AWAIT_STORE:
			return "store"
		RunController.AWAIT_REEDUCATION:
			return "reeducation"
		RunController.AWAIT_RUN_OVER:
			# A full run ends on its ending; the demo keeps its Year summary and closing page.
			return "ending" if controller.seats.has_village() else "year_summary"
	return table_id()


## True when a run save, or its backup, holds a run Continue can pick up.
func has_saved_run() -> bool:
	return RunStarter.resumable(Saves.run_service())


## The seat's surname, as the table and speech call a villager.
func seat_name(seat: int) -> String:
	var key: String = controller.seats.seated_name_key(seat) if _in_run() else ""
	return tr(key if not key.is_empty() else DEMO.name_keys[seat])


## The seated family's own speech lines, or null for the demo's fixed seats.
func seat_speech(seat: int) -> SpeechBook:
	var family: FamilyDef = _seated_family(seat)
	return null if family == null else family.speech


## The seated family's voice as its generation has drifted it, or the demo seat's by its
## villager name.
func seat_voice(seat: int) -> VoiceProfile:
	if _seated_family(seat) != null:
		return controller.seats.seated_voice(seat)
	var path: String = DEMO_VOICE % seat_voice_bank(seat)
	return load(path) if ResourceLoader.exists(path) else null


## The name of the seat's letter bank under audio/voices: the family's id.
func seat_voice_bank(seat: int) -> String:
	var family: FamilyDef = _seated_family(seat)
	if family != null:
		return family.id
	if seat >= DEMO.name_keys.size():
		return ""
	return DEMO.name_keys[seat].trim_prefix("villager.")


## The seat's portrait cropped around its face for a box of the given shape.
func seat_portrait(seat: int, box: Vector2 = Vector2.ZERO) -> Texture2D:
	var family: FamilyDef = _seated_family(seat)
	if family != null:
		if family.portrait == null:
			return null
		var face: Texture2D = ArtStages.resolve(family.portrait)
		if box == Vector2.ZERO:
			return face
		return FaceCrop.crop(face, family.portrait_face, box.x / box.y)
	if seat >= DEMO.portraits.size() or DEMO.portraits[seat] == null:
		return null
	var picture: Texture2D = ArtStages.resolve(DEMO.portraits[seat])
	if box == Vector2.ZERO or seat >= DEMO.portrait_faces.size():
		return picture
	return FaceCrop.crop(picture, DEMO.portrait_faces[seat], box.x / box.y)


func need_cap() -> int:
	return DEMO.need_cap


func sets_per_year() -> int:
	return SetConfig.SETS_PER_YEAR


## The most rounds a Set of the run in play takes.
func max_rounds() -> int:
	return controller.figures.max_rounds() if _in_run() else DEMO.sets.max_rounds


## Seconds between table events: shorter under reduced motion, longer through the
## arrival, where every play and every score is new.
func motion_step() -> float:
	var presets: MotionPresets = UiMotion.PRESETS
	var pace: int = clampi(
		int(Settings.value(SettingsPanel.PACE_SETTING)), 0, presets.pace_scales.size() - 1
	)
	var step: float = UiMotion.seconds(presets.event_step) * presets.pace_scales[pace]
	return step * (presets.arrival_scale if arrival.is_running() else 1.0)


func _in_run() -> bool:
	return controller != null and controller.has_run()


## The family in the seat, or null before any run and for the demo's fixed seats.
func _seated_family(seat: int) -> FamilyDef:
	return controller.seats.seated_family(seat) if _in_run() else null
