class_name TutorialLayer
extends Control
## The arrival over every screen it plays on (ADR 0026): Wang's slip, the light on what
## the step asks for (TutorialGlow), the Skip button in the corner and the question it
## asks, and the "Begin your first year" button for the last step. It reads the
## director and the screen shown; it sends nothing to the run. Screens name their
## targets with tutorial_target(key) or, for the table, tutorial_rects(key); they may
## name what the slip must keep clear of, or with tutorial_home(extent) the one place
## the slip stands, as the table does. It draws above every piece a screen lifts (the
## store's slips and seals, the envelope), and below the app's menu.

const CORNER: float = 24.0
## From the screen's foot: close under it, so Skip clears the ledger's foot at the table.
const FOOT: float = 8.0
const BEGIN_GAP: float = 16.0
## Above the highest piece a screen lifts, the envelope overlay's 4.
const DRAW_ORDER: int = 5

var _app: DemoApp = null
var _director: TutorialDirector = null
var _slip: TutorialSlip = TutorialSlip.new()
var _glow: TutorialGlow = TutorialGlow.new()
var _skip: Button = ScreenKit.button("", CommonsTheme.GHOST)
var _begin: Button = ScreenKit.button("", CommonsTheme.PRIMARY)
var _confirm: SkipConfirm = SkipConfirm.new()
## The step and target focus was last put on, so it moves only when they change.
var _focused: String = ""
## The step whose follow-up beat is running.
var _beat_for: int = -1


func _ready() -> void:
	# Offsets too: anchors alone keep the size a new control has, none.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = DRAW_ORDER
	for child: Control in [_glow, _slip, _begin, _skip, _confirm]:
		add_child(child)
	_skip.text = tr("tutorial.skip")
	_skip.pressed.connect(_confirm.ask)
	_begin.text = tr("tutorial.begin")
	_begin.pressed.connect(_on_begin)
	_confirm.skipped.connect(func() -> void: _app.arrival.skip())
	_begin.visible = false
	visible = false


## Starts showing the arrival the director walks.
func attach(app: DemoApp, director: TutorialDirector) -> void:
	_app = app
	_director = director
	_focused = ""
	_beat_for = -1
	director.changed.connect(_on_changed)
	director.refused.connect(_slip.refuse)
	_slip.set_face(app.seat_portrait(1, TutorialSlip.FACE))
	visible = true
	_on_changed()


func detach() -> void:
	_director = null
	_confirm.visible = false
	_glow.light([])
	_slip.say("")
	_begin.visible = false
	visible = false


## The app showed a screen. Every screen but the table reports where the run stands at
## once; the table reports when its events have played out.
func on_screen(screen_id: String) -> void:
	if _director != null and screen_id != "table" and _app.controller.has_run():
		_director.ready(screen_id, _app.controller.awaiting())


func slip() -> TutorialSlip:
	return _slip


func glow() -> TutorialGlow:
	return _glow


func skip_button() -> Button:
	return _skip


func begin_button() -> Button:
	return _begin


func confirm() -> SkipConfirm:
	return _confirm


func _on_changed() -> void:
	if _director == null:
		return
	var key: String = _director.line_key()
	_slip.say(tr(key) if not key.is_empty() else "")
	_begin.visible = _director.highlight() == "begin"
	var at: String = "%d:%s" % [_director.index(), _director.highlight()]
	if _director.phase() == TutorialDirector.Phase.PROMPT and at != _focused:
		_focused = at
		_focus_target.call_deferred()
	if _director.is_held() and _beat_for != _director.index():
		_beat_for = _director.index()
		var timer: SceneTreeTimer = get_tree().create_timer(_director.follow_seconds())
		timer.timeout.connect(_release.bind(_beat_for))
	_layout()


func _release(index: int) -> void:
	if _director != null and _director.index() == index:
		_director.release()


func _process(_delta: float) -> void:
	if _director != null:
		_layout()


## Lights the target on the screen shown and stands the slip by it, or at its home.
func _layout() -> void:
	var size_now: Vector2 = get_viewport_rect().size
	_skip.reset_size()
	_skip.position = size_now - _skip.size - Vector2(CORNER, FOOT)
	_begin.reset_size()
	_begin.position = Vector2(
		_skip.position.x - BEGIN_GAP - _begin.size.x, size_now.y - _begin.size.y - FOOT
	)
	var guide: Object = _guide()
	var hidden: bool = _app.menu_is_open()
	if guide != null and guide.has_method("tutorial_hidden"):
		hidden = hidden or bool(guide.call("tutorial_hidden"))
	var showing: bool = not hidden and _on_its_screen()
	_slip.visible = showing and not _slip.line().is_empty()
	var key: String = _director.highlight() if showing else ""
	_glow.light(_targets(guide, key))
	var target: Rect2 = _glow.lit_area()
	if not target.has_area():
		return
	if guide != null and guide.has_method("tutorial_home"):
		_slip.reset_size()
		var home: Vector2 = guide.call("tutorial_home", _slip.size)
		if home.is_finite():
			_slip.global_position = home
			return
	var avoid: Array[Rect2] = []
	if guide != null and guide.has_method("tutorial_avoid"):
		avoid.assign(guide.call("tutorial_avoid"))
	_slip.place(target, avoid, size_now)


func _on_its_screen() -> bool:
	return _app.switcher.current_id() == _director.screen()


## What answers for the screen shown: the screen, or for the table its tutorial guide.
func _guide() -> Object:
	var screen: Node = _app.switcher.current()
	if screen == null:
		return null
	if screen.has_method("tutorial"):
		return screen.call("tutorial")
	return screen


## What the step asks for on the screen shown, each thing's place in screen space.
func _targets(guide: Object, key: String) -> Array[Rect2]:
	var found: Array[Rect2] = []
	if key.is_empty() or guide == null:
		return found
	if key == "begin":
		found.append(_begin.get_global_rect())
	elif guide.has_method("tutorial_rects"):
		found.assign(guide.call("tutorial_rects", key))
	elif guide.has_method("tutorial_target"):
		var control: Control = guide.call("tutorial_target", key)
		if control != null and control.is_visible_in_tree():
			found.append(control.get_global_rect())
	return found


## Keyboard and gamepad start on the allowed action: the target's own button.
func _focus_target() -> void:
	if _director == null:
		return
	var key: String = _director.highlight()
	if key == "begin":
		_begin.grab_focus()
		return
	var guide: Object = _guide()
	if guide == null or not guide.has_method("tutorial_target"):
		return
	var control: Control = guide.call("tutorial_target", key)
	if control == null:
		return
	var button: Button = control as Button
	if button == null:
		for found: Node in control.find_children("*", "Button", true, false):
			if (found as Button).is_visible_in_tree():
				button = found as Button
				break
	if button != null and button.focus_mode != Control.FOCUS_NONE:
		button.grab_focus()


func _on_begin() -> void:
	_app.arrival.allows("begin")
