extends GdUnitTestSuite
## The deck sheet's group names stand clear of every card (ADR 0041): read-only and
## choosing for an exchange, with the card coming in beside the heading, at both screens
## and every text size, no card covers a rank's name, a joker's or the plot's.

const SEED: int = 4242

static var _save_path: String = TestFolder.of("test_deck_board_names") + "run.json"

var _app: App
var _was_size: Vector2i


func before_test() -> void:
	_was_size = get_tree().root.size
	Settings.set_value("reduced_motion", true)
	Saves.use_run_path(_save_path)
	Saves.run_service().delete()
	_app = AppKit.make(self)
	_app.new_run(SEED)
	var driver: ControllerScript = ControllerScript.new()
	driver.play_to(self, _app.controller, RunController.AWAIT_SET_OVER)
	_app.controller.finish_set()


func after_test() -> void:
	Settings.set_value(TextSize.SETTING, 0)
	Settings.set_value("reduced_motion", false)
	get_tree().root.size = _was_size
	Saves.run_service().delete()


func test_no_card_covers_a_group_name() -> void:
	for level: int in TextSize.count():
		Settings.set_value(TextSize.SETTING, level)
		for screen_size: Vector2i in ClipCheck.SIZES:
			get_tree().root.size = screen_size
			for choosing: bool in [false, true]:
				var store: StoreScreen = _app.show_screen(App.STORE, true)
				await await_idle_frame()
				var sheet: DeckSheet = store.deck
				if choosing:
					var card: CardInstance = _app.controller.store.deck_stall().card(0)
					var refuse: Callable = func(_out: int) -> String: return ""
					var act: Callable = func(_out: int) -> int: return RunController.OK
					sheet.open_choice(ExchangeChoice.new(card, "", refuse, act))
				else:
					sheet.open_deck()
				await await_idle_frame()
				await await_idle_frame()
				var where: String = "text %d %s choosing %s" % [level, screen_size, choosing]
				_check(sheet.board(), where)
				sheet.close()


func _check(board: DeckBoard, where: String) -> void:
	var names: Array[Control] = []
	for node: Node in board.get_children():
		if node is Label and node.is_in_group(SlipPlacer.KEEP_CLEAR):
			names.append(node as Control)
	assert_int(names.size()).is_greater(0)
	for card_id: int in board.card_ids():
		var card: Rect2 = EnvelopeOverlay.shown_rect(board.view_of(card_id)).grow(-ClipCheck.SLACK)
		for shown: Control in names:
			var label: Label = shown as Label
			(
				assert_bool(card.intersects(shown.get_global_rect()))
				. override_failure_message(
					(
						"%s: %s %s covers %s %s"
						% [
							where,
							CardName.of(board.card_of(card_id)),
							card,
							label.text,
							shown.get_global_rect()
						]
					)
				)
				. is_false()
			)
