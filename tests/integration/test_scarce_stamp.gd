extends GdUnitTestSuite
## A Cadre that seldom reaches a counter is stamped Scarce (P5.2a), so a rare one cannot
## be taken for a routine one: the stamp is on the rare card and no other, it is pressed
## a beat after the cards arrive, and with motion off it is simply there. The tooltip
## says what the word means.

const SEED: int = 4242
const SAVE_PATH: String = "user://test_scarce_stamp/run.json"
const POOL: CadrePool = preload("res://data/run/cadre_pool.tres")
const MARKET_POOL: CadrePool = preload("res://data/run/market_pool.tres")
const PARAMS: ShopParams = preload("res://data/run/default_shop.tres")
const MARKET_PARAMS: ShopParams = preload("res://data/run/black_market.tres")
const RARE: String = "seed_grain"
const COMMON: String = "canteen"

var _app: DemoApp


func before_test() -> void:
	Saves.use_run_path(SAVE_PATH)
	Saves.run_service().delete()
	var scene: PackedScene = load("res://ui/main.tscn")
	_app = auto_free(scene.instantiate())
	add_child(_app)
	_app.new_run(SEED)
	var driver: ControllerScript = ControllerScript.new()
	while _app.controller.awaiting() != RunController.AWAIT_SET_OVER:
		driver.act(_app.controller)
	_app.controller.finish_set()


func after_test() -> void:
	Settings.set_value("reduced_motion", false)
	Saves.run_service().delete()


## Opens the state store with a rare Cadre and a common one on its counter, behind the
## controller, as only tests do.
func _store() -> StoreScreen:
	var loop: RunLoop = _app.controller.run_loop()
	var pool: Array[ModifierDef] = POOL.cadres.duplicate()
	var stock: Array[String] = [RARE, COMMON]
	loop.visit.shop.set("_pool", pool)
	loop.visit.shop.set("_stock", stock)
	var store: StoreScreen = _app.show_screen("store", true)
	await await_idle_frame()
	return store


func _stamps(under: Node) -> Array[ScarceStamp]:
	var found: Array[ScarceStamp] = []
	for node: Node in under.find_children("*", "Control", true, false):
		if node is ScarceStamp:
			found.append(node as ScarceStamp)
	return found


func _buy_button(card: Node) -> Button:
	for button: Button in card.find_children("*", "Button", true, false):
		if button.theme_type_variation == CommonsTheme.COUPON:
			return button
	return null


func test_only_the_top_rarity_is_rare() -> void:
	var shop: RunShop = RunShop.new(RunState.new(1), PARAMS, POOL.cadres)
	shop.open()
	var stock: Array[String] = [RARE, COMMON, RunShop.SOLD]
	shop.set("_stock", stock)
	assert_bool(shop.is_rare(0)).is_true()
	assert_bool(shop.is_rare(1)).is_false()
	assert_bool(shop.is_rare(2)).is_false()
	assert_bool(shop.is_rare(9)).is_false()
	# The rare tier is the last weight on both counters, and no Cadre is rarer.
	assert_int(PARAMS.rarity_weights.size()).is_equal(ModifierDef.RARE + 1)
	assert_int(MARKET_PARAMS.rarity_weights.size()).is_equal(ModifierDef.RARE + 1)
	for definition: ModifierDef in POOL.cadres + MARKET_POOL.cadres:
		assert_int(definition.rarity).is_between(0, ModifierDef.RARE)


func test_a_scarce_cadre_is_stamped_and_a_routine_one_is_not() -> void:
	var store: StoreScreen = await _store()
	var cards: Array[Node] = store.blocks()["counter"].get_children()
	var marked: Array[ScarceStamp] = _stamps(cards[0])
	assert_int(marked.size()).is_equal(1)
	assert_int(_stamps(cards[1]).size()).is_equal(0)
	var stamp: ScarceStamp = marked[0]
	assert_str(stamp.word()).is_equal(tr("store.scarce").to_upper())
	# The cards are still arriving: the stamp has not landed.
	assert_float(stamp.modulate.a).is_equal(0.0)
	var presets: MotionPresets = UiMotion.PRESETS
	await await_millis(int((presets.scarce_wait + presets.stamp_time) * 1000.0) + 250)
	assert_float(stamp.modulate.a).is_equal(1.0)
	assert_vector(stamp.scale).is_equal(Vector2.ONE)
	assert_float(stamp.rotation).is_equal(0.0)
	# At rest it lies on the card, over the picture and clear of the name under it.
	var card: Rect2 = (cards[0] as Control).get_global_rect()
	var picture: Rect2 = (stamp.get_parent() as Control).get_global_rect()
	var shown: Rect2 = stamp.get_global_rect()
	assert_bool(card.encloses(shown)).is_true()
	assert_float(shown.end.y).is_less_equal(picture.end.y)
	# The word is explained where the rules are, and only on the scarce card.
	var note: String = tr("store.scarce.note")
	assert_str(_buy_button(cards[0]).tooltip_text).contains(note)
	assert_str(_buy_button(cards[1]).tooltip_text).not_contains(note)
	# A page refreshed, as after a purchase, shows it at rest: it is pressed once.
	store.call("_refresh")
	await await_idle_frame()
	var after: Array[ScarceStamp] = _stamps(store.blocks()["counter"].get_child(0))
	assert_int(after.size()).is_equal(1)
	assert_float(after[0].modulate.a).is_equal(1.0)


func test_with_motion_off_the_stamp_is_simply_there() -> void:
	Settings.set_value("reduced_motion", true)
	var store: StoreScreen = await _store()
	var marked: Array[ScarceStamp] = _stamps(store.blocks()["counter"].get_child(0))
	assert_int(marked.size()).is_equal(1)
	assert_float(marked[0].modulate.a).is_equal(1.0)
	assert_vector(marked[0].scale).is_equal(Vector2.ONE)
