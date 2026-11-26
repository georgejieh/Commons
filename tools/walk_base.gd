class_name WalkBase
extends RefCounted
## What every part of the playtest walk shares (tools/playtest.gd): the app it walks, how
## it clicks, presses and waits, how it takes a frame, and the counts the walk reports.
## The walk is one run of one tool, so the app, the counts and where frames go are held
## once, on the class, and every part reads the same ones. A part reaches a private member
## of the game only through member(), invoke() and assign(), which fail the walk naming
## the member when it is gone, so a rename in the game fails a walk instead of reading
## null. A failure prints "MISS <reason>"; a click that did nothing prints "MISCLICK
## <reason>"; the cloud workflow fails on either. Loaded by the walk at run time, so it
## reaches every UI node as Object, Node or Control, never by a ui/ class name.
## Development only; tools/ never ships.

## Seconds a frame waits for count-ups and entrances, which run on the clock, to settle.
const SETTLE_SECONDS: float = 1.8
## Seconds between pictures of a moment in motion.
const SNAP_SECONDS: float = 0.22
## The longest a wait on something the table does may take, in real seconds: generous,
## since a headless run and a software-rendered one go at different paces.
const WAIT_SECONDS: float = 20.0
## Where a card in the fan is clicked: on the strip the next card leaves showing, from its
## left edge, at this share of its height. The last card shows whole and is clicked at its
## middle.
const GRIP_X: float = 24.0
const GRIP_HEIGHT: float = 0.45
## The last corruption stage, at which the walk photographs things worn.
const LAST_STAGE: int = 9

static var tree: SceneTree
static var app: Node
## The folder frames are saved in; none are saved without a window.
static var out: String = ""
static var headless: bool = false
static var options: ToolOptions
static var shots: int = 0
static var misses: int = 0
static var layout_found: int = 0
static var _audit: RefCounted = null


## Starts a walk: where its frames go and whether there is a window to take them.
static func begin(walk_tree: SceneTree, frames_out: String, walk_options: ToolOptions) -> void:
	tree = walk_tree
	out = frames_out
	options = walk_options
	headless = DisplayServer.get_name() == "headless"


## The member called name of object, failing the walk when object has none.
static func member(object: Object, name: String) -> Variant:
	if object == null or not (name in object):
		_missing(object, name)
		return null
	return object.get(name)


## The controller's view called name (texts, figures, table, items, store or seats), which
## its queries are read through, failing the walk when it has none.
static func view(controller: Object, name: String) -> Object:
	return member(controller, name)


## Calls object's method called name with arguments, failing the walk when it has none.
static func invoke(object: Object, name: String, arguments: Array = []) -> Variant:
	if object == null or not object.has_method(name):
		_missing(object, name)
		return null
	return object.callv(name, arguments)


## Sets object's member called name, failing the walk when object has none.
static func assign(object: Object, name: String, value: Variant) -> void:
	if object == null or not (name in object):
		_missing(object, name)
		return
	object.set(name, value)


## Reads the screen at rest for layout faults (tools/layout_audit.gd) and prints each new
## one as a LAYOUT line under the frame's name. A finding is to be read, not a failure.
static func audit_layout(name: String) -> void:
	if _audit == null:
		var script: GDScript = load("res://tools/layout_audit.gd")
		_audit = script.new()
	var found: PackedStringArray = _audit.call("check", tree.root)
	for line: String in found:
		print("LAYOUT %s %s" % [name, line])
	layout_found += found.size()


static func _missing(object: Object, name: String) -> void:
	var holder: String = "null"
	if object != null:
		var script: Script = object.get_script()
		holder = object.get_class() if script == null else script.resource_path
	print("MISS NO MEMBER %s ON %s" % [name, holder])
	push_error("the walk reached %s on %s, which has none" % [name, holder])
	misses += 1


## The run's controller.
func _controller() -> Object:
	return app.get("controller")


## The run's loop, which only a development tool reaches into.
func _loop() -> RunLoop:
	return _controller().call("run_loop")


func _current() -> Node:
	var switcher: Object = app.get("switcher")
	return switcher.call("current")


func _screen_id() -> String:
	var switcher: Object = app.get("switcher")
	return switcher.call("current_id")


## A part of the table now on screen, by its method or member name, or null when the
## screen is not the table.
func _part(part: String) -> Object:
	var screen: Node = _current()
	if screen == null or not is_instance_valid(screen) or screen.get("_player") == null:
		return null
	if screen.has_method(part):
		return screen.call(part)
	return member(screen, part)


## True once the table's events have all played, or when the table is not on screen.
func _idle() -> bool:
	var events: Object = _part("_player")
	return events == null or bool(events.call("is_idle"))


## Writes snapshot back as the run's save and resumes it, so a sandbox the walk staged
## leaves the run and its record as they were.
func _restore(snapshot: Dictionary) -> void:
	var saves: Object = tree.root.get_node("Saves").call("run_service")
	saves.call("save", snapshot, ContentStamp.extras())
	app.call("resume_to_screen")
	await _frames(30)


## Waits until an opened envelope's papers are at rest.
func _settled(overlay: Object) -> void:
	if overlay == null:
		return
	if not await _until(func() -> bool: return not bool(overlay.call("is_busy"))):
		_fail("ENVELOPE NEVER SETTLED")


func _fail(reason: String) -> void:
	print("MISS %s" % reason)
	misses += 1


## A click, or a press of a key, that did nothing it should have.
func _misclick(reason: String) -> void:
	print("MISCLICK %s" % reason)
	misses += 1


func _expect(held: bool, failure: String) -> void:
	if not held:
		_fail(failure)


func _frames(count: int) -> void:
	for _frame: int in count:
		await tree.process_frame


## Waits until ready says so, at most seconds of real time, and says whether it did.
## ready looks up what it reads each time, so it never holds a node a new round may free.
func _until(ready: Callable, seconds: float = WAIT_SECONDS) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while ready.is_valid() and not bool(ready.call()):
		if Time.get_ticks_msec() > deadline:
			return false
		await _frames(1)
	if not ready.is_valid():
		_fail("WAIT LOST ITS SUBJECT")
		return false
	return true


## Moves the pointer to at and clicks there with the left button, as a mouse does. Every
## event the walk makes carries the device id 4.7 gives a real mouse or keyboard.
func _mouse_click(at: Vector2) -> void:
	await _mouse_move(at, 0)
	await _mouse_button(at, true)
	await _mouse_button(at, false)


func _mouse_move(at: Vector2, mask: int) -> void:
	var move: InputEventMouseMotion = InputEventMouseMotion.new()
	move.position = at
	move.button_mask = mask
	move.device = InputEvent.DEVICE_ID_MOUSE
	tree.root.push_input(move, true)
	await _frames(1)


func _mouse_button(at: Vector2, pressed: bool) -> void:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.device = InputEvent.DEVICE_ID_MOUSE
	click.pressed = pressed
	click.position = at
	click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	tree.root.push_input(click, true)
	await _frames(1)


## Presses and lets go of key, as a player at the keyboard does.
func _press_key(key: Key) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = key
		event.device = InputEvent.DEVICE_ID_KEYBOARD
		event.physical_keycode = key
		event.pressed = pressed
		tree.root.push_input(event, true)
		await _frames(2)


## Rests the pointer over a control, as a person reading it would.
func _hover(control: Control) -> void:
	await _mouse_move(control.get_global_transform_with_canvas() * (control.size / 2.0), 0)
	await _frames(5)


## Moves the pointer itself to a place on the canvas. Rich text finds the word under the
## pointer from where the engine says the mouse is, not from an event's own position: the
## real cursor in a window, Input's record without one, both in the window's pixels.
func _point_at(at: Vector2) -> void:
	var move: InputEventMouseMotion = InputEventMouseMotion.new()
	move.position = tree.root.get_final_transform() * at
	move.global_position = move.position
	move.device = InputEvent.DEVICE_ID_MOUSE
	tree.root.warp_mouse(at)
	Input.parse_input_event(move)


## Clicks the middle of a button that shows and can be pressed; anything else fails.
func _press(button: Button) -> void:
	if button == null or not button.is_visible_in_tree() or button.disabled:
		var named: String = "(none)" if button == null else "'%s'" % button.text
		_fail("NO BUTTON %s to press" % named)
		return
	await _mouse_click(button.get_global_transform_with_canvas() * (button.size / 2.0))


## Presses the first button inside node.
func _press_in(node: Node) -> void:
	var buttons: Array[Node] = node.find_children("*", "Button", true, false)
	await _press(null if buttons.is_empty() else buttons[0] as Button)


## The button under node that shows text, or null.
func _button_in(node: Node, text: String) -> Button:
	for child: Node in node.find_children("*", "Button", true, false):
		var button: Button = child as Button
		if button.text == text and button.is_visible_in_tree():
			return button
	return null


## Presses the button under node that shows text; none fails the walk.
func _press_text_in(node: Node, text: String) -> void:
	var button: Button = _button_in(node, text)
	if button == null:
		_fail("NO BUTTON '%s'" % text)
		return
	await _press(button)


## Presses the screen's button that shows text, and waits for what it opens.
func _click_button_with_text(text: String) -> void:
	await _frames(5)
	var button: Button = _button_in(_current(), text)
	if button == null:
		_fail("NO BUTTON '%s'" % text)
		return
	await _press(button)
	await _frames(20)


## Presses the screen's first button that shows and can be pressed.
func _click_first_button() -> void:
	for child: Node in _current().find_children("*", "Button", true, false):
		var button: Button = child as Button
		if button.is_visible_in_tree() and not button.disabled:
			await _press(button)
			return
	_fail("NO BUTTON to press on %s" % _screen_id())


## Clicks the strip of the card that the next card in the fan leaves showing.
func _click_card(table: Node, card_id: int) -> void:
	var views: Array = member(member(table, "_hand_view"), "_views")
	for index: int in views.size():
		var view: Control = views[index]
		if view.get("card_id") != card_id:
			continue
		var grip: float = GRIP_X if index < views.size() - 1 else view.size.x / 2.0
		var local: Vector2 = Vector2(grip, view.size.y * GRIP_HEIGHT)
		await _mouse_click(view.get_global_transform_with_canvas() * local)
		return
	_misclick("card %d not in the fan" % card_id)


## A picture of a moment in motion: a short beat on, with no wait for things to settle.
func _snap(name: String) -> void:
	await tree.create_timer(SNAP_SECONDS).timeout
	await _picture(name)


## A picture once the screen has settled, read for layout faults first.
func _shot(name: String) -> void:
	await tree.create_timer(SETTLE_SECONDS).timeout
	audit_layout(name)
	await _picture(name)


## Counts and names a frame, and saves it when there is a window; a frame that cannot be
## saved fails the walk.
func _picture(name: String) -> void:
	shots += 1
	var named: String = "%02d_%s" % [shots, name]
	print("FRAME %s" % named)
	if headless:
		return
	await RenderingServer.frame_post_draw
	var image: Image = tree.root.get_texture().get_image()
	if not ToolFiles.save_png(image, out.path_join(named + ".png")):
		_fail("FRAME %s NOT SAVED" % named)
