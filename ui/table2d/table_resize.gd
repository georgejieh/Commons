class_name TableResize
extends RefCounted
## Takes a new text size to the table's own pieces at the next deal (ADR 0034). The
## theme's text changes at once; building the table again mid-round would lose a need
## being set, an open reading picker and plays not yet acted out, so the table is built
## again only once a deal has been shown and no card of it played: the event queue has
## drained, the run waits on the player's bid or lead, and the menu is shut. It is built
## as on a resume, replaying the Set silently, with the hand's sort kept. The selection
## lives in the app's HandModel and the searches in the controller, so neither is touched.

var _table: TableScreen
var _app: DemoApp
var _menu: PauseMenu
## The text size the table's pieces were set at, and the plays shown since the deal.
var _built: int = 0
var _plays: int = 0


func setup(table: TableScreen, app: DemoApp, menu: PauseMenu) -> void:
	_table = table
	_app = app
	_menu = menu
	_built = TextSize.level()


## Counts the deal's plays; a fresh deal starts the count again.
func on_event(event: RunEvent) -> void:
	match event.type:
		RunEvent.Type.SET_STARTED, RunEvent.Type.DEALT:
			_plays = 0
		RunEvent.Type.ROUND:
			if event.round_event.type == RoundEvent.Type.PLAYED:
				_plays += 1


## True when the table's pieces are at an older size than the one chosen now.
func is_due() -> bool:
	return _built != TextSize.level()


## The queue has drained: builds the table again when a new size is due and this is the
## safe point. Deferred, so the old table finishes its own call first.
func drained(awaiting: int) -> void:
	var start: bool = awaiting == RunController.AWAIT_BID or awaiting == RunController.AWAIT_PLAY
	if is_due() and start and _plays == 0 and not _menu.visible and not _app.arrival.is_running():
		_rebuild.call_deferred()


func _rebuild() -> void:
	if not _table.is_inside_tree() or _app.switcher.current() != _table or not is_due():
		return
	var sort: HandView.Sort = _table.hand_view.sort_mode
	var built: TableScreen = _app.switcher.reload()
	built.open(_app)
	built.keep_sort(sort)
