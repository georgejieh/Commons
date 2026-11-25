extends SceneTree
## Plays the game through its real UI, the way a person would, with mouse events on what
## shows, and photographs it. Needs --demo or --tutorial:
##   godot --path . --script res://tools/playtest.gd -- --demo --rounds 6 --out reports/playtest
## walks the demo for the rounds asked for, then every ending and a full run once
## (tools/playtest_demo.gd, ADR 0025);
##   godot --path . --script res://tools/playtest.gd -- --tutorial --out reports/tutorial
## plays the arrival (ADR 0026) from a first launch with no profile to run setup
## (tools/tutorial_walk.gd). Needs a real window for its pictures. Run with --headless it
## walks the same steps and names each frame instead, which checks its clicks without a
## window. Either walk takes --grayscale, --reduced-motion and --text-size N (ADR 0035,
## tools/display_flags.gd), for this run only and saved to the tool's own settings file,
## never the player's, and --profile NAME, which gives its saves a sandbox folder of their
## own (tools/walk_profile.gd) so two walks at once never share one. It prints a MISS line
## for each step that went wrong and a MISCLICK line for each click that did nothing, and
## exits 1 on any, 2 on bad options. Development only; tools/ never ships.

const USAGE: String = (
	"playtest.gd -- (--demo [--rounds N] | --tutorial) [--out DIR] [--profile NAME]"
	+ " [--grayscale] [--reduced-motion] [--text-size N]"
)
const DEFAULT_OUT: String = "reports/playtest"
const DEFAULT_ROUNDS: int = 6
## The sandbox folders of the two walks' saves (WalkProfile).
const DEMO_BASE: String = "playtest"
const TUTORIAL_BASE: String = "playtest_tutorial"
## Frames a second a headless run is paced at.
const HEADLESS_FPS: int = 60

var _options: ToolOptions
var _rounds: int


func _initialize() -> void:
	_options = ToolOptions.new(USAGE)
	if _options.has("demo") == _options.has("tutorial"):
		_options.refuse("Needs --demo or --tutorial, and not both.")
	_rounds = _options.integer("rounds", DEFAULT_ROUNDS, 1)
	DisplayFlags.text_size(_options)
	var out: String = _options.path("out", DEFAULT_OUT)
	if _options.failed():
		quit(2)
		return
	if DisplayServer.get_name() == "headless":
		# Paced like a window, so the step guard lasts as long as the moments it waits on.
		Engine.max_fps = HEADLESS_FPS
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	WalkBase.begin(self, out, _options)
	_run.call_deferred()


func _run() -> void:
	print(DisplayFlags.apply(root, _options))
	# Loaded at run time: the walks name autoloads, which a --script tool can't see.
	if _options.has("tutorial"):
		var script: GDScript = load("res://tools/tutorial_walk.gd")
		var walk: Object = script.new()
		await walk.call("run", WalkProfile.folder(TUTORIAL_BASE, _options))
		var counts: Array = [WalkBase.shots, walk.get("clicks"), WalkBase.misses]
		print("tutorial shots=%d clicks=%d misclicks=%d" % counts)
	else:
		var script: GDScript = load("res://tools/playtest_demo.gd")
		var demo: Object = script.new()
		await demo.call("run", WalkProfile.folder(DEMO_BASE, _options), _rounds)
	print("layout findings=%d" % WalkBase.layout_found)
	quit(1 if WalkBase.misses > 0 else 0)
