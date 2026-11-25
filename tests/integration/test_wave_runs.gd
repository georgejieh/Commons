extends GdUnitTestSuite
## ADR 0032's Cadres across a Quota of the real run loop: each one's effect as the loop
## logs it, against the events that say when it should have acted.

const SEEDS: int = 40
const HONEST: int = 10


func _loop(seed_value: int, cadres: Array, sets: SetConfig = SetConfig.new()) -> RunLoop:
	var state: RunState = RunState.new(seed_value)
	state.inventory.cadres.assign(cadres)
	var loop: RunLoop = RunLoop.new(state, RunScript.bots(), sets)
	return loop


## Villagers who always claim more than their need, so audits catch them.
func _liars(seed_value: int, cadres: Array) -> RunLoop:
	var bots: Array[BotConfig] = RunScript.bots()
	for config: BotConfig in bots:
		config.honesty = 0.0
	var state: RunState = RunState.new(seed_value)
	state.inventory.cadres.assign(cadres)
	return RunLoop.new(state, bots, SetConfig.new())


## Plays the Quota out, declaring need when asked.
func _play_set(loop: RunLoop, need: int = RunScript.NEED) -> void:
	var script: RunScript = RunScript.new()
	for _step: int in 2000:
		if loop.awaiting() == RunLoop.Awaiting.PLAYER_NEED:
			assert_int(loop.player_need(need)).is_equal(RunLoop.Reason.OK)
		elif not script.act(loop):
			break
	assert_int(loop.awaiting()).is_equal(RunLoop.Awaiting.SET_OVER)


func _of(loop: RunLoop, type: RunEvent.Type, text: String = "") -> Array[RunEvent]:
	return loop.events().filter(
		func(event: RunEvent) -> bool:
			return event.type == type and (text.is_empty() or event.text == text)
	)


## Rounds the peasants won with the player among them: the round's landlord lost the seat.
func _won_as_peasant(loop: RunLoop) -> int:
	var lost: Array[RunEvent] = _of(loop, RunEvent.Type.SEAT_LOST)
	return lost.filter(func(event: RunEvent) -> bool: return event.seat != 0).size()


func test_public_granary_lowers_famine_once_for_each_round_won_as_a_peasant() -> void:
	var checked: int = 0
	for seed_value: int in range(8100, 8100 + SEEDS):
		var loop: RunLoop = _loop(seed_value, ["public_granary"])
		loop.state.famine = 30
		loop.start_set()
		_play_set(loop)
		var won: int = _won_as_peasant(loop)
		var fired: Array[RunEvent] = _of(loop, RunEvent.Type.CADRE_FIRED, "public_granary")
		assert_int(fired.size()).is_equal(won)
		var falls: Array[RunEvent] = _of(loop, RunEvent.Type.METER_CHANGED, RunMeters.FAMINE)
		falls = falls.filter(func(event: RunEvent) -> bool: return event.value < 0)
		assert_int(falls.size()).is_equal(won)
		for event: RunEvent in falls:
			assert_int(event.value).is_equal(-1)
		checked += won
		if checked >= 3:
			break
	assert_int(checked).is_greater_equal(3)


## Each fall is logged before that round is scored, so the Quota's summary, which reads
## Famine's changes after the last round's scores, never counts it as the Quota's own.
func test_public_granarys_fall_comes_before_the_rounds_scores() -> void:
	for seed_value: int in range(8200, 8200 + SEEDS):
		var loop: RunLoop = _loop(seed_value, ["public_granary"])
		loop.state.famine = 0
		loop.start_set()
		_play_set(loop)
		if _won_as_peasant(loop) == 0:
			continue
		var events: Array[RunEvent] = loop.events()
		for index: int in events.size():
			var event: RunEvent = events[index]
			if event.type == RunEvent.Type.METER_CHANGED and event.value <= 0:
				# Stopped at 0: logged with no change, before this round's scores.
				assert_int(event.value).is_equal(0)
				assert_bool(_scored_next(events, index)).is_true()
		assert_int(loop.state.famine).is_greater_equal(0)
		return
	assert_bool(false).override_failure_message("no seed won a round").is_true()


## True when the round's scores come after index before the round's need or seat does.
func _scored_next(events: Array[RunEvent], index: int) -> bool:
	var later: Array[RunEvent.Type] = [
		RunEvent.Type.NEED_DECLARED, RunEvent.Type.SEAT_KEPT, RunEvent.Type.SEAT_LOST
	]
	for after: int in range(index + 1, events.size()):
		if events[after].type == RunEvent.Type.ROUND_SCORED:
			return true
		if later.has(events[after].type):
			return false
	return false


func test_open_accounts_lowers_resentment_each_round_the_player_claims_honestly() -> void:
	var loop: RunLoop = _loop(8300, ["open_accounts"])
	loop.state.resentment = 30
	loop.start_set()
	_play_set(loop, HONEST)
	var declared: Array[RunEvent] = _of(loop, RunEvent.Type.NEED_DECLARED).filter(
		func(event: RunEvent) -> bool: return event.seat == 0
	)
	var falls: Array[RunEvent] = _of(loop, RunEvent.Type.RESENTMENT, Resentment.CADRE)
	assert_int(declared.size()).is_greater(0)
	assert_int(falls.size()).is_equal(declared.size())
	for event: RunEvent in falls:
		assert_int(event.value).is_equal(-1)
	# A claim above the need lowers nothing.
	var lying: RunLoop = _loop(8300, ["open_accounts"])
	lying.state.resentment = 30
	lying.start_set()
	_play_set(lying, HONEST + 2)
	assert_array(_of(lying, RunEvent.Type.RESENTMENT, Resentment.CADRE)).is_empty()


func test_informers_reward_pays_two_coupons_for_each_villager_caught() -> void:
	for seed_value: int in range(8400, 8400 + SEEDS):
		var loop: RunLoop = _liars(seed_value, ["informers_reward"])
		loop.start_set()
		_play_set(loop)
		var caught: Array[RunEvent] = _of(loop, RunEvent.Type.AUDITED).filter(
			func(event: RunEvent) -> bool: return event.seat != 0 and event.value == 1
		)
		var paid: int = 0
		for event: RunEvent in _of(loop, RunEvent.Type.CADRE_FIRED, "informers_reward"):
			paid += event.value
		assert_int(paid).is_equal(caught.size() * 2)
		if not caught.is_empty():
			return
	assert_bool(false).override_failure_message("no villager was caught").is_true()


## Every deck card carries the player's stamp: without Forged Seal each one scored adds
## Resentment; with it, none does.
func test_forged_seal_keeps_stamped_cards_from_adding_resentment() -> void:
	var stamped: Array[int] = []
	for held: Array in [[], ["forged_seal"]]:
		var loop: RunLoop = _loop(8500, held)
		for deck_id: int in Deck.SIZE:
			CardMarks.stamp(loop.state, Deck.new().card(deck_id), 0)
		loop.start_set()
		_play_set(loop)
		stamped.append(_of(loop, RunEvent.Type.RESENTMENT, Resentment.STAMPED_CARD).size())
	assert_int(stamped[0]).is_greater(0)
	assert_int(stamped[1]).is_equal(0)


## A target of 1 is beaten by the most steps: with Grain Speculator each pays one more
## coupon and adds one more Resentment, and the norm rises as it always does.
func test_grain_speculator_adds_to_what_each_step_pays_and_costs() -> void:
	var params: SetParams = SetConfig.DEFAULT_PARAMS.duplicate()
	params.targets = params.targets.duplicate()
	params.targets.fill(1.0)
	var results: Array[RunState] = []
	for held: Array in [[], ["grain_speculator"]]:
		var loop: RunLoop = _loop(8600, held, SetConfig.new(params))
		loop.start_set()
		_play_set(loop)
		results.append(loop.state)
	var steps: int = results[0].over_steps
	assert_int(steps).is_equal(params.over_max_steps)
	assert_int(results[1].over_steps).is_equal(steps)
	assert_int(results[1].norm_steps).is_equal(results[0].norm_steps)
	assert_int(results[1].coupons).is_equal(results[0].coupons + steps)
	# A private Cadre held at the Quota's end is resented as every one is.
	var held: int = RunDefaults.RESENTMENT.private_cadre
	assert_int(results[1].resentment).is_equal(results[0].resentment + steps + held)


func test_rent_book_counts_each_round_won_as_landlord_and_resents_it() -> void:
	for seed_value: int in range(8700, 8700 + SEEDS):
		var loop: RunLoop = _loop(seed_value, ["rent_book"])
		loop.start_set()
		_play_set(loop)
		var kept: Array[RunEvent] = _of(loop, RunEvent.Type.SEAT_KEPT).filter(
			func(event: RunEvent) -> bool: return event.seat == 0
		)
		var memo: CadreMemo = loop.state.cadre_memos.peek("rent_book")
		assert_int(memo.value(RentBookEffect.WINS)).is_equal(kept.size())
		var resented: int = 0
		for event: RunEvent in _of(loop, RunEvent.Type.RESENTMENT, Resentment.CADRE):
			resented += event.value
		assert_int(resented).is_equal(kept.size() * 2)
		if not kept.is_empty():
			return
	assert_bool(false).override_failure_message("the player never won as landlord").is_true()


## Year 3: a play in the Quota's clean first round has 1 + 3 × 0.1 Zeal.
func test_five_year_plan_reads_the_year_in_play() -> void:
	var loop: RunLoop = _loop(8800, ["five_year_plan"])
	loop.state.year = 3
	loop.start_set()
	_play_set(loop)
	var first: RunEvent = _of(loop, RunEvent.Type.PLAY_SCORED)[0]
	assert_float(first.zeal).is_equal_approx(1.3, 0.0001)


func test_the_gleaners_fire_for_each_round_the_peasants_win_with_cards_left() -> void:
	for seed_value: int in range(8900, 8900 + SEEDS):
		var loop: RunLoop = _loop(seed_value, ["the_gleaners"])
		loop.start_set()
		_play_set(loop)
		var fired: Array[RunEvent] = _of(loop, RunEvent.Type.CADRE_FIRED, "the_gleaners")
		var lost: Array[RunEvent] = _of(loop, RunEvent.Type.SEAT_LOST)
		assert_int(fired.size()).is_equal(lost.size())
		for event: RunEvent in fired:
			assert_int(event.value % 5).is_equal(0)
			assert_int(event.value).is_greater(0)
		if not fired.is_empty():
			return
	assert_bool(false).override_failure_message("the peasants never won").is_true()


## Bought at the black market, the first reroll that visit is free at once; the record
## replays the visit to the same coupons.
func test_back_door_frees_the_first_black_market_reroll_and_replays() -> void:
	var loop: RunLoop = _loop(9000, [])
	loop.start_set()
	_play_set(loop)
	loop.state.reeducation_due = false
	loop.state.coupons = 200
	assert_int(loop.open_shop()).is_equal(RunLoop.Reason.OK)
	assert_int(loop.visit.market.reroll_price()).is_greater(0)
	var rerolled: int = 0
	for _reroll: int in 60:
		if loop.visit.market.stock().has("back_door"):
			break
		assert_int(loop.player_market_reroll()).is_equal(RunLoop.Reason.OK)
		rerolled += 1
	var slot: int = loop.visit.market.stock().find("back_door")
	assert_int(slot).is_greater_equal(0)
	assert_int(loop.player_market_buy(slot)).is_equal(RunLoop.Reason.OK)
	# Bought now, it works at once, unless this visit's first reroll is already spent.
	assert_bool(loop.visit.market.reroll_price() == 0).is_equal(rerolled == 0)
	assert_int(RunScript.next_set(loop)).is_equal(RunLoop.Reason.OK)
	_play_set(loop)
	loop.state.reeducation_due = false
	assert_int(loop.open_shop()).is_equal(RunLoop.Reason.OK)
	var coupons: int = loop.state.coupons
	assert_int(loop.visit.market.reroll_price()).is_equal(0)
	assert_int(loop.player_market_reroll()).is_equal(RunLoop.Reason.OK)
	assert_int(loop.state.coupons).is_equal(coupons)
	assert_int(loop.visit.market.reroll_price()).is_greater(0)
	var saved: Dictionary = loop.record.to_dict()
	saved["checkpoint"]["reeducation_due"] = false
	var resumed: RunLoop = RunRecord.resume(saved, RunScript.bots(), SetConfig.new())
	assert_object(resumed).is_not_null()
	assert_int(resumed.state.coupons).is_equal(coupons)
	assert_int(resumed.visit.market.reroll_price()).is_equal(loop.visit.market.reroll_price())
