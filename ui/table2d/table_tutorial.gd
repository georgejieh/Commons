class_name TableTutorial
extends RefCounted
## The table's part in the arrival (ADR 0026): it reports where the run stands once the
## table's events have played, puts a play step's cards up as chosen with the cursor on
## the first, tells the arrival when the rules card closes, and names what the arrival
## lights and where its slip stands: beside Wang's seat, clear of the hand, the trick,
## the score and the prompt.

## The slip's home: its top, level with the seats, and its gap from Wang's seat.
const HOME_TOP: float = 118.0
const HOME_GAP: float = 16.0

var _app: DemoApp
var _actions: ActionBar
var _hand: HandModel
var _hand_view: HandView
var _need_panel: NeedPanel
var _cheat_sheet: CheatSheet
var _pause: PauseMenu
var _dressing: DreadDressing
## The step whose cards were last put up, so a player's own change is kept.
var _picked_for: int = -1


func setup(
	app: DemoApp,
	actions: ActionBar,
	hand_view: HandView,
	need_panel: NeedPanel,
	cheat_sheet: CheatSheet,
	pause: PauseMenu,
	dressing: DreadDressing = null
) -> void:
	_app = app
	_dressing = dressing
	_actions = actions
	_hand = app.hand
	_hand_view = hand_view
	_need_panel = need_panel
	_cheat_sheet = cheat_sheet
	_pause = pause
	var director: TutorialDirector = app.arrival.director
	if director == null:
		return
	director.changed.connect(_on_changed)
	cheat_sheet.visibility_changed.connect(_on_sheet)


## The table's events have all played: the run waits on awaiting.
func settled(awaiting: int) -> void:
	var director: TutorialDirector = _app.arrival.director
	if director != null:
		director.ready("table", awaiting)


## What the step asks for, each thing lit by itself. A play step's cards are put up as
## chosen, so what is left to press is Play; a card the player has put down again is lit
## in its place.
func tutorial_rects(key: String) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if key != "cards":
		rects.append(tutorial_rect(key))
		return rects
	for card_id: int in _app.arrival.director.cards():
		if not _hand.is_selected(card_id):
			rects.append(_hand_view.card_rect(card_id))
	if rects.is_empty():
		rects.append(_visible_rect(_actions.play))
	return rects


## Where the slip stands at the table whatever the step: beside Wang's seat, over the
## Cadre board's slots, which are empty through the arrival. Nowhere of its own while the
## rules card lies over the table.
func tutorial_home(extent: Vector2) -> Vector2:
	if _cheat_sheet.visible:
		return Vector2.INF
	var seat_left: float = TableScreen.PLAY_CENTER + TableScreen.SEAT_OFFSET
	return Vector2(seat_left - HOME_GAP - extent.x, HOME_TOP)


func tutorial_rect(key: String) -> Rect2:
	match key:
		"cards":
			var rect: Rect2 = Rect2()
			for card_id: int in _app.arrival.director.cards():
				var card: Rect2 = _hand_view.card_rect(card_id)
				rect = card if not rect.has_area() else rect.merge(card)
			return rect
		"rules_close":
			return _visible_rect(_cheat_sheet.close_button())
		"declare":
			return _visible_rect(_need_panel.declare_button())
	var buttons: Dictionary[String, Button] = {
		"pass": _actions.pass_turn,
		"decline": _actions.decline,
		"call": _actions.call,
		"rules": _actions.rules,
	}
	return _visible_rect(buttons.get(key, null))


## The player's hand, which the slip never covers, unless the rules card covers it, and
## the brigade notice on the wall.
func tutorial_avoid() -> Array[Rect2]:
	var avoid: Array[Rect2] = []
	if not _cheat_sheet.visible:
		avoid.append(_hand_view.get_global_rect())
	if _dressing != null and _dressing.notice_rect().has_area():
		avoid.append(_dressing.notice_rect())
	return avoid


## True while the table's menu is open over everything.
func tutorial_hidden() -> bool:
	return _pause.visible


func _visible_rect(control: Control) -> Rect2:
	if control == null or not control.is_visible_in_tree():
		return Rect2()
	return control.get_global_rect()


## A play step's cards go up as chosen, once, with the cursor on the first of them.
func _on_changed() -> void:
	var director: TutorialDirector = _app.arrival.director
	if director == null or director.cards().is_empty() or _picked_for == director.index():
		return
	_picked_for = director.index()
	var ids: Array[int] = []
	ids.assign(Array(director.cards()))
	_hand.select_only(ids)
	_hand_view.point_cursor(ids[0])


func _on_sheet() -> void:
	var director: TutorialDirector = _app.arrival.director
	if director != null and not _cheat_sheet.visible:
		director.note("rules_close")
