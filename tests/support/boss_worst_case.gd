class_name BossWorstCase
extends RefCounted
## The boss the table's worst case puts on the rules slip (ADR 0043): the one whose line
## stands tallest on a strip of the table's width, the Handicap's with its most cards set
## aside, each with one of the longest card names; or, with named, the boss with the
## longest name.

const HANDICAP: String = "the_handicap"
## The most cards the Handicap sets aside, in its last Year before the New Landlord's.
const MOST_ASIDE: int = 3


static func worst(app: App, suite: GdUnitTestSuite, named: bool) -> String:
	var loop: RunLoop = app.controller.run_loop()
	var state: RunState = loop.state
	var ids: Array[String] = []
	for boss: ModifierDef in RunPools.BOSSES.all():
		ids.append(boss.id)
	var chosen: String = ""
	if named:
		var length: Callable = func(id: String) -> int:
			return app.controller.texts.modifier_name(id).length()
		ids.sort_custom(func(a: String, b: String) -> bool: return length.call(a) > length.call(b))
		chosen = ids[0]
	else:
		chosen = await _tallest(app, suite, ids)
	_set_aside(app, chosen == HANDICAP)
	state.boss_id = chosen
	return chosen


static func _tallest(app: App, suite: GdUnitTestSuite, ids: Array[String]) -> String:
	var state: RunState = _loop(app).state
	var strip: DebuffStrip = DebuffStrip.new()
	app.add_child(strip)
	strip.size = Vector2(TableWorstCase.STRIP_WIDTH, 0.0)
	state.debuff_ladder.assign(["", "", "", ""])
	var tallest: String = ""
	var height: float = -1.0
	for id: String in ids:
		state.boss_id = id
		_set_aside(app, id == HANDICAP)
		strip.show_debuffs(app.controller)
		await suite.await_idle_frame()
		if strip.get_combined_minimum_size().y > height:
			height = strip.get_combined_minimum_size().y
			tallest = id
	strip.queue_free()
	return tallest


## Sets the round's deal's cards aside: the most the Handicap does, of the longest names,
## or none.
static func _set_aside(app: App, handicap: bool) -> void:
	var deal: DealResult = _loop(app).deal()
	deal.set_aside.clear()
	if not handicap:
		return
	var deck: Deck = Deck.new()
	var slots: Array[int] = []
	for slot: int in Deck.SIZE:
		slots.append(slot)
	var named: Callable = func(slot: int) -> int: return CardName.of(deck.card(slot)).length()
	slots.sort_custom(func(a: int, b: int) -> bool: return named.call(a) > named.call(b))
	for index: int in MOST_ASIDE:
		deal.set_aside.append(deck.card(slots[index]))


static func _loop(app: App) -> RunLoop:
	return app.controller.run_loop()
