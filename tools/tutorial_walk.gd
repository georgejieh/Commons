extends WalkBase
## The playtest's --tutorial mode (ADR 0026): starts with no profile, names the family on
## the surname page (ADR 0028), a village name refused first and then a ticket picked
## with a real click, takes the Arrival page, then plays every step of the arrival with
## real clicks on what each step rings, at the table's own pace, taking a frame at each
## prompt, once after a refused action, and at run setup. A step that does not advance is
## a misclick, which the cloud workflow fails on. Development only; tools/ never ships.

## The longest a step may take to come, or to be taken, in real seconds: the arrival
## waits on its own beats, longer than the table's.
const STEP_SECONDS: float = 30.0
## Frames the arrival is given after a click to answer it.
const CLICK_FRAMES: int = 4
## Steps the walk may take before the arrival is failed as never ending.
const MOST_STEPS: int = 40

var clicks: int = 0

var _refused: bool = false
## The surname picked on the surname page, which the profile's first save must hold.
var _surname: String = ""


## Plays the arrival through and returns when it has reached run setup or failed.
func run(folder: String) -> void:
	var saves: Node = tree.root.get_node("Saves")
	saves.call("use_run_path", folder + WalkProfile.RUN_FILE)
	for service: Object in [saves.call("run_service"), saves.call("profile_service")]:
		service.call("delete")
	app = (load("res://ui/main.tscn") as PackedScene).instantiate()
	app.set("demo", true)
	tree.root.add_child(app)
	await _frames(20)
	if _screen_id() == "content_note":
		await _shot("tutorial_content_note")
		await _press(_buttons(_current())[0])
		await _frames(20)
	_expect(_screen_id() == "surname", "NO SURNAME PAGE WITH NO PROFILE")
	await _surname_page()
	_clicked(_screen_id() == "arrival", "no Arrival page after the surname page")
	await _shot("tutorial_arrival")
	await _press(_current().call("sit_in_button"))
	await _frames(20)
	var arrival: Object = app.get("arrival")
	var guard: int = 0
	while bool(arrival.call("is_running")) and guard < MOST_STEPS:
		guard += 1
		if not await _until(_prompting, STEP_SECONDS):
			_misclick("no prompt after step %d" % _index())
			break
		var step: Resource = _director().call("step")
		await _shot("tutorial_step_%s" % step.get("id"))
		if not _refused and int(step.get("action")) == TutorialStep.Action.PLAY:
			await _try_refused()
		await _take(step)
		if not await _until(func() -> bool: return _moved_past(step), STEP_SECONDS):
			_misclick("step %s did not advance" % step.get("id"))
			break
	if await _until(func() -> bool: return _screen_id() == "run_setup", STEP_SECONDS):
		await _shot("tutorial_run_setup")
	else:
		_misclick("the arrival did not end at run setup")
	var first: ProfileData = Profile.read(saves.call("profile_service"))
	var seen: Array = first.seen
	_expect(seen == ["tutorial"], "THE PROFILE'S FIRST SAVE IS %s" % str(seen))
	_expect(first.surname == _surname, "THE PROFILE HOLDS SURNAME %s" % first.surname)


## The surname page: a village family's name is refused and the page stays; then a ticket
## clicked fills the field and Confirm takes it to the Arrival page.
func _surname_page() -> void:
	var page: Node = _current()
	await _shot("surname_page")
	var field: LineEdit = page.call("field")
	field.text = tr("villager.wang")
	await _press(page.call("confirm_button"))
	await _frames(4)
	var refused: bool = not str(page.call("note")).is_empty() and _screen_id() == "surname"
	_clicked(refused, "a village surname was taken")
	await _shot("surname_refused")
	var tickets: Array = page.call("tickets")
	var ticket: Button = tickets[int(tickets.size() / 2.0)]
	await _press(ticket)
	clicks += 1
	_surname = field.text
	_clicked(_surname == ticket.get("surname"), "the ticket left %s" % _surname)
	await _press(page.call("confirm_button"))
	await _frames(20)


## A disallowed action, once: Pass while a play is asked for. Nothing moves and the slip
## pulses.
func _try_refused() -> void:
	_refused = true
	var before: int = _index()
	var actions: Object = _current().get("actions")
	await _press(actions.get("pass_turn"))
	await _frames(4)
	await _shot("tutorial_refused")
	var held: bool = (
		_index() == before and _director().call("phase") == TutorialDirector.Phase.PROMPT
	)
	_clicked(held, "refused moved")


## Takes the step with clicks on what it rings.
func _take(step: Resource) -> void:
	var action: int = int(step.get("action"))
	var actions: Object = null
	if _screen_id() == "table":
		actions = _current().get("actions")
	match action:
		TutorialStep.Action.BID_CALL:
			await _press(actions.get("call_landlord"))
		TutorialStep.Action.BID_PASS:
			await _press(actions.get("decline"))
		TutorialStep.Action.PASS:
			await _press(actions.get("pass_turn"))
		TutorialStep.Action.NEED:
			var panel: Object = _current().get("need_panel")
			await _press(panel.call("declare_button"))
		TutorialStep.Action.PLAY:
			await _play(step, actions)
		_:
			await _button(step, actions)


## Picks the ringed cards by hand, then presses Play.
func _play(step: Resource, actions: Object) -> void:
	var hand: Object = app.get("hand")
	hand.call("clear")
	await _frames(2)
	for card_id: int in step.get("cards"):
		await _click_card(_current(), card_id)
		clicks += 1
		if not bool(hand.call("is_selected", card_id)):
			_misclick("step %s card %d" % [step.get("id"), card_id])
	await _frames(2)
	await _press(actions.get("play"))


func _button(step: Resource, actions: Object) -> void:
	var named: String = step.get("button")
	match named:
		"rules":
			await _press(actions.get("rules"))
			await _until(func() -> bool: return _slip_line() == tr(step.get("then_key")))
			await _shot("tutorial_rules_open")
			var sheet: Object = member(_current(), "cheat_sheet")
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
	var target: Control = _current().call("tutorial_target", key)
	if target == null:
		_fail("NO BUTTON for %s" % key)
		return null
	if target is Button:
		return target as Button
	for found: Node in target.find_children("*", "Button", true, false):
		return found as Button
	return null


func _director() -> Object:
	var arrival: Object = app.get("arrival")
	return arrival.get("director")


func _layer() -> Control:
	var arrival: Object = app.get("arrival")
	return arrival.get("layer")


func _index() -> int:
	var director: Object = _director()
	return -1 if director == null else int(director.call("index"))


func _prompting() -> bool:
	var director: Object = _director()
	return director != null and int(director.call("phase")) == TutorialDirector.Phase.PROMPT


func _moved_past(step: Resource) -> bool:
	var director: Object = _director()
	return director == null or director.call("step") != step


func _slip_line() -> String:
	var slip: Object = _layer().call("slip")
	return slip.call("line")


func _buttons(screen: Node) -> Array[Button]:
	var found: Array[Button] = []
	for node: Node in screen.find_children("*", "Button", true, false):
		if (node as Button).is_visible_in_tree():
			found.append(node as Button)
	return found


## A click, then the frames the arrival takes to answer it.
func _mouse_click(at: Vector2) -> void:
	await super(at)
	await _frames(CLICK_FRAMES)


## A misclick, unless held.
func _clicked(held: bool, failure: String) -> void:
	if not held:
		_misclick(failure)
