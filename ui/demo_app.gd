class_name DemoApp
extends Control
## The demo's root (ADR 0017): the run controller, the hand model, the scene switcher
## and the screen host. Screens get the app in open() and reach the run only through
## its controller. The table scene is the 2D or the 3D one, chosen at export.

const DEMO: DemoParams = preload("res://data/run/demo.tres")
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
}

var controller: RunController = RunController.new()
var hand: HandModel
var switcher: SceneSwitcher = SceneSwitcher.new()

@onready var _host: Control = $Screens


func _ready() -> void:
	add_child(controller)
	add_child(switcher)
	hand = HandModel.new(controller)
	var scenes: Dictionary[String, PackedScene] = {}
	for screen_id: String in SCREENS:
		if ResourceLoader.exists(SCREENS[screen_id]):
			scenes[screen_id] = load(SCREENS[screen_id])
	switcher.setup(_host, scenes)
	show_screen("title", true)


## Shows a screen and hands it the app. replace drops the way back.
func show_screen(screen_id: String, replace: bool = false) -> Node:
	var screen: Node = switcher.replace(screen_id) if replace else switcher.push(screen_id)
	if screen.has_method("open"):
		screen.call("open", self)
	return screen


func back() -> void:
	if switcher.back() and switcher.current().has_method("open"):
		switcher.current().call("open", self)


## The table this build plays on.
func table_id() -> String:
	return "table_3d" if OS.has_feature(TABLE_3D_FEATURE) else "table"


func new_run(seed_value: int) -> void:
	controller.start_run(
		seed_value, _configs(), SetConfig.new(DEMO.sets), Saves.run_service(), DEMO.starting_coupons
	)


func continue_run() -> bool:
	return controller.resume_saved(Saves.run_service(), _configs(), SetConfig.new(DEMO.sets))


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
		RunController.AWAIT_RUN_OVER:
			return "year_summary"
	return table_id()


func has_saved_run() -> bool:
	return FileAccess.file_exists(Saves.run_service().path())


func seat_name(seat: int) -> String:
	return tr(DEMO.name_keys[seat])


func seat_portrait(seat: int) -> Texture2D:
	return DEMO.portraits[seat] if seat < DEMO.portraits.size() else null


func need_cap() -> int:
	return DEMO.need_cap


func sets_per_year() -> int:
	return SetConfig.SETS_PER_YEAR


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
