class_name DemoApp
extends Control
## The demo's root (ADR 0017): the run controller, the hand model, the scene switcher
## and the screen host. Screens get the app in open() and reach the run only through
## its controller. The table scene is the 2D or the 3D one, chosen at export.

const DEMO: DemoParams = preload("res://data/run/demo.tres")
## The demo seats' voices, by villager name.
const DEMO_VOICE: String = "res://data/ui/voices/%s.tres"
const MOTION: MotionPresets = preload("res://data/ui/motion_presets.tres")
const TABLE_3D_FEATURE: String = "table_3d"
const SCREENS: Dictionary[String, String] = {
	"title": "res://ui/screens/title_screen.tscn",
	"set_intro": "res://ui/screens/set_intro_screen.tscn",
	"table": "res://ui/table2d/table_screen.tscn",
	"table_3d": "res://ui/table3d/table_3d_screen.tscn",
	"set_summary": "res://ui/screens/set_summary_screen.tscn",
	"store": "res://ui/screens/store_screen.tscn",
	"year_summary": "res://ui/screens/year_summary_screen.tscn",
	"settings": "res://ui/screens/settings_screen.tscn",
	"demo_complete": "res://ui/screens/demo_complete_screen.tscn",
	"dossier": "res://ui/screens/dossier_screen.tscn",
	"content_note": "res://ui/screens/content_note_screen.tscn",
	"run_setup": "res://ui/screens/run_setup_screen.tscn",
	"round_summary": "res://ui/screens/round_summary_screen.tscn",
	"black_market": "res://ui/screens/black_market_screen.tscn",
	"plot_swap": "res://ui/screens/plot_swap_screen.tscn",
	"reeducation": "res://ui/screens/reeducation_screen.tscn",
	"ending": "res://ui/screens/ending_screen.tscn",
	"collection": "res://ui/screens/collection_screen.tscn",
	"village_history": "res://ui/screens/village_history_screen.tscn",
}

## Screens of a run, off the table, where Escape opens the menu. The table has its own.
const MENU_SCREENS: Array[String] = [
	"set_intro", "set_summary", "store", "black_market", "year_summary", "plot_swap"
]

var controller: RunController = RunController.new()
var hand: HandModel
var switcher: SceneSwitcher = SceneSwitcher.new()
var post: PostProcess = PostProcess.new()
var _wipe: ColorRect = ColorRect.new()
var _wipe_layer: CanvasLayer = CanvasLayer.new()
var _menu: PauseMenu = PauseMenu.new()

@onready var _host: Control = $Screens


func _ready() -> void:
	add_child(controller)
	add_child(switcher)
	add_child(post)
	theme = CommonsTheme.build()
	_wipe.color = CommonsTheme.STYLE.ink
	_wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wipe.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wipe.modulate.a = 0.0
	_wipe_layer.layer = PostProcess.LAYER - 1
	_wipe_layer.add_child(_wipe)
	add_child(_wipe_layer)
	add_child(_menu)
	_menu.to_title.connect(func() -> void: show_screen("title", true))
	_menu.quit_game.connect(func() -> void: get_tree().quit())
	_menu.dossier.connect(func() -> void: show_screen("dossier"))
	_menu.last_round.connect(func() -> void: show_screen("round_summary"))
	hand = HandModel.new(controller)
	var scenes: Dictionary[String, PackedScene] = {}
	for screen_id: String in SCREENS:
		if ResourceLoader.exists(SCREENS[screen_id]):
			scenes[screen_id] = load(SCREENS[screen_id])
	switcher.setup(_host, scenes)
	show_screen(first_screen(), true)


## Escape opens the menu on a run's screens away from the table (the table handles its
## own, first).
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or _menu.visible:
		return
	if MENU_SCREENS.has(switcher.current_id()):
		_menu.open()
		get_viewport().set_input_as_handled()


func menu_is_open() -> bool:
	return _menu.visible


## The content note on first launch, then the title ever after.
func first_screen() -> String:
	return "title" if bool(Settings.value("content_note_seen")) else "content_note"


## Shows a screen and hands it the app. replace drops the way back.
func show_screen(screen_id: String, replace: bool = false) -> Node:
	_play_wipe()
	var screen: Node = switcher.replace(screen_id) if replace else switcher.push(screen_id)
	if screen.has_method("open"):
		screen.call("open", self)
	return screen


## Screens cut through a quick ink fade, like a page turning under a lamp.
func _play_wipe() -> void:
	if UiMotion.reduced():
		return
	_wipe.modulate.a = 1.0
	var tween: Tween = _wipe.create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_wipe, "modulate:a", 0.0, UiMotion.PRESETS.wipe_time)


## Goes back one screen. Returns false at the bottom of the stack.
func back() -> bool:
	if not switcher.back():
		return false
	if switcher.current().has_method("open"):
		switcher.current().call("open", self)
	return true


## The table this build plays on.
func table_id() -> String:
	return "table_3d" if OS.has_feature(TABLE_3D_FEATURE) else "table"


func new_run(seed_value: int) -> void:
	controller.start_run(
		seed_value,
		_configs(),
		SetConfig.new(DEMO.sets),
		Saves.run_service(),
		DEMO.starting_coupons,
		Saves.profile_service()
	)


func continue_run() -> bool:
	return controller.resume_saved(
		Saves.run_service(), _configs(), SetConfig.new(DEMO.sets), Saves.profile_service()
	)


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
			return "year_summary"
		RunController.AWAIT_SWAP:
			return "plot_swap"
	return table_id()


func has_saved_run() -> bool:
	return FileAccess.file_exists(Saves.run_service().path())


func seat_name(seat: int) -> String:
	var key: String = _controller_call("seated_name_key", seat, "")
	return tr(key if not key.is_empty() else DEMO.name_keys[seat])


## The seated family's own speech lines, or null for the demo's fixed seats.
func seat_speech(seat: int) -> SpeechBook:
	var family: FamilyDef = _controller_call("seated_family", seat, null)
	return null if family == null else family.speech


## The seated family's voice (P3B.13), or the demo seat's by its villager name.
func seat_voice(seat: int) -> VoiceProfile:
	var family: FamilyDef = _controller_call("seated_family", seat, null)
	if family != null:
		return family.voice
	var path: String = DEMO_VOICE % seat_voice_bank(seat)
	return load(path) if ResourceLoader.exists(path) else null


## The name of the seat's letter bank under audio/voices: the family's id.
func seat_voice_bank(seat: int) -> String:
	var family: FamilyDef = _controller_call("seated_family", seat, null)
	if family != null:
		return family.id
	if seat >= DEMO.name_keys.size():
		return ""
	return DEMO.name_keys[seat].trim_prefix("villager.")


## Asks the controller about a seat, or gives fallback before any run exists.
func _controller_call(method: String, seat: int, fallback: Variant) -> Variant:
	if controller == null or not controller.has_run():
		return fallback
	return controller.call(method, seat)


## The seat's portrait cropped around its face for a box of the given shape.
func seat_portrait(seat: int, box: Vector2 = Vector2.ZERO) -> Texture2D:
	var family: FamilyDef = _controller_call("seated_family", seat, null)
	if family != null:
		if family.portrait == null:
			return null
		var face: Texture2D = ArtStages.resolve(family.portrait)
		if box == Vector2.ZERO:
			return face
		return ScreenKit.face_crop(face, family.portrait_face, box.x / box.y)
	if seat >= DEMO.portraits.size() or DEMO.portraits[seat] == null:
		return null
	var picture: Texture2D = ArtStages.resolve(DEMO.portraits[seat])
	if box == Vector2.ZERO or seat >= DEMO.portrait_faces.size():
		return picture
	return ScreenKit.face_crop(picture, DEMO.portrait_faces[seat], box.x / box.y)


func need_cap() -> int:
	return DEMO.need_cap


func sets_per_year() -> int:
	return SetConfig.SETS_PER_YEAR


## Dread for the post-process: the higher meter, as a share of its range.
func max_rounds() -> int:
	return DEMO.sets.max_rounds


## Seconds between table events, shorter under reduced motion.
func motion_step() -> float:
	var reduced: bool = bool(Settings.value("reduced_motion"))
	return MOTION.event_step * (MOTION.reduced_scale if reduced else 1.0)


func _configs() -> Array[BotConfig]:
	var configs: Array[BotConfig] = []
	for tier: int in DEMO.tiers:
		configs.append(BotConfig.new(BotConfig.DEFAULT_WEIGHTS, tier as BotConfig.Tier))
	return configs
