extends GdUnitTestSuite
## ADR 0021's Cadres across a run: the rank picked when buying, each Cadre's own state
## saved, loaded and replayed, cleared when the Cadre is lost, and counted by the turn
## hook from real plays and passes only.

## Enough for every reroll _offer() may need.
const RICH: int = 20000
const REROLLS: int = 100


func _at_the_shops(seed_value: int) -> RunLoop:
	var loop: RunLoop = RunLoop.new(RunState.new(seed_value), RunScript.bots(), SetConfig.new())
	loop.start_set()
	RunScript.new().play_until_set_over(loop)
	loop.state.coupons = RICH
	assert_int(loop.open_shop()).is_equal(RunLoop.Reason.OK)
	return loop


## Rerolls the black market until it offers the Cadre, and returns its slot.
func _offer(loop: RunLoop, cadre_id: String) -> int:
	for _reroll: int in REROLLS:
		var slot: int = loop.visit.market.stock().find(cadre_id)
		if slot >= 0:
			return slot
		assert_int(loop.player_market_reroll()).is_equal(RunLoop.Reason.OK)
	return loop.visit.market.stock().find(cadre_id)


## The record from a shop visit, its checkpoint given the coupons the test handed out.
func _rich_record(loop: RunLoop) -> Dictionary:
	var record: Dictionary = loop.record.to_dict()
	var checkpoint: Dictionary = record["checkpoint"]
	checkpoint["coupons"] = RICH
	return record


func test_a_rank_cadre_is_refused_without_a_rank_and_saves_the_one_picked() -> void:
	var loop: RunLoop = _at_the_shops(5101)
	var slot: int = _offer(loop, "rehabilitation")
	assert_int(slot).is_greater_equal(0)
	var commands: int = loop.record.commands.size()
	var coupons: int = loop.state.coupons
	assert_int(loop.player_market_buy(slot)).is_equal(RunLoop.Reason.ILLEGAL)
	assert_int(loop.player_market_buy(slot, Ranks.SMALL_JOKER)).is_equal(RunLoop.Reason.ILLEGAL)
	assert_int(loop.record.commands.size()).is_equal(commands)
	assert_int(loop.state.coupons).is_equal(coupons)
	assert_int(loop.player_market_buy(slot, Ranks.SEVEN)).is_equal(RunLoop.Reason.OK)
	assert_int(loop.record.commands[-1]["rank"]).is_equal(Ranks.SEVEN)
	var memo: CadreMemo = loop.state.cadre_memos.peek("rehabilitation")
	assert_int(memo.value(CadreMemo.RANK, -1)).is_equal(Ranks.SEVEN)
	# Replayed from the record, the same rank is saved.
	var resumed: RunLoop = RunRecord.resume(_rich_record(loop), RunScript.bots(), SetConfig.new())
	assert_object(resumed).is_not_null()
	var replayed: CadreMemo = resumed.state.cadre_memos.peek("rehabilitation")
	assert_int(replayed.value(CadreMemo.RANK, -1)).is_equal(Ranks.SEVEN)
	assert_array(resumed.state.inventory.cadres).is_equal(loop.state.inventory.cadres)


func test_a_market_buy_saved_before_the_picker_still_replays() -> void:
	var loop: RunLoop = _at_the_shops(5102)
	var slot: int = -1
	for _reroll: int in REROLLS:
		var stock: Array[String] = loop.visit.market.stock()
		for index: int in stock.size():
			if stock[index] != RunShop.SOLD and not _needs_rank(stock[index]):
				slot = index
				break
		if slot >= 0:
			break
		loop.player_market_reroll()
	assert_int(loop.player_market_buy(slot)).is_equal(RunLoop.Reason.OK)
	assert_bool(loop.record.commands[-1].has("rank")).is_false()
	var record: Dictionary = _rich_record(loop)
	assert_bool(RunRecordCheck.is_valid(record)).is_true()
	var resumed: RunLoop = RunRecord.resume(record, RunScript.bots(), SetConfig.new())
	assert_array(resumed.state.inventory.cadres).is_equal(loop.state.inventory.cadres)


func _needs_rank(cadre_id: String) -> bool:
	for cadre: ModifierDef in RunLoop.all_cadres():
		if cadre.id == cadre_id:
			return cadre.needs_rank
	return false


func test_cadre_state_survives_a_save_and_a_lost_cadre_loses_it() -> void:
	var state: RunState = RunState.new(7)
	state.inventory.cadres.assign(["steel_target", "seed_grain"])
	state.cadre_memos.entry("steel_target").put(SteelTargetEffect.BOMBS, 4)
	state.cadre_memos.entry("seed_grain").put(SeedGrainEffect.MET, 2)
	var copy: RunState = RunState.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())))
	assert_int(copy.cadre_memos.peek("steel_target").value(SteelTargetEffect.BOMBS)).is_equal(4)
	assert_int(copy.cadre_memos.peek("seed_grain").value(SeedGrainEffect.MET)).is_equal(2)
	copy.inventory.cadres.erase("steel_target")
	copy.cadre_memos.keep_only(copy.inventory.cadres)
	assert_bool(copy.cadre_memos.has("steel_target")).is_false()
	assert_bool(copy.cadre_memos.has("seed_grain")).is_true()


## Reeducation exchanges a held Cadre; the one exchanged loses its state with it.
func test_reeducation_clears_the_exchanged_cadres_state() -> void:
	var loop: RunLoop = RunLoop.new(RunState.new(5103), RunScript.bots(), SetConfig.new())
	loop.state.inventory.cadres.assign(["steel_target"])
	loop.state.cadre_memos.entry("steel_target").put(SteelTargetEffect.BOMBS, 3)
	loop.start_set()
	RunScript.new().play_until_set_over(loop)
	loop.state.reeducation_due = true
	assert_int(loop.open_shop()).is_equal(RunLoop.Reason.OK)
	assert_array(loop.state.inventory.cadres).not_contains(["steel_target"])
	assert_bool(loop.state.cadre_memos.has("steel_target")).is_false()


func test_held_cadres_count_a_year_at_each_years_end() -> void:
	var memos: CadreMemos = CadreMemos.new()
	var held: Array[String] = ["rehabilitation"]
	memos.new_year(held)
	memos.new_year(held)
	assert_int(memos.peek("rehabilitation").value(CadreMemo.YEARS)).is_equal(2)


## Ration Coupon and Stakhanovite count from the real turns of a whole Set, the coupons
## reach the player, each one is logged on the Cadre, and the count replays exactly.
func test_counts_come_from_real_turns_and_replay_from_the_record() -> void:
	var state: RunState = RunState.new(5104)
	state.inventory.cadres.assign(["ration_coupon", "stakhanovite", "steel_target"])
	var loop: RunLoop = RunLoop.new(state, RunScript.bots(), SetConfig.new())
	loop.start_set()
	var checkpoint: Dictionary = loop.record.to_dict()["checkpoint"]
	RunScript.new().play_until_set_over(loop)
	var fired: int = 0
	var paid: int = 0
	for event: RunEvent in loop.events():
		if event.type == RunEvent.Type.CADRE_FIRED and event.text == "ration_coupon":
			fired += 1
			paid += event.value
	var passes: int = 0
	for event: RunEvent in loop.events():
		if event.type == RunEvent.Type.ROUND and event.round_event.type == RoundEvent.Type.PASSED:
			passes += 1 if event.round_event.seat == RunLoop.PLAYER else 0
	# Counted from the Set's log: one coupon per four passes, at most three. The Quota's
	# end then starts the count again.
	assert_int(paid).is_equal(mini(floori(passes / 4.0), 3))
	assert_int(fired).is_equal(paid)
	var ration: CadreMemo = loop.state.cadre_memos.peek("ration_coupon")
	assert_int(ration.value(RationCouponEffect.EARNED)).is_equal(0)
	# The same checkpoint and the same player give the same state.
	var replay: RunLoop = RunLoop.new(RunState.from_dict(checkpoint), RunScript.bots())
	replay.start_set()
	RunScript.new().play_until_set_over(replay)
	assert_dict(replay.state.cadre_memos.to_dict()).is_equal(loop.state.cadre_memos.to_dict())
	assert_int(replay.state.coupons).is_equal(loop.state.coupons)
