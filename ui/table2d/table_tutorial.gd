class_name TableTutorial
extends RefCounted
## The table's part in the arrival (ADR 0026): it reports where the run stands once the
## table's events have played and the cards on top of the trick have landed, and tells
## the arrival when a new deal begins, so a follow-up waits for the villagers' answer it
## speaks of. It puts a play step's cards up as chosen with the cursor on the first,
## tells the arrival when the rules card closes, and names what the arrival lights and
## where its slip stands: in the player's eye line, centred between the seats with its
## foot just over the trick, clear of the cards in play, the hand, the prompt, the
## ledger and the bar.

## The highest the slip's top may stand, level with the seats' tops under the bar, and
## its gap over the trick, or over the claim sheet while that is up.
const HOME_TOP: float = 118.0
const HOME_GAP: float = 16.0
## The longest a report waits for a play's cards to land, in milliseconds, so a flight
## that never ends cannot hold the arrival.
const LANDING_WAIT_MSEC: int = 3000
## No report waits to be sent.
const NO_REPORT: int = -2

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
var _pile: TrickPile
## What the run waits on, held until the top play has landed, or NO_REPORT; and until when.
var _report: int = NO_REPORT
var _report_by: int = 0
## Where the top play's cards stood on the frame before, to see that they have stopped.
var _pose: Array[Transform2D] = []


func setup(
	app: DemoApp,
	actions: ActionBar,
	hand_view: HandView,
	need_panel: NeedPanel,
	cheat_sheet: CheatSheet,
	pause: PauseMenu,
	dressing: DreadDressing
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


## The trick and the event queue the table plays the run's answers on.
func watch(pile: TrickPile, player: EventPlayer) -> void:
	_pile = pile
	player.played.connect(_on_played)


## The table's events have all played: the run waits on awaiting. It is reported once the
## top play's cards have landed.
func settled(awaiting: int) -> void:
	if _app.arrival.director == null:
		return
	_report = awaiting
	_report_by = Time.get_ticks_msec() + LANDING_WAIT_MSEC
	_pose.clear()
	_report_when_landed()


func _report_when_landed() -> void:
	if _report == NO_REPORT:
		return
	if not _landed() and Time.get_ticks_msec() < _report_by and _pile.is_inside_tree():
		_pile.get_tree().process_frame.connect(_report_when_landed, CONNECT_ONE_SHOT)
		return
	var awaiting: int = _report
	_report = NO_REPORT
	var director: TutorialDirector = _app.arrival.director
	# The table may have given way to another screen, which reports for itself.
	if director != null and _pile.is_visible_in_tree():
		director.ready("table", awaiting)


## True when the trick is empty, or every card of the play on top has landed and stood
## still since the frame before, so a sweep that starts this frame is seen moving.
func _landed() -> bool:
	var views: Array[CardView] = _pile.top_views()
	if views.is_empty():
		return true
	var rest: Vector2 = Vector2.ONE * TrickPile.PLAY_SCALE
	var pose: Array[Transform2D] = []
	var resting: bool = true
	for view: CardView in views:
		pose.append(view.get_transform())
		resting = resting and view.scale.is_equal_approx(rest)
	var still: bool = pose == _pose
	_pose = pose
	return resting and still


## A new deal ends the answer to the last action: what came before it has been shown.
func _on_played(event: RunEvent) -> void:
	var director: TutorialDirector = _app.arrival.director
	if director != null and event.type == RunEvent.Type.DEALT:
		director.answered()


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


## Stands the slip at its home at the table, whatever the step, and returns true; or
## returns false while the rules card lies over the table, where it has none. Its home is
## centred on the play area's middle, between the two seats, with its foot just over the
## trick, or over the claim sheet while that is up, so the eye finds it beside the play.
## Where the claim sheet leaves no room over it, at the larger text sizes, Wang speaks
## from his own seat: the slip stands over it, between the sheet and the action column,
## as narrow as that room.
func tutorial_place(slip: TutorialSlip) -> bool:
	if _cheat_sheet.visible:
		return false
	slip.set_width(TutorialSlip.WIDTH)
	var foot: float = _pile.get_global_rect().position.y
	if _need_panel.visible:
		var sheet: Rect2 = _need_panel.get_global_rect()
		foot = sheet.position.y
		if foot - HOME_GAP - slip.size.y < HOME_TOP:
			var left: float = sheet.end.x + HOME_GAP
			slip.set_width(_actions.get_global_rect().position.x + _actions.size.x - left)
			slip.global_position = Vector2(left, HOME_TOP)
			return true
	var top: float = maxf(HOME_TOP, foot - HOME_GAP - slip.size.y)
	slip.global_position = Vector2(TableScreen.PLAY_CENTER - slip.size.x / 2.0, top)
	return true


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
		"call": _actions.call_landlord,
		"rules": _actions.rules,
	}
	return _visible_rect(buttons.get(key, null))


## The player's hand, which the slip never covers, unless the rules card covers it, and
## the brigade notice on the wall.
func tutorial_avoid() -> Array[Rect2]:
	var avoid: Array[Rect2] = []
	if not _cheat_sheet.visible:
		avoid.append(_hand_view.get_global_rect())
	if _dressing.notice_rect().has_area():
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
