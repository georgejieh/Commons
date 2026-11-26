extends GdUnitTestSuite
## The Tally Clerk (ADR 0043): while the landlord seat is bid for, the player who holds it
## sees the kitty the landlord will take, and is told of it by KITTY_SEEN after every deal
## that is bid for, a redeal's too. Nothing else changes: a whole Set played holding it is
## the same, villager for villager, bid for bid and play for play, as one holding Peek,
## the other information Cadre with no hooks, so no bot sees through it. It is sold at the
## black market for the Resentment every private purchase carries, from the first run.

const CLERK: ModifierDef = preload("res://data/modifiers/the_tally_clerk.tres")
const RESENTMENT: ResentmentParams = preload("res://data/run/resentment.tres")
const SEED: int = 4321
const STEPS: int = 1500
const RICH: int = 99


func _loop(seed_value: int, cadres: Array[String]) -> RunLoop:
	var state: RunState = RunState.new(seed_value)
	state.inventory.cadres.assign(cadres)
	var loop: RunLoop = RunLoop.new(state, RunScript.bots())
	loop.start_set()
	return loop


func _ids(text: String) -> Array[int]:
	var ids: Array[int] = []
	for part: String in text.split(",", false):
		ids.append(part.to_int())
	ids.sort()
	return ids


## Plays the Set, checking the bid's view at every player bid, and returns every villager's
## bid and play, in order, as text.
func _villagers(loop: RunLoop) -> PackedStringArray:
	var script: RunScript = RunScript.new()
	for _step: int in STEPS:
		if loop.awaiting() == RunLoop.Awaiting.PLAYER_BID:
			_check_bid_view(loop)
		if not script.act(loop):
			break
	assert_int(loop.refused_bot_actions).is_zero()
	var seen: PackedStringArray = []
	for event: RunEvent in loop.events():
		if event.seat == RunLoop.PLAYER or event.seat == Seats.NONE:
			continue
		if event.type == RunEvent.Type.BID:
			seen.append("bid %d %d" % [event.seat, event.value])
		elif event.type == RunEvent.Type.ROUND and event.round_event.type == RoundEvent.Type.PLAYED:
			seen.append("play %d %s" % [event.seat, str(event.round_event.card_ids)])
	return seen


func _check_bid_view(loop: RunLoop) -> void:
	var held: bool = loop.state.inventory.cadres.has(CLERK.id)
	var info: InfoView = loop.bid_info()
	if not held:
		assert_object(info).is_null()
		return
	assert_object(info).is_not_null()
	assert_int(info.flags & InfoView.KITTY).is_equal(InfoView.KITTY)
	assert_int(info.kitty.size()).is_equal(Dealer.KITTY_SIZE)
	var last_seen: String = ""
	for event: RunEvent in loop.events():
		if event.type == RunEvent.Type.KITTY_SEEN:
			last_seen = event.text
	var shown: Array[int] = []
	for card: CardInstance in info.kitty:
		shown.append(card.id())
	shown.sort()
	assert_array(_ids(last_seen)).is_equal(shown)


func test_the_kitty_seen_is_the_kitty_the_landlord_takes() -> void:
	var loop: RunLoop = _loop(SEED, [CLERK.id])
	_villagers(loop)
	var seen: String = ""
	var checked: int = 0
	for event: RunEvent in loop.events():
		if event.type == RunEvent.Type.KITTY_SEEN:
			assert_int(event.seat).is_equal(RunLoop.PLAYER)
			seen = event.text
		elif event.type == RunEvent.Type.DEALT:
			seen = ""
		elif event.type == RunEvent.Type.ROUND:
			var taken: RoundEvent = event.round_event
			if taken.type == RoundEvent.Type.KITTY_TAKEN and not seen.is_empty():
				var ids: Array[int] = taken.card_ids.duplicate()
				ids.sort()
				assert_array(_ids(seen)).is_equal(ids)
				checked += 1
	assert_int(checked).is_greater(0)


func test_without_it_no_kitty_is_shown() -> void:
	var loop: RunLoop = _loop(SEED, ["peek"])
	_villagers(loop)
	for event: RunEvent in loop.events():
		assert_int(event.type).is_not_equal(RunEvent.Type.KITTY_SEEN)
	assert_object(loop.bid_info()).is_null()


func test_no_villager_plays_differently_for_it() -> void:
	for offset: int in 3:
		var with_clerk: PackedStringArray = _villagers(_loop(SEED + offset, [CLERK.id]))
		var with_peek: PackedStringArray = _villagers(_loop(SEED + offset, ["peek"]))
		assert_bool(with_clerk.is_empty()).is_false()
		assert_array(Array(with_clerk)).is_equal(Array(with_peek))


func test_it_is_private_and_open_from_the_first_run() -> void:
	assert_int(CLERK.tag).is_equal(ModifierDef.Tag.PRIVATE)
	assert_int(CLERK.kind).is_equal(ModifierDef.Kind.CADRE)
	assert_int(CLERK.unlock_tier).is_equal(0)
	assert_bool(EffectRegistry.create(CLERK, RunLoop.PLAYER) is InfoMarkerEffect).is_true()
	assert_bool(RunPools.MARKET_CADRES.cadres.has(CLERK)).is_true()
	assert_bool(RunPools.STORE_CADRES.cadres.has(CLERK)).is_false()
	assert_bool(ScreenKit.ART.has_cadre(CLERK.id)).is_false()


func test_buying_it_at_the_black_market_is_resented() -> void:
	var loop: RunLoop = _loop(SEED, [])
	RunScript.new().play_until_set_over(loop)
	loop.state.coupons = RICH
	loop.record.mark(loop.state)
	assert_int(loop.open_shop()).is_equal(RunLoop.Reason.OK)
	var stock: Array[String] = [CLERK.id]
	loop.visit.market.set("_stock", stock)
	var resentment: int = loop.state.resentment
	assert_int(loop.player_market_buy(0)).is_equal(RunLoop.Reason.OK)
	assert_bool(loop.state.inventory.cadres.has(CLERK.id)).is_true()
	assert_int(loop.state.resentment).is_equal(resentment + RESENTMENT.private_purchase)
