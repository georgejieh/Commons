extends GdUnitTestSuite
## The four rank modifiers, including that legal moves stay legal under each.

const SEED: int = 1904
const GAMES: int = 200
## Every three actions play at least one card, so a game can't need more.
const MAX_ACTIONS: int = 162


func _table(names: Array[String], holder: int = 0) -> SeatRules:
	var stack: ModifierStack = ModifierStack.new()
	for name: String in names:
		stack.add(ResourceLoader.load("res://data/modifiers/%s.tres" % name), holder)
	return SeatRules.new(stack)


func _round(table: SeatRules, seats: Array[String]) -> RoundState:
	return RoundState.new(RoundScript.stacked_deal(seats, ""), 0, table)


func _play(round_state: RoundState, table: SeatRules, text: String) -> RoundState.Reason:
	var seat: int = round_state.seat_to_act()
	var read: Classification = Classifier.classify(
		RankText.counts(text), table.rules_for(seat), table.map_for(seat)
	)
	return round_state.apply(round_state.action_for(read.pattern))


func _pass(round_state: RoundState) -> void:
	round_state.apply(RoundAction.new(round_state.seat_to_act()))


func test_promotion_puts_threes_above_twos_and_below_jokers() -> void:
	var map: PackedByteArray = _table(["promotion_of_the_masses"]).map_for(1)
	assert_bool(map[Ranks.THREE] > map[Ranks.TWO]).is_true()
	assert_bool(map[Ranks.THREE] < map[Ranks.SMALL_JOKER]).is_true()
	for rank: int in range(Ranks.FOUR, Ranks.TWO):
		assert_bool(map[rank] < map[rank + 1]).is_true()


func test_promotion_never_breaks_a_straight() -> void:
	var table: SeatRules = _table(["promotion_of_the_masses"])
	var read: Classification = Classifier.classify(
		RankText.counts("34567"), table.rules_for(0), table.map_for(0)
	)
	assert_int(read.pattern.type).is_equal(Pattern.Type.STRAIGHT)


func test_promotion_changes_who_wins() -> void:
	var table: SeatRules = _table(["promotion_of_the_masses"])
	var round_state: RoundState = _round(table, ["29", "3", "4"])
	assert_int(_play(round_state, table, "2")).is_equal(RoundState.Reason.OK)
	assert_int(_play(round_state, table, "3")).is_equal(RoundState.Reason.OK)


func test_criticism_meeting_lowers_only_the_holders_twos() -> void:
	var table: SeatRules = _table(["criticism_meeting"], 1)
	assert_int(table.map_for(1)[Ranks.TWO]).is_equal(Ranks.THREE)
	assert_int(table.map_for(0)[Ranks.TWO]).is_equal(Ranks.TWO)
	var round_state: RoundState = _round(table, ["49", "2J", "5"])
	assert_int(_play(round_state, table, "4")).is_equal(RoundState.Reason.OK)
	assert_int(_play(round_state, table, "2")).is_equal(RoundState.Reason.DOES_NOT_BEAT)


func test_inverted_order_reverses_only_the_holders_plays() -> void:
	var table: SeatRules = _table(["inverted_order"], 1)
	var round_state: RoundState = _round(table, ["KJ", "3Q", "5"])
	assert_int(_play(round_state, table, "K")).is_equal(RoundState.Reason.OK)
	assert_int(_play(round_state, table, "3")).is_equal(RoundState.Reason.OK)
	assert_int(_play(round_state, table, "5")).is_equal(RoundState.Reason.DOES_NOT_BEAT)


func test_inverted_order_reverses_every_rank_for_the_holder_alone() -> void:
	var table: SeatRules = _table(["inverted_order"], 1)
	assert_bool(table.map_for(0) == Ranks.identity_map()).is_true()
	assert_bool(table.map_for(2) == Ranks.identity_map()).is_true()
	for rank: int in Ranks.COUNT:
		assert_int(table.map_for(1)[rank]).is_equal(Ranks.COUNT - 1 - rank)


func test_a_tied_rank_does_not_beat() -> void:
	var table: SeatRules = _table(["criticism_meeting"], 1)
	var round_state: RoundState = _round(table, ["39", "2J", "5"])
	assert_int(_play(round_state, table, "3")).is_equal(RoundState.Reason.OK)
	assert_int(_play(round_state, table, "2")).is_equal(RoundState.Reason.DOES_NOT_BEAT)


func test_a_promoted_chain_compares_by_its_lowest_rank() -> void:
	var table: SeatRules = _table(["promotion_of_the_masses"])
	var round_state: RoundState = _round(table, ["TJQKA9", "345678", "5"])
	assert_int(_play(round_state, table, "TJQKA")).is_equal(RoundState.Reason.OK)
	assert_int(_play(round_state, table, "34567")).is_equal(RoundState.Reason.OK)


func test_repeated_promotion_changes_nothing() -> void:
	var once: SeatRules = _table(["promotion_of_the_masses"])
	var twice: SeatRules = _table(["promotion_of_the_masses", "promotion_of_the_masses"])
	assert_bool(once.map_for(0) == twice.map_for(0)).is_true()


func _assert_no_ties(rank_map: PackedByteArray) -> void:
	var seen: Dictionary[int, bool] = {}
	for rank: int in Ranks.COUNT:
		seen[rank_map[rank]] = true
	assert_int(seen.size()).is_equal(Ranks.COUNT)


func test_promotion_and_inversion_compose_in_either_order() -> void:
	var first: SeatRules = _table(["cultural_revolution", "promotion_of_the_masses"])
	var second: SeatRules = _table(["promotion_of_the_masses", "cultural_revolution"])
	first.set_trick_bombed(true)
	second.set_trick_bombed(true)
	_assert_no_ties(first.map_for(0))
	_assert_no_ties(second.map_for(0))
	var promoted_after: PackedByteArray = first.map_for(0)
	assert_bool(promoted_after[Ranks.THREE] > promoted_after[Ranks.TWO]).is_true()
	var inverted_after: PackedByteArray = second.map_for(0)
	assert_bool(inverted_after[Ranks.THREE] < inverted_after[Ranks.TWO]).is_true()


func test_a_modifier_added_mid_trick_applies_at_once() -> void:
	var stack: ModifierStack = ModifierStack.new()
	var table: SeatRules = SeatRules.new(stack)
	var round_state: RoundState = _round(table, ["29", "34", "5"])
	assert_int(_play(round_state, table, "2")).is_equal(RoundState.Reason.OK)
	stack.add(ResourceLoader.load("res://data/modifiers/promotion_of_the_masses.tres"), 0)
	assert_int(round_state.legal_moves().size()).is_equal(1)
	assert_int(_play(round_state, table, "3")).is_equal(RoundState.Reason.OK)


func test_a_modifier_removed_mid_trick_refreshes_the_play_on_the_table() -> void:
	var stack: ModifierStack = ModifierStack.new()
	var entry: ActiveModifier = stack.add(
		ResourceLoader.load("res://data/modifiers/promotion_of_the_masses.tres"), 0
	)
	var table: SeatRules = SeatRules.new(stack)
	var round_state: RoundState = _round(table, ["39", "45", "6"])
	assert_int(_play(round_state, table, "3")).is_equal(RoundState.Reason.OK)
	stack.remove(entry)
	assert_int(_play(round_state, table, "4")).is_equal(RoundState.Reason.OK)


func test_the_refresh_reads_the_players_own_map() -> void:
	var stack: ModifierStack = ModifierStack.new()
	stack.add(ResourceLoader.load("res://data/modifiers/cultural_revolution.tres"), 0)
	stack.add(ResourceLoader.load("res://data/modifiers/inverted_order.tres"), 1)
	var table: SeatRules = SeatRules.new(stack)
	var round_state: RoundState = _round(table, ["34", "7777J", "5"])
	assert_int(_play(round_state, table, "3")).is_equal(RoundState.Reason.OK)
	assert_int(_play(round_state, table, "7777")).is_equal(RoundState.Reason.OK)
	var view: PublicView = round_state.public_view()
	var expected: int = table.map_for(1)[Ranks.SEVEN]
	assert_int(expected).is_equal(Ranks.SEVEN)
	assert_int(view.current_play.key & 0xFF).is_equal(expected)
	assert_int(view.history[1].pattern.key & 0xFF).is_equal(expected)


func test_a_round_ending_on_a_bomb_clears_the_inversion() -> void:
	var table: SeatRules = _table(["cultural_revolution"])
	var round_state: RoundState = _round(table, ["3333", "4", "5"])
	assert_int(_play(round_state, table, "3333")).is_equal(RoundState.Reason.OK)
	assert_bool(table.map_for(0) == Ranks.identity_map()).is_true()


func test_a_new_round_starts_with_a_clean_table() -> void:
	var table: SeatRules = _table(["cultural_revolution"])
	table.set_trick_bombed(true)
	_round(table, ["3", "4", "5"])
	assert_bool(table.map_for(0) == Ranks.identity_map()).is_true()


func test_cultural_revolution_inverts_after_a_bomb_until_the_trick_ends() -> void:
	var table: SeatRules = _table(["cultural_revolution"])
	var round_state: RoundState = _round(table, ["34", "77778888", "6666J5"])
	_pass_lead(round_state, table)
	assert_int(_play(round_state, table, "7777")).is_equal(RoundState.Reason.OK)
	assert_int(table.map_for(2)[Ranks.SIX]).is_equal(Ranks.COUNT - 1 - Ranks.SIX)
	assert_int(_play(round_state, table, "6666")).is_equal(RoundState.Reason.OK)
	_pass(round_state)
	_pass(round_state)
	assert_int(table.map_for(2)[Ranks.SIX]).is_equal(Ranks.SIX)


func test_a_higher_bomb_loses_once_ranks_are_inverted() -> void:
	var table: SeatRules = _table(["cultural_revolution"])
	var round_state: RoundState = _round(table, ["34", "77775", "88886"])
	_pass_lead(round_state, table)
	assert_int(_play(round_state, table, "7777")).is_equal(RoundState.Reason.OK)
	assert_int(_play(round_state, table, "8888")).is_equal(RoundState.Reason.DOES_NOT_BEAT)


## The landlord's 3 opens, so the bomb lands mid-trick.
func _pass_lead(round_state: RoundState, table: SeatRules) -> void:
	_play(round_state, table, "3")


func _random_game(table: SeatRules, stream: RandomStream, landlord: int) -> void:
	var cards: Array[CardInstance] = []
	for deck_id: int in Deck.generate():
		cards.append(CardInstance.from_deck_id(deck_id))
	var round_state: RoundState = RoundState.new(Dealer.deal(cards, stream), landlord, table)
	var actions: int = 0
	while not round_state.is_over() and actions < MAX_ACTIONS:
		actions += 1
		var moves: Array[Pattern] = round_state.legal_moves()
		var action: RoundAction = RoundAction.new(round_state.seat_to_act())
		var pick: int = stream.next_int(0, moves.size())
		if pick < moves.size():
			action = round_state.action_for(moves[pick])
		elif round_state.current_play() == null:
			action = round_state.action_for(moves[0])
		assert_int(round_state.apply(action)).is_equal(RoundState.Reason.OK)
	assert_bool(round_state.is_over()).is_true()


func test_every_generated_move_is_accepted_under_each_modifier() -> void:
	var stream: RandomStream = RandomStream.new(SEED)
	var names: Array[String] = [
		"cultural_revolution",
		"promotion_of_the_masses",
		"criticism_meeting",
		"inverted_order",
	]
	for name: String in names:
		for game: int in GAMES:
			_random_game(_table([name], (game + 1) % Seats.COUNT), stream, game % Seats.COUNT)
