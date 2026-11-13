class_name TableCommands
extends RefCounted
## What the player sends from the table: plays, passes, bids, declared need, hints and
## the sort toggle. It wires the action bar and need panel to the run controller, and
## keeps the bar's reading and buttons in step with the hand and the turn.

var _controller: RunController
var _hand: HandModel
var _hand_view: HandView
var _actions: ActionBar
var _need_panel: NeedPanel
var _player: EventPlayer
var _names: Dictionary[int, String] = {}


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
	_actions.play.disabled = not (my_turn and _hand.can_play())
	_actions.pass_turn.disabled = not (my_turn and _hand.can_pass())
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
					"grain": Strings.score(preview.grain),
					"rate": Strings.factor(preview.rate),
					"zeal": Strings.factor(preview.zeal),
					"total": Strings.score(preview.score),
				}
			)
		)
	_actions.reading.text = text
	_actions.reading.tooltip_text = Keywords.tip(text)


## Calling is free and opens the seat; a grab takes it from whoever called.
func _show_bid() -> void:
	var holder: int = _controller.bid_holder()
	var grabbing: bool = holder != Seats.NONE
	_actions.call.text = tr("action.grab" if grabbing else "action.call")
	if grabbing:
		var who: String = _names.get(holder, "")
		var cost: int = _controller.grab_cost()
		_actions.reading.text = tr("table.grab_prompt").format({"name": who, "cost": cost})
	else:
		_actions.reading.text = tr("table.bid_prompt")
	_actions.reading.tooltip_text = tr("table.bid_tip")


## Every command fills the event queue, so the buttons go off until it drains.
func _on_play() -> void:
	if _controller.play(_hand.selected_ids()) == RunController.OK:
		_hand.clear()
	refresh()


func _on_pass() -> void:
	_controller.pass_turn()
	_hand.clear()
	refresh()


func _on_bid(claim: bool) -> void:
	_actions.show_bidding(false)
	_controller.bid(claim)
	refresh()


func _on_need(need: int) -> void:
	_need_panel.visible = false
	_controller.declare_need(need)
	refresh()


## Cycles rank, suit and groups, and names the current sort on the button.
func _toggle_sort() -> void:
	var next: int = (_hand_view.sort_mode + 1) % HandView.Sort.size()
	_hand_view.set_sort(next as HandView.Sort)
	_show_sort()


func _show_sort() -> void:
	var mode: String = tr(HandView.SORT_KEYS[_hand_view.sort_mode])
	_actions.sort.text = tr("action.sort_by").format({"mode": mode})
	_actions.sort.tooltip_text = tr("action.sort_tip").format({"mode": mode})


## Selects the play a Medium villager would make, and lights it.
func _on_hint() -> void:
	if _controller.awaiting() != RunController.AWAIT_PLAY:
		return
	var ids: Array[int] = _hand.suggested_ids()
	_hand.select_only(ids)
	_hand_view.show_hint(ids)
	if ids.is_empty():
		_actions.reading.text = tr("hand.hint.pass")
