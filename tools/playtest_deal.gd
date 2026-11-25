extends RefCounted
## The playtest's frames of what a deal shows before the bid (ADR 0043), in a sandbox put
## back after, as the playtest's file and wild-rank frames are. Neither the Handicap nor
## the Tally Clerk need come up in the walk's own run, so both are staged on the table at
## the bid: the Handicap as the Set's boss with two of a villager's dealt cards set aside,
## its beat photographed as the cards lie on the pile and again once they have left, with
## the rules slip naming them; then the kitty the Tally Clerk shows, face up under its
## note. Loaded at run time by playtest.gd, so it reaches every UI node as Object, Node or
## Control, never by a ui/ class name. Development only; tools/ never ships.

const SETTLE_SECONDS: float = 1.8
const WAIT_SECONDS: float = 20.0
## When the set-aside beat is photographed: as the cards land, and once they have left.
const BEAT_SECONDS: Array[float] = [0.5, 2.6]
const ASIDE: int = 2

var shots: int = 0
var misclicks: int = 0

var _tree: SceneTree
var _app: Node
var _out: String
var _headless: bool


func _init(tree: SceneTree, app: Node, out: String, headless: bool, shot_count: int) -> void:
	_tree = tree
	_app = app
	_out = out
	_headless = headless
	shots = shot_count


## The table's frames, from the round under way, put back as they were after.
func table() -> void:
	var controller: Object = _app.get("controller")
	var loop: RunLoop = controller.get("_loop")
	var deal: DealResult = loop.get("_deal")
	if deal == null:
		_fail("NO DEAL FOR THE DEAL FRAMES")
		return
	var snapshot: Dictionary = loop.record.to_dict()
	var was_boss: String = loop.state.boss_id
	_app.call("show_screen", "table", true)
	await _frames(20)
	await _until(_idle)
	loop.state.boss_id = "the_handicap"
	var ids: PackedStringArray = []
	for card: CardInstance in deal.hands[1].cards().slice(0, ASIDE):
		deal.set_aside.append(card)
		ids.append(str(card.id()))
	var beats: Object = _part("_deal_beats")
	var pile: Object = _part("_pile")
	pile.call("clear")
	var aside: RunEvent = RunEvent.new(RunEvent.Type.CARDS_SET_ASIDE, 0, 0, 0.0, ",".join(ids))
	beats.call("on_event", aside, false)
	var waited: float = 0.0
	for index: int in BEAT_SECONDS.size():
		await _tree.create_timer(BEAT_SECONDS[index] - waited).timeout
		waited = BEAT_SECONDS[index]
		await _snap("table_set_aside_%d" % index)
	var strip: Object = _part("_debuffs")
	strip.call("show_debuffs", controller)
	var line: String = tr("table.set_aside").format({"cards": controller.call("set_aside_names")})
	var lines: Object = strip.get("_lines")
	_expect(str(lines.call("get_parsed_text")).contains(line), "NO SET ASIDE ON SLIP")
	await _shot("table_set_aside_slip")
	var kitty: PackedStringArray = []
	for card: CardInstance in deal.kitty:
		kitty.append(str(card.id()))
	pile.call("clear")
	var seen: RunEvent = RunEvent.new(RunEvent.Type.KITTY_SEEN, 0, 0, 0.0, ",".join(kitty))
	beats.call("on_event", seen, false)
	_expect(bool(beats.call("kitty_shown")), "NO KITTY SEEN")
	await _shot("table_kitty_seen")
	deal.set_aside.clear()
	loop.state.boss_id = was_boss
	var saves: Object = _tree.root.get_node("Saves").call("run_service")
	saves.call("save", snapshot, ContentStamp.extras())
	_app.call("resume_to_screen")
	await _frames(30)


func _current() -> Node:
	var switcher: Object = _app.get("switcher")
	return switcher.call("current")


func _idle() -> bool:
	var events: Object = _part("_player")
	return events == null or bool(events.call("is_idle"))


## A part of the table now on screen, by its property name, or null off it.
func _part(part: String) -> Object:
	var screen: Node = _current()
	if screen == null or not is_instance_valid(screen) or screen.get("_player") == null:
		return null
	return screen.get(part)


func _until(ready: Callable, seconds: float = WAIT_SECONDS) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while not bool(ready.call()):
		if Time.get_ticks_msec() > deadline:
			return false
		await _frames(1)
	return true


func _expect(held: bool, failure: String) -> void:
	if not held:
		_fail(failure)


func _fail(reason: String) -> void:
	print("MISS %s" % reason)
	misclicks += 1


func _frames(count: int) -> void:
	for _frame: int in count:
		await _tree.process_frame


## A frame after the table settles.
func _shot(name: String) -> void:
	await _tree.create_timer(SETTLE_SECONDS).timeout
	await _snap(name)


## A frame now, mid-beat.
func _snap(name: String) -> void:
	_tree.call("audit_layout", name)
	shots += 1
	if _headless:
		print("FRAME %02d_%s" % [shots, name])
		return
	await RenderingServer.frame_post_draw
	var path: String = _out.path_join("%02d_%s.png" % [shots, name])
	_tree.root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
