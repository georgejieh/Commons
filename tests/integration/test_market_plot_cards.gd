extends GdUnitTestSuite
## The black market's cards for the private plot are drawn as the table draws a card, at
## a card's proportions, over Buy tickets wider than they are, on both screens at every
## text size (the owner's playtest of 2026-11-24: they were squashed to the ticket's
## width).

const SEED: int = 4301
const SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1280, 800)]

static var _save_path: String = TestFolder.of("test_market_plot_cards") + "run.json"

var _app: DemoApp
var _was_size: Vector2i


func before_test() -> void:
	_was_size = get_tree().root.size
	Saves.use_run_path(_save_path)
	Saves.run_service().delete()
	var scene: PackedScene = load("res://ui/main.tscn")
	_app = auto_free(scene.instantiate())
	add_child(_app)
	_app.new_run(SEED)


func after_test() -> void:
	Settings.set_value(TextSize.SETTING, 0)
	get_tree().root.size = _was_size
	Saves.run_service().delete()


func test_the_black_markets_plot_cards_keep_a_cards_proportions() -> void:
	var driver: ControllerScript = ControllerScript.new()
	while _app.controller.awaiting() != RunController.AWAIT_SET_OVER:
		driver.act(_app.controller)
	_app.controller.finish_set()
	for level: int in TextSize.count():
		Settings.set_value(TextSize.SETTING, level)
		for screen_size: Vector2i in SIZES:
			get_tree().root.size = screen_size
			var market: StoreScreen = _app.show_screen("black_market", true)
			await await_idle_frame()
			await await_idle_frame()
			var goods: MarketGoods = market.get("_goods")
			for slot: int in 2:
				var view: CardView = goods.card_view(slot)
				assert_object(view).is_not_null()
				var shown: Vector2 = view.get_global_rect().size
				(
					assert_float(shown.x / shown.y)
					. override_failure_message("level %d %s: %s" % [level, screen_size, shown])
					. is_equal_approx(SwapFit.CARD.x / SwapFit.CARD.y, 0.01)
				)


## A plot card's Buy ticket is explained in the page's slip, as every piece on the counter
## is, with the card's name over the stall's rule, and carries no tooltip of its own.
func test_a_plot_cards_ticket_is_explained_in_the_slip() -> void:
	var driver: ControllerScript = ControllerScript.new()
	while _app.controller.awaiting() != RunController.AWAIT_SET_OVER:
		driver.act(_app.controller)
	_app.controller.finish_set()
	var market: StoreScreen = _app.show_screen("black_market", true)
	await await_idle_frame()
	var goods: MarketGoods = market.get("_goods")
	var buy: Button = goods.card_button(0)
	assert_str(buy.tooltip_text).is_empty()
	buy.focus_entered.emit()
	assert_object(market.slip().anchor()).is_same(buy)
	assert_str(market.slip().shown_rule()).is_equal(tr("market.plot.tip"))
	buy.focus_exited.emit()
	assert_str(market.slip().shown_rule()).is_empty()
