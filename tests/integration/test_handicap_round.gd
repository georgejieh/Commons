extends GdUnitTestSuite
## The Handicap through the run (ADR 0043): in its boss Set every deal, redeals included,
## sets the Year's count of the player's cards aside before the bid and logs them, the
## player bids and plays short, every seat counts the round without them, and the bots play
## whole Sets around it with no refused action.

const HANDICAP: ModifierDef = preload("res://data/modifiers/bosses/the_handicap.tres")
## Every other official, as if each had already run, so the Year's official is the Handicap.
const OTHERS: Array[String] = ["struggle_session", "requisition", "great_leap", "the_purge"]
const STEPS: int = 1500


func _boss_loop(seed_value: int, year: int) -> RunLoop:
	var state: RunState = RunState.new(seed_value)
	state.year = year
	state.set_type = RunState.SetType.BOSS
	state.officials_used.assign(OTHERS)
	var loop: RunLoop = RunLoop.new(state, RunScript.bots())
	loop.start_set()
	return loop


func _count(loop: RunLoop, type: RunEvent.Type) -> int:
	var found: int = 0
	for event: RunEvent in loop.events():
		if event.type == type:
			found += 1
	return found


func test_every_deal_of_the_set_is_short_and_no_villager_is_refused() -> void:
	for year: int in [1, 4, 7]:
		var loop: RunLoop = _boss_loop(5100 + year, year)
		assert_str(loop.state.boss_id).is_equal(HANDICAP.id)
		var short: int = HandicapEffect.count_at(HANDICAP.parameters, year)
		var script: RunScript = RunScript.new()
		var checked: int = 0
		for _step: int in STEPS:
			if loop.awaiting() == RunLoop.Awaiting.PLAYER_BID:
				assert_int(loop.player_cards().size()).is_equal(Dealer.HAND_SIZE - short)
				assert_int(loop.set_aside_cards().size()).is_equal(short)
				checked += 1
			if loop.awaiting() == RunLoop.Awaiting.PLAYER_PLAY:
				_check_counts(loop, short)
			if not script.act(loop):
				break
		var over: Array[RunLoop.Awaiting] = [RunLoop.Awaiting.SET_OVER, RunLoop.Awaiting.RUN_OVER]
		var case: String = "year %d" % year
		assert_bool(over.has(loop.awaiting())).override_failure_message(case).is_true()
		assert_int(loop.refused_bot_actions).override_failure_message(case).is_zero()
		assert_int(checked).override_failure_message(case).is_greater(0)
		var deals: int = _count(loop, RunEvent.Type.DEALT)
		assert_int(_count(loop, RunEvent.Type.CARDS_SET_ASIDE)).is_equal(deals)


## Each logged set-aside names the Year's count of cards, none of them in any hand.
func test_the_logged_cards_are_out_of_every_hand() -> void:
	var loop: RunLoop = _boss_loop(5201, 4)
	var logged: Array[RunEvent] = []
	for event: RunEvent in loop.events():
		if event.type == RunEvent.Type.CARDS_SET_ASIDE:
			logged.append(event)
	assert_int(logged.size()).is_equal(1)
	assert_int(logged[0].seat).is_equal(RunLoop.PLAYER)
	var ids: PackedStringArray = logged[0].text.split(",")
	assert_int(ids.size()).is_equal(2)
	var script: RunScript = RunScript.new()
	while loop.round_state() == null and script.act(loop):
		pass
	for seat: int in Seats.COUNT:
		for card: CardInstance in loop.round_state().view_for(seat).own_cards:
			assert_bool(ids.has(str(card.id()))).is_false()


func test_a_set_without_the_handicap_sets_nothing_aside() -> void:
	var state: RunState = RunState.new(5301)
	var loop: RunLoop = RunLoop.new(state, RunScript.bots())
	loop.start_set()
	assert_int(_count(loop, RunEvent.Type.CARDS_SET_ASIDE)).is_zero()
	assert_int(loop.set_aside_cards().size()).is_zero()
	assert_int(loop.player_cards().size()).is_equal(Dealer.HAND_SIZE)


## Every seat, a villager as much as the player, counts the round without the cards set
## aside: the counts it was handed add up to the deck less them, and less any card a plot
## swap set aside for the player alone.
func _check_counts(loop: RunLoop, short: int) -> void:
	for seat: int in range(1, Seats.COUNT):
		var total: int = 0
		for count: int in loop.round_state().view_for(seat).deck_counts:
			total += count
		assert_int(total).is_equal(Deck.SIZE - short)
