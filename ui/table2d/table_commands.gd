class_name TableCommands
extends RefCounted
## What the player sends from the table: plays, passes, bids, declared need, hints and
## the sort toggle. It wires the action bar and need panel to the run controller, and
## keeps the bar's reading and buttons in step with the hand and the turn. Every press
## asks the gate first; during the arrival only the step's own action passes, and a
## refused press does nothing (ADR 0026).

## What the prompt line says in place of the hand's reading, such as an armed Campaign's
## ask, or "" to leave the reading.
var prompt: Callable = Callable()
## Asked with an action's name and detail before it is sent; false refuses it. Unset, all
## pass.
var gate: Callable = Callable()
## Opens the rules card.
var open_rules: Callable = Callable()
## Asks which reading to play when the chosen cards can be played more than one way now
## (ADR 0029); with none set, the strongest is played.
var picker: ReadingPicker = null:
	set = _set_picker

var _controller: RunController
var _hand: HandModel
var _hand_view: HandView
var _actions: ActionBar
var _need_panel: NeedPanel
var _player: EventPlayer
var _names: Dictionary[int, String] = {}
## The cards the open picker plays.
var _picking: Array[int] = []


func setup(
	controller: RunController,
	hand: HandModel,
	hand_view: HandView,
	actions: ActionBar,
	need_panel: NeedPanel,
	player: EventPlayer
) -> void:
	_controller = controller
	_hand = hand
	_hand_view = hand_view
	_actions = actions
	_need_panel = need_panel
	_player = player
	hand.changed.connect(refresh)
	player.queued.connect(refresh)
	actions.play.pressed.connect(_on_play)
	actions.pass_turn.pressed.connect(_on_pass)
	actions.hint.pressed.connect(_on_hint)
	actions.sort.pressed.connect(_toggle_sort)
	actions.rules.pressed.connect(_on_rules)
	actions.call.pressed.connect(_on_bid.bind(true))
	actions.decline.pressed.connect(_on_bid.bind(false))
	need_panel.declared.connect(_on_need)
	_show_sort()


## The seats' names, for saying who holds the seat during a grab.
func set_names(names: Dictionary[int, String]) -> void:
	_names = names


## Sets the buttons and the reading for the turn, the bid or the selection.
func refresh() -> void:
	var my_turn: bool = _player.is_idle() and _controller.awaiting() == RunController.AWAIT_PLAY
	var was_off: bool = _actions.play.disabled
	_actions.play.disabled = not (my_turn and _hand.can_play())
	# The Play ticket swells the moment a selection becomes playable.
	if was_off and not _actions.play.disabled:
		UiMotion.pulse(_actions.play)
	_actions.pass_turn.disabled = not (my_turn and _hand.can_pass())
	var asked: String = prompt.call() if prompt.is_valid() else ""
	if not asked.is_empty():
		# The selection is the Campaign's while one is armed, so it is not played.
		_actions.play.disabled = true
		_actions.pass_turn.disabled = true
		_actions.reading.text = asked
		_actions.reading.tooltip_text = Keywords.tip(asked)
		return
	if _controller.awaiting() == RunController.AWAIT_BID:
		_show_bid()
		return
	var text: String = tr(_hand.label_key())
	var preview: PlayPreview = _hand.preview()
	if preview != null and preview.score > 0.0:
		text = (
			tr("hand.sum")
			. format(
				{
					"type": text,
					# The hand type on a line of its own, then its sum, whose result never
					# drops alone onto a further line (the string joins it to Zeal).
					"break": "\n",
					"grain": Strings.score(preview.grain),
					"rate": Strings.factor(preview.rate),
					"zeal": Strings.factor(preview.zeal),
					"total": Strings.score(preview.score),
				}
			)
		)
		# A debuff that cuts the total is shown as a last factor, so the sum adds up.
		var percent: int = ScoreTally.scale_percent(
			preview.grain, preview.rate, preview.zeal, preview.score
		)
		if percent != ScoreTally.WHOLE:
			text += " " + tr("hand.scaled").format({"percent": percent})
	_actions.reading.text = text
	_actions.reading.tooltip_text = Keywords.tip(text)


## Calling is free and opens the seat; a grab takes it from whoever called.
func _show_bid() -> void:
	var holder: int = _controller.table.bid_holder()
	var grabbing: bool = holder != Seats.NONE
	_actions.call.text = tr("action.grab" if grabbing else "action.call")
	if grabbing:
		var who: String = _names.get(holder, "")
		var cost: int = _controller.figures.grab_cost()
		_actions.reading.text = tr("table.grab_prompt").format({"name": who, "cost": cost})
	else:
		_actions.reading.text = tr("table.bid_prompt")
	_actions.reading.tooltip_text = tr("table.bid_tip")


## Every command fills the event queue, so the buttons go off until it drains. Cards
## that can be played more than one way now open the reading picker, unless they are the
## hint's, which plays the reading the hint meant (ADR 0029).
func _on_play() -> void:
	var ids: Array[int] = _hand.selected_ids()
	if not _allowed("play", ids):
		return
	var reading: Pattern = _hand.hint_reading()
	if reading == null and picker != null:
		var readings: Array[Pattern] = _controller.table.readings_for(ids)
		if readings.size() > 1:
			_picking = ids
			picker.open(readings, _hand_view.selection_rect())
			return
	_send_play(ids, reading)


func _send_play(ids: Array[int], reading: Pattern) -> void:
	if _controller.play(ids, reading) == RunController.OK:
		_hand.clear()
	refresh()


## The picker's choice plays the cards it was opened on, as that reading.
func _on_picked(reading: Pattern) -> void:
	var ids: Array[int] = _picking
	_picking = []
	_send_play(ids, reading)


func _set_picker(value: ReadingPicker) -> void:
	picker = value
	if picker != null:
		picker.chosen.connect(_on_picked)
		picker.closed.connect(func() -> void: _picking = [])


## Night Shift refuses the pass (ADR 0023): the Pass ticket is knocked back like a
## stamp and the reading says why, and the turn stays the player's.
func _on_pass() -> void:
	if not _allowed("pass"):
		return
	var refusal: String = _controller.table.pass_refusal()
	if not refusal.is_empty():
		_actions.reading.text = tr(refusal)
		_actions.reading.tooltip_text = tr(refusal)
		UiMotion.stamp(_actions.pass_turn)
		return
	_controller.pass_turn()
	_hand.clear()
	refresh()


func _on_bid(claim: bool) -> void:
	if not _allowed("bid_call" if claim else "bid_pass"):
		return
	_actions.show_bidding(false)
	_controller.bid(claim)
	refresh()


func _on_need(need: int) -> void:
	if not _allowed("need", need):
		return
	_need_panel.visible = false
	_controller.declare_need(need)
	refresh()


## Cycles rank, suit and groups, and names the current sort on the button.
func _toggle_sort() -> void:
	if not _allowed("sort"):
		return
	var next: int = (_hand_view.sort_mode + 1) % HandView.Sort.size()
	_hand_view.set_sort(next as HandView.Sort)
	_show_sort()


## Sets the hand's sort, as when the table is built again at a new text size.
func set_sort(mode: HandView.Sort) -> void:
	_hand_view.set_sort(mode)
	_show_sort()


func _show_sort() -> void:
	var mode: String = tr(HandView.SORT_KEYS[_hand_view.sort_mode])
	_actions.sort.text = tr("action.sort_by").format({"mode": mode})
	_actions.sort.tooltip_text = tr("action.sort_tip").format({"mode": mode})


## Selects the play a Medium villager would make, as its reading, and lights it.
func _on_hint() -> void:
	if _controller.awaiting() != RunController.AWAIT_PLAY or not HintSetting.shown():
		return
	if not _allowed("hint"):
		return
	var ids: Array[int] = _hand.take_hint()
	_hand_view.show_hint(ids)
	if ids.is_empty():
		_actions.reading.text = tr("hand.hint.pass")


func _on_rules() -> void:
	if _allowed("rules") and open_rules.is_valid():
		open_rules.call()


func _allowed(action: String, detail: Variant = null) -> bool:
	return not gate.is_valid() or bool(gate.call(action, detail))
