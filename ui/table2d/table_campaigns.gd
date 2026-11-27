class_name TableCampaigns
extends RefCounted
## The player's Campaigns at the table (ADR 0021): the held leaflets at full size in a row
## under the left seat, with Use and Cancel under them, clear of the brigade notice, the
## trick, the hand, the buttons and the prompt line, and not shown at all while none is
## held; the Play on button at the opening before the first play; and the layer that acts
## each use out. While a leaflet is armed the action bar's reading says what to choose, and
## the hand's selection is the Campaign's.

## Where the tray's top left corner sits at 1920x1080: under the left seat, which ends at
## y 354, left of the trick, which starts at x 470, with its buttons above the notice at
## y 622. Three leaflets end by x 460.
const TRAY_AT: Vector2 = Vector2(78, 358)

## The tray of the held leaflets; hidden while none is held.
var tray: CampaignTray = CampaignTray.new()
## The layer that acts out each use of a Campaign.
var moments: CampaignMoments = CampaignMoments.new()

var _controller: RunController
var _hand: HandModel
var _actions: ActionBar
var _hand_view: HandView
var _table: TableMoments
var _player: EventPlayer
var _armed: int = -1


## Puts the tray and the moments layer on the table.
func place(screen: Control) -> void:
	screen.add_child(tray)
	tray.position = TRAY_AT
	screen.add_child(moments)
	moments.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Wires the tray and the Play on button to the run, the hand, the action bar, the commands, the
## event queue and the table's moments, and shows the tray if a Campaign is held.
func setup(
	controller: RunController,
	hand: HandModel,
	hand_view: HandView,
	actions: ActionBar,
	commands: TableCommands,
	player: EventPlayer,
	table: TableMoments
) -> void:
	_controller = controller
	_hand = hand
	_hand_view = hand_view
	_actions = actions
	_player = player
	_table = table
	tray.show_empty = false
	tray.setup(controller)
	tray.visible = not controller.items.held_campaigns().is_empty()
	tray.selection = hand.selected_ids
	tray.changed.connect(_on_tray_changed.bind(commands))
	commands.campaign_prompt = _prompt
	actions.play_on.pressed.connect(_play_on)
	player.queued.connect(_hold_tray)


## Hands the moments layer the table's card pool, debuff strip and cards, and puts it in
## front.
func attach(pool: CardPool, debuffs: DebuffStrip, cards: TableCards) -> void:
	moments.tray = tray
	moments.setup(_controller, _hand_view, pool, _player, _table, debuffs, cards)
	moments.move_to_front()


## Acts out one event; quiet ones only leave their end state.
func on_event(event: RunEvent, quiet: bool) -> void:
	moments.on_event(event, quiet)


## Once the queue has drained: the tray shows what can be used now, and the opening
## shows Play on.
func refresh() -> void:
	tray.enabled = _player.is_idle()
	tray.refresh()
	tray.visible = not _controller.items.held_campaigns().is_empty()
	_actions.show_opening(_controller.awaiting() == RunController.AWAIT_OPENING)


## The prompt line's text while a Campaign is armed or the opening waits.
func _prompt() -> String:
	var asked: String = tray.prompt()
	if asked.is_empty() and _controller.awaiting() == RunController.AWAIT_OPENING:
		return tr("campaign.opening")
	return asked


func _play_on() -> void:
	tray.disarm()
	_actions.show_opening(false)
	_controller.begin_round()


## Nothing is armed while the table acts events out.
func _hold_tray() -> void:
	tray.enabled = false


## Arming or disarming starts the selection afresh, so neither leaves a choice behind.
func _on_tray_changed(commands: TableCommands) -> void:
	if tray.armed_slot() != _armed:
		_armed = tray.armed_slot()
		_hand.clear()
	commands.refresh()
