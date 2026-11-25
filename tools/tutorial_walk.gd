extends RefCounted
## The playtest's --tutorial mode (ADR 0026): starts with no profile, names the family on
## the surname page (ADR 0028), a village name refused first and then a ticket picked
## with a real click, takes the Arrival page, then plays every step of the arrival with
## real clicks on what each step rings, at the table's own pace, taking a frame at each
## prompt, once after a refused action, and at run setup. A step that does not advance prints a
## MISCLICK line, which the cloud workflow fails on. Loaded at run time by playtest.gd,
## so it reaches every UI node as Object, Node or Control, never by a ui/ class name.
## Development only; tools/ never ships.

const SAVE_FILE: String = "run.json"
const SETTLE_SECONDS: float = 1.2
## The longest a step may take to come, or to be taken, in real seconds.
const WAIT_SECONDS: float = 30.0
## Where a card in the fan is clicked when the next card covers the rest of it.
const GRIP_X: float = 24.0
## TutorialDirector.Phase.PROMPT and TutorialStep.Action values, by number.
const PROMPT: int = 1
const BID_CALL: int = 0
const BID_PASS: int = 1
const PLAY: int = 2
const PASS: int = 3
const NEED: int = 4

var misclicks: int = 0
var shots: int = 0
var clicks: int = 0

var _tree: SceneTree
var _root: Window
var _app: Node
var _out: String
var _headless: bool
var _refused: bool = false
## The surname picked on the surname page, which the profile's first save must hold.
var _surname: String = ""


## Plays the arrival through and returns when it has reached run setup or failed.
func run(tree: SceneTree, out: String, headless: bool, folder: String) -> void:
	_tree = tree
	_root = tree.root
	_out = out
	_headless = headless
	var saves: Node = _root.get_node("Saves")
	saves.call("use_run_path", folder + SAVE_FILE)
	for service: Object in [saves.call("run_service"), saves.call("profile_service")]:
		service.call("delete")
	_app = (load("res://ui/main.tscn") as PackedScene).instantiate()
	_app.set("demo", true)
	_root.add_child(_app)
	await _frames(20)
	if _screen_id() == "content_note":
		await _shot("tutorial_content_note")
		await _press(_buttons(_screen())[0])
		await _frames(20)
	_expect(_screen_id() == "surname", "MISCLICK no surname page with no profile")
	await _surname_page()
	_expect(_screen_id() == "arrival", "MISCLICK no Arrival page after the surname page")
	await _shot("tutorial_arrival")
	await _press(_screen().call("sit_in_button"))
	await _frames(20)
	var arrival: Object = _app.get("arrival")
	var guard: int = 0
	while bool(arrival.call("is_running")) and guard < 40:
		guard += 1
		if not await _until(_prompting):
			_fail("MISCLICK no prompt after step %d" % _index())
			break
		var step: Resource = _director().call("step")
		await _shot("tutorial_step_%s" % step.get("id"))
		if not _refused and int(step.get("action")) == PLAY:
			await _try_refused()
		await _take(step)
		if not await _until(func() -> bool: return _moved_past(step)):
			_fail("MISCLICK step %s did not advance" % step.get("id"))
			break
	if await _until(func() -> bool: return _screen_id() == "run_setup"):
		await _shot("tutorial_run_setup")
	else:
		_fail("MISCLICK the arrival did not end at run setup")
	var first: ProfileData = Profile.read(saves.call("profile_service"))
	var seen: Array = first.seen
	_expect(seen == ["tutorial"], "MISCLICK the profile's first save is %s" % str(seen))
	_expect(first.surname == _surname, "MISCLICK the profile holds surname %s" % first.surname)


## The surname page: a village family's name is refused and the page stays; then a ticket
## clicked fills the field and Confirm takes it to the Arrival page.
func _surname_page() -> void:
	var page: Node = _screen()
	await _shot("surname_page")
	var field: LineEdit = page.call("field")
	field.text = tr("villager.wang")
	await _press(page.call("confirm_button"))
	await _frames(4)
	var refused: bool = not str(page.call("note")).is_empty() and _screen_id() == "surname"
	_expect(refused, "MISCLICK a village surname was taken")
	await _shot("surname_refused")
	var tickets: Array = page.call("tickets")
	var ticket: Button = tickets[int(tickets.size() / 2.0)]
	await _press(ticket)
	clicks += 1
	_surname = field.text
	_expect(_surname == ticket.get("surname"), "MISCLICK the ticket left %s" % _surname)
	await _press(page.call("confirm_button"))
	await _frames(20)


## A disallowed action, once: Pass while a play is asked for. Nothing moves and the slip
## pulses.
func _try_refused() -> void:
	_refused = true
	var before: int = _index()
	var actions: Object = _screen().call("actions")
	await _press(actions.get("pass_turn"))
	await _frames(4)
	await _shot("tutorial_refused")
	_expect(_index() == before and _director().call("phase") == PROMPT, "MISCLICK refused moved")


## Takes the step with clicks on what it rings.
func _take(step: Resource) -> void:
	var action: int = int(step.get("action"))
	var actions: Object = null
	if _screen_id() == "table":
		actions = _screen().call("actions")
	match action:
		BID_CALL:
			await _press(actions.get("call"))
		BID_PASS:
			await _press(actions.get("decline"))
		PASS:
			await _press(actions.get("pass_turn"))
		NEED:
			var panel: Object = _screen().call("need_panel")
			await _press(panel.call("declare_button"))
		PLAY:
			await _play(step, actions)
		_:
			await _button(step, actions)


## Picks the ringed cards by hand, then presses Play.
func _play(step: Resource, actions: Object) -> void:
	var hand: Object = _app.get("hand")
	hand.call("clear")
	await _frames(2)
	for card_id: int in step.get("cards"):
		await _click_card(card_id)
		clicks += 1
		if not bool(hand.call("is_selected", card_id)):
			_fail("MISCLICK step %s card %d" % [step.get("id"), card_id])
	await _frames(2)
	await _press(actions.get("play"))


func _button(step: Resource, actions: Object) -> void:
	var named: String = step.get("button")
	match named:
		"rules":
			await _press(actions.get("rules"))
			await _until(func() -> bool: return _slip_line() == tr(step.get("then_key")))
			await _shot("tutorial_rules_open")
			var sheet: Object = _screen().get("_cheat_sheet")
			await _press(sheet.call("close_button"))
		"begin":
			await _press(_layer().call("begin_button"))
		_:
			if not String(step.get("via")).is_empty():
				await _press(_target_button(step.get("via")))
				await _frames(20)
				await _until(func() -> bool: return _screen_id() == step.get("screen"))
				await _frames(10)
			await _press(_target_button(step.get("highlight")))


## The button inside what the screen shown rings for key.
func _target_button(key: String) -> Button:
	var target: Control = _screen().call("tutorial_target", key)
	if target == null:
		print("NO BUTTON for %s" % key)
		return null
	if target is Button:
		return target as Button
	for found: Node in target.find_children("*", "Button", true, false):
		return found as Button
	return null


func _click_card(card_id: int) -> void:
	var hand_view: Control = _screen().get("_hand_view")
	var views: Array = hand_view.get("_views")
	for index: int in views.size():
		var view: Control = views[index]
		if view.get("card_id") != card_id:
			continue
		var visible_x: float = GRIP_X if index < views.size() - 1 else view.size.x / 2.0
		var local: Vector2 = Vector2(visible_x, view.size.y * 0.45)
		await _mouse_click(view.get_global_transform_with_canvas() * local)
		return
	_fail("MISCLICK card %d not in the fan" % card_id)


func _director() -> Object:
	var arrival: Object = _app.get("arrival")
	return arrival.get("director")


func _layer() -> Control:
	var arrival: Object = _app.get("arrival")
	return arrival.get("layer")


func _index() -> int:
	var director: Object = _director()
	return -1 if director == null else int(director.call("index"))


func _prompting() -> bool:
	var director: Object = _director()
	return director != null and int(director.call("phase")) == PROMPT


func _moved_past(step: Resource) -> bool:
	var director: Object = _director()
	return director == null or director.call("step") != step


func _slip_line() -> String:
	var slip: Object = _layer().call("slip")
	return slip.call("line")


func _screen() -> Node:
	var switcher: Object = _app.get("switcher")
	return switcher.call("current")


func _screen_id() -> String:
	var switcher: Object = _app.get("switcher")
	return switcher.call("current_id")


func _buttons(screen: Node) -> Array[Button]:
	var found: Array[Button] = []
	for node: Node in screen.find_children("*", "Button", true, false):
		if (node as Button).is_visible_in_tree():
			found.append(node as Button)
	return found


func _until(ready: Callable, seconds: float = WAIT_SECONDS) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while not bool(ready.call()):
		if Time.get_ticks_msec() > deadline:
			return false
		await _frames(1)
	return true


func _press(button: Button) -> void:
	if button == null or not button.is_visible_in_tree():
		print("NO BUTTON at step %d" % _index())
		return
	await _mouse_click(button.get_global_transform_with_canvas() * (button.size / 2.0))


func _mouse_click(at: Vector2) -> void:
	var move: InputEventMouseMotion = InputEventMouseMotion.new()
	move.position = at
	_root.push_input(move, true)
	await _frames(1)
	for pressed: bool in [true, false]:
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = at
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		_root.push_input(click, true)
		await _frames(1)
	await _frames(4)


func _frames(count: int) -> void:
	for _frame: int in count:
		await _tree.process_frame


func _shot(name: String, settle: float = SETTLE_SECONDS) -> void:
	if settle > 0.0:
		await _tree.create_timer(settle).timeout
	shots += 1
	if _headless:
		print("FRAME %02d_%s" % [shots, name])
		return
	await RenderingServer.frame_post_draw
	var path: String = _out.path_join("%02d_%s.png" % [shots, name])
	_root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))


func _expect(held: bool, failure: String) -> void:
	if not held:
		_fail(failure)


func _fail(reason: String) -> void:
	print(reason)
	misclicks += 1
