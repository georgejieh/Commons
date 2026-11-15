extends GdUnitTestSuite
## ADR 0021's eight Campaigns played through the run loop: each one's effect, its
## refusals, which change nothing, and the Resentment or meter it moves. Round-scoped
## effects end with their round.

const SEEDS: int = 80


func _loop(seed_value: int, held: Array[String]) -> RunLoop:
	var state: RunState = RunState.new(seed_value)
	state.inventory.consumables.assign(held)
	var loop: RunLoop = RunLoop.new(state, RunScript.bots(), SetConfig.new())
	loop.start_set()
	return loop


## Plays the player's seat until moment says the loop stands where a test wants it.
func _drive(loop: RunLoop, moment: Callable, limit: int = 300) -> bool:
	var script: RunScript = RunScript.new()
	for _step: int in limit:
		if moment.call(loop):
			return true
		if not script.act(loop):
			return false
	return false


## The first seed, from start, whose run reaches the moment with these Campaigns held.
func _find(held: Array[String], moment: Callable, start: int = 1) -> RunLoop:
	for seed_value: int in range(start, start + SEEDS):
		var loop: RunLoop = _loop(seed_value, held)
		if _drive(loop, moment):
			return loop
	return null


func _my_turn(loop: RunLoop) -> bool:
	return loop.awaiting() == RunLoop.Awaiting.PLAYER_PLAY


func _answering_with_cards(loop: RunLoop) -> bool:
	if not _my_turn(loop):
		return false
	var view: SeatView = loop.round_state().view_for(0)
	return view.public.current_play != null and view.own_cards.size() >= 3


func _first_turn_as_landlord(loop: RunLoop) -> bool:
	return _my_turn(loop) and loop.round_state().public_view().history.is_empty()


func _opening(loop: RunLoop) -> bool:
	return loop.awaiting() == RunLoop.Awaiting.PLAYER_OPENING


func _ids(cards: Array[CardInstance], count: int) -> Array[int]:
	var ids: Array[int] = []
	for card: CardInstance in cards.slice(0, count):
		ids.append(card.id())
	return ids


func _events_of(loop: RunLoop, type: RunEvent.Type) -> Array[RunEvent]:
	return loop.events().filter(func(event: RunEvent) -> bool: return event.type == type)


## A refused use leaves the state and the record as they were.
func _refused(loop: RunLoop, slot: int, ids: Array[int], reason: CampaignEffect.Reason) -> void:
	var before: Dictionary = loop.state.to_dict()
	var commands: int = loop.record.commands.size()
	assert_int(loop.campaign_reason(slot, ids)).is_equal(reason)
	assert_int(loop.player_campaign(slot, ids)).is_not_equal(RunLoop.Reason.OK)
	assert_dict(loop.state.to_dict()).is_equal(before)
	assert_int(loop.record.commands.size()).is_equal(commands)


func test_model_harvest_marks_chosen_cards_for_the_run() -> void:
	var loop: RunLoop = _find(["model_harvest", "model_harvest"], _my_turn)
	var hand: Array[CardInstance] = loop.player_cards()
	var none: Array[int] = []
	_refused(loop, 0, none, CampaignEffect.Reason.CARD_COUNT)
	_refused(loop, 0, _ids(hand, 3), CampaignEffect.Reason.CARD_COUNT)
	var foreign: Array[int] = [999]
	_refused(loop, 0, foreign, CampaignEffect.Reason.NOT_IN_HAND)
	var chosen: Array[int] = _ids(hand, 2)
	assert_int(loop.player_campaign(0, chosen)).is_equal(RunLoop.Reason.OK)
	assert_array(loop.state.inventory.consumables).is_equal(["model_harvest"])
	for card: CardInstance in loop.player_cards():
		var model: bool = card.enhancement_id() == CardInstance.MODEL
		assert_bool(model).is_equal(chosen.has(card.id()))
	for card_id: int in chosen:
		if card_id < Deck.SIZE:
			assert_str(loop.state.card_marks.enhancements[card_id]).is_equal(CardInstance.MODEL)
	var marked: Array[RunEvent] = _events_of(loop, RunEvent.Type.CARDS_MARKED)
	assert_int(marked.size()).is_equal(1)
	assert_int(marked[0].value).is_equal(1)
	var again: Array[int] = [chosen[0]]
	_refused(loop, 0, again, CampaignEffect.Reason.ALREADY_MARKED)
	assert_int(loop.awaiting()).is_equal(RunLoop.Awaiting.PLAYER_PLAY)


func test_registration_drive_stamps_one_to_three_cards_and_breeds_nothing_on_use() -> void:
	var loop: RunLoop = _find(["registration_drive"], _my_turn)
	var resentment: int = loop.state.resentment
	_refused(loop, 0, _ids(loop.player_cards(), 4), CampaignEffect.Reason.CARD_COUNT)
	var chosen: Array[int] = _ids(loop.player_cards(), 3)
	assert_int(loop.player_campaign(0, chosen)).is_equal(RunLoop.Reason.OK)
	for card: CardInstance in loop.player_cards():
		var stamped: bool = card.owner_stamp() == RunLoop.PLAYER
		assert_bool(stamped).is_equal(chosen.has(card.id()))
	assert_int(loop.state.resentment).is_equal(resentment)
	assert_int(_events_of(loop, RunEvent.Type.CARDS_MARKED)[0].value).is_equal(0)


func test_no_campaign_is_used_outside_its_moment() -> void:
	var loop: RunLoop = _loop(3, ["model_harvest", "grain_loan"])
	assert_bool(_drive(loop, _bidding)).is_true()
	var none: Array[int] = []
	assert_int(loop.campaign_reason(1, none)).is_equal(CampaignEffect.Reason.NOT_NOW)
	assert_int(loop.player_campaign(1, none)).is_equal(RunLoop.Reason.NOT_AWAITED)
	assert_int(loop.campaign_reason(5, none)).is_equal(CampaignEffect.Reason.NO_SUCH_SLOT)


func test_mutual_aid_trades_two_cards_with_the_teammate_before_the_first_play() -> void:
	var loop: RunLoop = _find(["mutual_aid"], _opening)
	assert_object(loop).is_not_null()
	var round_state: RoundState = loop.round_state()
	var mate: int = 3 - round_state.landlord()
	var mate_view: SeatView = round_state.view_for(mate)
	var expected: Array[int] = AidChoice.choose(mate_view, loop.seat_table(mate).rank_map, 2)
	var one: Array[int] = _ids(loop.player_cards(), 1)
	_refused(loop, 0, one, CampaignEffect.Reason.CARD_COUNT)
	var given: Array[int] = _ids(loop.player_cards(), 2)
	var sizes: PackedInt32Array = round_state.remaining()
	assert_int(loop.player_campaign(0, given)).is_equal(RunLoop.Reason.OK)
	# Nothing else to use at the opening, so the round plays on.
	assert_int(loop.awaiting()).is_not_equal(RunLoop.Awaiting.PLAYER_OPENING)
	var moved: Array[RunEvent] = _events_of(loop, RunEvent.Type.CARDS_MOVED)
	assert_int(moved.size()).is_equal(2)
	assert_int(moved[0].seat).is_equal(0)
	assert_int(moved[0].value).is_equal(mate)
	var expected_text: PackedStringArray = []
	for card_id: int in expected:
		expected_text.append(str(card_id))
	assert_str(moved[1].text).is_equal(",".join(expected_text))
	var held: Array[int] = []
	for card: CardInstance in loop.round_state().view_for(0).own_cards:
		held.append(card.id())
	for card_id: int in expected:
		assert_bool(held.has(card_id) or _played_by(loop, 0, card_id)).is_true()
	# Hand sizes are kept; any difference now is from plays made since.
	assert_int(sizes[0]).is_equal(Dealer.HAND_SIZE)


func _played_by(loop: RunLoop, seat: int, card_id: int) -> bool:
	for event: RunEvent in loop.events():
		var played: RoundEvent = event.round_event
		if played != null and played.type == RoundEvent.Type.PLAYED and played.seat == seat:
			if played.card_ids.has(card_id):
				return true
	return false


func test_mutual_aid_is_refused_to_the_landlord_and_once_play_starts() -> void:
	var loop: RunLoop = _find(["mutual_aid"], _first_turn_as_landlord)
	var two: Array[int] = _ids(loop.player_cards(), 2)
	_refused(loop, 0, two, CampaignEffect.Reason.NOT_PEASANT)
	var later: RunLoop = _find(["mutual_aid"], _peasant_turn)
	_refused(later, 0, _ids(later.player_cards(), 2), CampaignEffect.Reason.PLAY_STARTED)


## Overfulfillment's bank against the same round played without it: multiplied on a
## win, nothing on a loss, and the next round banks as usual.
func test_overfulfillment_multiplies_a_won_bank_and_voids_a_lost_one() -> void:
	var outcomes: Dictionary[int, bool] = {}
	for seed_value: int in range(1, SEEDS):
		var staked: RunLoop = _loop(seed_value, ["overfulfillment"])
		if not _drive(staked, _first_turn_as_landlord):
			continue
		var plain: RunLoop = _loop(seed_value, ["overfulfillment"])
		_drive(plain, _first_turn_as_landlord)
		var none: Array[int] = []
		assert_int(staked.player_campaign(0, none)).is_equal(RunLoop.Reason.OK)
		var to_end: Callable = _past_round.bind(staked.state.round_index)
		_drive(staked, to_end)
		_drive(plain, to_end)
		var settled: Array[RunEvent] = _events_of(staked, RunEvent.Type.STAKE_SETTLED)
		assert_int(settled.size()).is_equal(1)
		var won: bool = settled[0].value == 1
		var bank: float = _last_bank(plain)
		var expected: float = bank * 2.0 if won else 0.0
		assert_float(_last_bank(staked)).is_equal_approx(expected, 0.001)
		assert_float(settled[0].amount).is_equal_approx(expected, 0.001)
		assert_bool(staked.campaigns.flags.staked).is_false()
		outcomes[1 if won else 0] = true
		if outcomes.size() == 2:
			break
	assert_int(outcomes.size()).is_equal(2)


## The bank of the round that ended last.
func _last_bank(loop: RunLoop) -> float:
	var banks: Array[RunEvent] = _events_of(loop, RunEvent.Type.BANKED)
	return banks[-1].amount


func _past_round(loop: RunLoop, round_index: int) -> bool:
	return loop.state.round_index > round_index


func _with_debuff(at: RunLoop) -> bool:
	if not (_opening(at) or _first_turn_as_landlord(at)):
		return false
	return at.state.debuff_ladder[at.state.round_index] != RunState.NO_DEBUFF


func _clean_first_turn(at: RunLoop) -> bool:
	return _first_turn_as_landlord(at) and at.state.round_index == 0


func _answering(at: RunLoop) -> bool:
	return _my_turn(at) and at.round_state().current_play() != null


func _can_play(at: RunLoop) -> bool:
	return _my_turn(at) and not at.round_state().legal_moves().is_empty()


func _bidding(at: RunLoop) -> bool:
	return at.awaiting() == RunLoop.Awaiting.PLAYER_BID


func _peasant_turn(at: RunLoop) -> bool:
	return _my_turn(at) and at.round_state().landlord() != 0


func test_overfulfillment_is_refused_to_a_peasant_and_twice_in_a_round() -> void:
	var loop: RunLoop = _find(["mutual_aid", "overfulfillment"], _opening)
	var none: Array[int] = []
	_refused(loop, 1, none, CampaignEffect.Reason.NOT_LANDLORD)
	var twice: RunLoop = _find(["overfulfillment", "overfulfillment"], _first_turn_as_landlord)
	assert_int(twice.player_campaign(0, none)).is_equal(RunLoop.Reason.OK)
	_refused(twice, 0, none, CampaignEffect.Reason.ALREADY_USED)


func test_appeal_lifts_this_rounds_debuff_for_the_round_only() -> void:
	var loop: RunLoop = _find(["appeal", "appeal"], _with_debuff)
	assert_object(loop).is_not_null()
	var debuff: String = loop.state.debuff_ladder[loop.state.round_index]
	var none: Array[int] = []
	assert_int(loop.player_campaign(0, none)).is_equal(RunLoop.Reason.OK)
	assert_bool(loop.campaigns.flags.round_debuff.enabled).is_false()
	assert_str(loop.campaigns.flags.lifted).is_equal(debuff)
	var lifted: Array[RunEvent] = _events_of(loop, RunEvent.Type.DEBUFF_LIFTED)
	assert_str(lifted[0].text).is_equal(debuff)
	# A second Appeal is refused while the first play is still to come, and the opening
	# ends by itself once nothing there can be used.
	if _first_turn_as_landlord(loop):
		_refused(loop, 0, none, CampaignEffect.Reason.NO_DEBUFF)
	else:
		assert_int(loop.awaiting()).is_not_equal(RunLoop.Awaiting.PLAYER_OPENING)
	var round_index: int = loop.state.round_index
	_drive(loop, _past_round.bind(round_index))
	assert_str(loop.campaigns.flags.lifted).is_equal(RunState.NO_DEBUFF)


func test_appeal_is_refused_on_a_clean_round() -> void:
	var loop: RunLoop = _find(["appeal"], _clean_first_turn)
	var none: Array[int] = []
	_refused(loop, 0, none, CampaignEffect.Reason.NO_DEBUFF)


func test_grain_loan_pays_coupons_for_famine_at_the_table_and_in_the_shop() -> void:
	var loop: RunLoop = _find(["grain_loan", "grain_loan"], _my_turn)
	var coupons: int = loop.state.coupons
	var famine: int = loop.state.famine
	var none: Array[int] = []
	assert_int(loop.player_campaign(0, none)).is_equal(RunLoop.Reason.OK)
	assert_int(loop.state.coupons).is_equal(coupons + 5)
	assert_int(loop.state.famine).is_equal(famine + 3)
	var meter: Array[RunEvent] = _events_of(loop, RunEvent.Type.METER_CHANGED)
	assert_str(meter[-1].text).is_equal(RunMeters.FAMINE)
	assert_int(_events_of(loop, RunEvent.Type.COUPONS_GAINED)[0].value).is_equal(5)
	RunScript.new().play_until_set_over(loop)
	while loop.awaiting() != RunLoop.Awaiting.SET_OVER:
		assert_bool(RunScript.new().act(loop)).is_true()
	assert_int(loop.open_shop()).is_equal(RunLoop.Reason.OK)
	coupons = loop.state.coupons
	assert_int(loop.player_campaign(0, none)).is_equal(RunLoop.Reason.OK)
	assert_int(loop.state.coupons).is_equal(coupons + 5)
	assert_int(loop.awaiting()).is_equal(RunLoop.Awaiting.SHOP)


func test_a_grain_loan_that_starves_the_village_ends_the_run() -> void:
	var loop: RunLoop = _find(["grain_loan"], _my_turn)
	RunScript.new().play_until_set_over(loop)
	loop.open_shop()
	loop.state.famine = RunLoop.DEFAULT_METERS.famine.death - 1
	var none: Array[int] = []
	assert_int(loop.player_campaign(0, none)).is_equal(RunLoop.Reason.OK)
	assert_int(loop.awaiting()).is_equal(RunLoop.Awaiting.RUN_OVER)
	assert_int(_events_of(loop, RunEvent.Type.RUN_DIED).size()).is_equal(1)
	# At the table the run dies at the round's end, the next state that may end it.
	var table: RunLoop = _find(["grain_loan"], _my_turn)
	table.state.famine = RunLoop.DEFAULT_METERS.famine.death - 1
	assert_int(table.player_campaign(0, none)).is_equal(RunLoop.Reason.OK)
	assert_int(table.awaiting()).is_equal(RunLoop.Awaiting.PLAYER_PLAY)
	RunScript.new().play_until_set_over(table)
	assert_int(table.awaiting()).is_equal(RunLoop.Awaiting.RUN_OVER)


func test_seizure_notice_takes_the_opponents_highest_for_your_lowest() -> void:
	var loop: RunLoop = _find(["seizure_notice"], _answering_with_cards)
	var resentment: int = loop.state.resentment
	var round_state: RoundState = loop.round_state()
	var sizes: PackedInt32Array = round_state.remaining()
	var none: Array[int] = []
	assert_int(loop.player_campaign(0, none)).is_equal(RunLoop.Reason.OK)
	assert_array(Array(round_state.remaining())).is_equal(Array(sizes))
	assert_int(loop.state.resentment).is_equal(resentment + 4)
	var moved: Array[RunEvent] = _events_of(loop, RunEvent.Type.CARDS_MOVED)
	assert_int(moved.size()).is_equal(2)
	var taken: int = moved[1].text.to_int()
	var given: int = moved[0].text.to_int()
	var held: Array[int] = []
	for card: CardInstance in loop.player_cards():
		held.append(card.id())
	assert_bool(held.has(taken)).is_true()
	assert_bool(held.has(given)).is_false()
	var rank_map: PackedByteArray = loop.seat_table(0).rank_map
	for card: CardInstance in loop.player_cards():
		if card.id() != taken:
			assert_int(rank_map[card.base_rank()]).is_greater_equal(
				rank_map[Deck.rank_of(given)] if given < Deck.SIZE else 0
			)


func test_anonymous_letter_makes_the_next_seat_pass_your_play() -> void:
	var loop: RunLoop = _find(["anonymous_letter", "anonymous_letter"], _can_play)
	var resentment: int = loop.state.resentment
	var none: Array[int] = []
	assert_int(loop.player_campaign(0, none)).is_equal(RunLoop.Reason.OK)
	assert_int(loop.state.resentment).is_equal(resentment + 2)
	_refused(loop, 0, none, CampaignEffect.Reason.ALREADY_USED)
	var moves: Array[Pattern] = loop.round_state().legal_moves()
	var move: Pattern = moves[moves.size() - 1]
	var seen: int = loop.events().size()
	var ids: Array[int] = loop.round_state().action_for(move).card_ids
	assert_int(loop.player_play(ids)).is_equal(RunLoop.Reason.OK)
	var after: Array[RunEvent] = loop.events().slice(seen)
	var forced: int = -1
	for index: int in after.size():
		if after[index].type == RunEvent.Type.PASS_FORCED:
			forced = index
	if loop.round_state() == null or after.any(_ends_round):
		return
	assert_int(forced).is_greater_equal(0)
	assert_int(after[forced].seat).is_equal(1)
	var next: RoundEvent = after[forced + 1].round_event
	assert_int(next.type).is_equal(RoundEvent.Type.PASSED)
	assert_int(next.seat).is_equal(1)


func _ends_round(event: RunEvent) -> bool:
	return event.round_event != null and event.round_event.type == RoundEvent.Type.ROUND_ENDED


func test_a_letter_is_spent_for_nothing_on_a_pass() -> void:
	var loop: RunLoop = _find(["anonymous_letter"], _answering)
	var none: Array[int] = []
	assert_int(loop.player_campaign(0, none)).is_equal(RunLoop.Reason.OK)
	assert_int(loop.player_play(none)).is_equal(RunLoop.Reason.OK)
	assert_int(_events_of(loop, RunEvent.Type.LETTER_LAPSED).size()).is_equal(1)
	assert_int(_events_of(loop, RunEvent.Type.PASS_FORCED).size()).is_equal(0)
