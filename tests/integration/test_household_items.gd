extends GdUnitTestSuite
## ADR 0039: whatever the player buys that changes how the game
## is played works for the player's seat alone. Golden tricks from both sides for Mass
## Line's and Model Worker's wild ranks and Industrialization's bigger bombs, alone, with
## each other, and with Promotion of the Masses and Shock Brigade: what the player may play
## and beat, what a villager may and may not play against it, and that a villager's card of
## the player's wild rank is a plain card. The player is seat 0, as in a run; the landlord
## leads and turns go 0, 1, 2. At the table Mass Line and Model Worker are the same thing,
## ranks wild for the player's seat; one rank stands for Mass Line, two for both together.

const PLAYER: int = RunLoop.PLAYER
const OK: RoundState.Reason = RoundState.Reason.OK
const DOES_NOT_BEAT: RoundState.Reason = RoundState.Reason.DOES_NOT_BEAT
const ILLEGAL: RoundState.Reason = RoundState.Reason.ILLEGAL_PLAY
const SEVENS: Array[int] = [Ranks.SEVEN]
const SEVENS_QUEENS: Array[int] = [Ranks.SEVEN, Ranks.QUEEN]
const BIG: Array[String] = ["industrialization"]
## IDs for copies of a rank past the deck's four, as the private plot holds them.
const PLOT_ID: int = 900


## Empty typed arrays, made fresh: two empty constants may be one array of one type.
func _no_reform() -> Array[String]:
	return []


func _no_wild() -> Array[int]:
	return []


## The table a run builds: the Cadres and Reforms held by the player, and the round's
## wild ranks for the player's seat.
func _table(cadres: Array[String], reforms: Array[String], wild: Array[int]) -> SeatRules:
	var stack: ModifierStack = ModifierStack.new()
	for cadre: String in cadres:
		stack.add(ResourceLoader.load("res://data/modifiers/%s.tres" % cadre), PLAYER)
	var state: RunState = RunState.new(1)
	state.reforms.assign(reforms)
	for rule: ActiveModifier in RunReforms.table_rules(state, PLAYER):
		stack.add_entry(rule)
	var table: SeatRules = SeatRules.new(stack)
	table.set_wild_ranks(wild, PLAYER)
	table.refresh()
	return table


## Stacked hands; plot gives a seat extra copies of ranks past the deck's four.
func _round(
	table: SeatRules, seats: Array[String], landlord: int = 0, plot: Dictionary = {}
) -> RoundState:
	var deal: DealResult = RoundScript.stacked_deal(seats, "")
	var next_id: int = PLOT_ID
	for seat: int in plot:
		for symbol: String in String(plot[seat]):
			var card: CardInstance = CardInstance.new(
				next_id, RankText.rank(symbol), 0, CardInstance.Origin.PLOT
			)
			deal.hands[seat].add(card)
			next_id += 1
	return RoundState.new(deal, landlord, table)


## The seat to act plays its lowest-ID cards of these printed ranks, read the strongest
## way its rules allow now.
func _play(round_state: RoundState, text: String) -> RoundState.Reason:
	var seat: int = round_state.seat_to_act()
	var wanted: PackedByteArray = RankText.counts(text)
	var ids: Array[int] = []
	for card: CardInstance in round_state.view_for(seat).own_cards:
		if wanted[card.base_rank()] > 0:
			wanted[card.base_rank()] -= 1
			ids.append(card.id())
	assert_int(ids.size()).override_failure_message("seat %d lacks %s" % [seat, text]).is_equal(
		text.length()
	)
	return round_state.apply(RoundAction.new(seat, ids))


func _pass(round_state: RoundState) -> void:
	assert_int(round_state.apply(RoundAction.new(round_state.seat_to_act()))).is_equal(OK)


func _offers(round_state: RoundState, type: Pattern.Type, cards: int = 0) -> bool:
	return round_state.legal_moves().any(
		func(move: Pattern) -> bool:
			return move.type == type and (cards == 0 or move.card_count == cards)
	)


## True when no move offered to the seat to act has a card standing in for another rank.
func _no_stand_ins(round_state: RoundState) -> bool:
	return round_state.legal_moves().all(func(move: Pattern) -> bool: return move.spent.is_empty())


func _table_play(round_state: RoundState) -> Pattern:
	return round_state.current_play()


func test_only_the_player_holds_the_wild_ranks() -> void:
	for wild: Array[int] in [SEVENS, SEVENS_QUEENS]:
		var table: SeatRules = _table([], _no_reform(), wild)
		assert_array(table.rules_for(PLAYER).wild_ranks()).is_equal(wild)
		for villager: int in [1, 2]:
			assert_array(table.rules_for(villager).wild_ranks()).is_empty()
	# A test or the tournament still makes a rank wild for every seat.
	var everyone: SeatRules = SeatRules.new(ModifierStack.new())
	everyone.set_wild_ranks(SEVENS)
	everyone.refresh()
	for seat: int in Seats.COUNT:
		assert_array(everyone.rules_for(seat).wild_ranks()).is_equal(SEVENS)


## The player's 7 stands in; a villager's 7 is a 7, in what they may play and in what they
## are offered.
func test_the_player_alone_may_play_a_wild_card_as_another_rank() -> void:
	var table: SeatRules = _table([], _no_reform(), SEVENS)
	var trio: RoundState = _round(table, ["9973", "TT7Q", "3456"])
	assert_int(_play(trio, "997")).is_equal(OK)
	assert_int(_table_play(trio).type).is_equal(Pattern.Type.TRIO)
	assert_int(_table_play(trio).main_rank).is_equal(Ranks.NINE)
	assert_bool(_offers(trio, Pattern.Type.TRIO)).is_false()
	assert_int(_play(trio, "TT7")).is_equal(ILLEGAL)
	var pair: RoundState = _round(table, ["4457", "T7JQ", "3456"], 1)
	assert_int(_play(pair, "T7")).is_equal(ILLEGAL)
	assert_bool(_no_stand_ins(pair)).is_true()
	assert_bool(_offers(pair, Pattern.Type.PAIR)).is_false()
	assert_int(_play(pair, "J")).is_equal(OK)
	_pass(pair)
	# The player's lone 7 is a 7, as a play of wild cards alone keeps one at its own rank.
	assert_int(_play(pair, "7")).is_equal(DOES_NOT_BEAT)
	# The same two cards are a Pair for the player.
	var mine: RoundState = _round(table, ["T7JQ", "4457", "3456"])
	assert_int(_play(mine, "T7")).is_equal(OK)
	assert_int(_table_play(mine).type).is_equal(Pattern.Type.PAIR)


## With two ranks wild, both are the player's alone.
func test_two_wild_ranks_are_both_the_players() -> void:
	var table: SeatRules = _table([], _no_reform(), SEVENS_QUEENS)
	var trick: RoundState = _round(table, ["Q7KK3", "Q7AA4", "3456"])
	assert_int(_play(trick, "Q7")).is_equal(OK)
	assert_int(_table_play(trick).type).is_equal(Pattern.Type.PAIR)
	assert_int(_play(trick, "Q7")).is_equal(ILLEGAL)
	assert_bool(_no_stand_ins(trick)).is_true()
	assert_int(_play(trick, "AA")).is_equal(OK)


## A villager's four 7s are a Bomb with no stand-in; the player's are the pure-wild bomb,
## above every other Bomb and below the Rocket, whoever answers it.
func test_four_of_the_wild_rank_are_pure_wild_for_the_player_alone() -> void:
	var table: SeatRules = _table([], _no_reform(), SEVENS)
	var theirs: RoundState = _round(table, ["8888K", "7777Q", "3456"], 1)
	assert_int(_play(theirs, "7777")).is_equal(OK)
	_pass(theirs)
	assert_int(_play(theirs, "8888")).is_equal(OK)
	var mine: RoundState = _round(table, ["7777K", "AAAAQ", "sb456"])
	assert_int(_play(mine, "7777")).is_equal(OK)
	assert_int(_play(mine, "AAAA")).is_equal(DOES_NOT_BEAT)
	_pass(mine)
	assert_int(_play(mine, "sb")).is_equal(OK)
	var over: RoundState = _round(table, ["7777K", "8888Q", "3456"], 1)
	assert_int(_play(over, "8888")).is_equal(OK)
	_pass(over)
	assert_int(_play(over, "7777")).is_equal(OK)


## The player's Bomb with a stand-in is below any Bomb without one, a villager's too.
func test_the_players_soft_bomb_falls_to_a_villagers_natural_bomb() -> void:
	var table: SeatRules = _table([], _no_reform(), SEVENS)
	var trick: RoundState = _round(table, ["9997K", "3333Q", "456"])
	assert_int(_play(trick, "9997")).is_equal(OK)
	assert_int(_table_play(trick).type).is_equal(Pattern.Type.BOMB)
	assert_int(_play(trick, "3333")).is_equal(OK)
	var lead: RoundState = _round(table, ["AAA7K", "3333Q", "456"], 1)
	assert_int(_play(lead, "3333")).is_equal(OK)
	_pass(lead)
	assert_int(_play(lead, "AAA7")).is_equal(DOES_NOT_BEAT)


## Only the player may play a Bomb of five or more cards. Against one a villager has only
## the Rocket: more cards beat fewer, so no villager Bomb of four answers it.
func test_industrialization_gives_the_player_alone_bigger_bombs() -> void:
	var table: SeatRules = _table([], BIG, _no_wild())
	var trick: RoundState = _round(table, ["9999K", "AAAA2", "sb34"], 0, {0: "9"})
	assert_int(_play(trick, "99999")).is_equal(OK)
	assert_int(_table_play(trick).card_count).is_equal(5)
	assert_bool(_offers(trick, Pattern.Type.BOMB)).is_false()
	assert_int(_play(trick, "AAAA")).is_equal(DOES_NOT_BEAT)
	_pass(trick)
	assert_int(_play(trick, "sb")).is_equal(OK)
	# The player's five 3s beat a villager's four 2s.
	var low: RoundState = _round(table, ["3333K", "2222Q", "456"], 1, {0: "3"})
	assert_int(_play(low, "2222")).is_equal(OK)
	_pass(low)
	assert_int(_play(low, "33333")).is_equal(OK)
	# A villager holding five of a rank may play four of them as a Bomb, never five.
	var five: RoundState = _round(table, ["3456K", "8888Q", "79TJ"], 1, {1: "8"})
	assert_int(_play(five, "88888")).is_equal(ILLEGAL)
	assert_bool(_offers(five, Pattern.Type.BOMB, 5)).is_false()
	assert_int(_play(five, "8888")).is_equal(OK)


## Together: the player's wild card makes a fifth, and four of a villager's own 7s never
## answer it.
func test_mass_line_and_industrialization_together() -> void:
	var table: SeatRules = _table([], BIG, SEVENS)
	var trick: RoundState = _round(table, ["99997K", "AAAAQ", "sb34"])
	assert_int(_play(trick, "99997")).is_equal(OK)
	assert_int(_table_play(trick).card_count).is_equal(5)
	assert_int(_play(trick, "AAAA")).is_equal(DOES_NOT_BEAT)
	_pass(trick)
	assert_int(_play(trick, "sb")).is_equal(OK)
	# A villager's four 7s and an Ace are no Bomb: the 7s are plain for them.
	var theirs: RoundState = _round(table, ["3456K", "7777A", "9999"], 1)
	assert_int(_play(theirs, "7777A")).is_equal(ILLEGAL)
	assert_int(_play(theirs, "7777")).is_equal(OK)
	# Two ranks wild: the player's Q and 7 both stand in for a fifth and a sixth 9.
	var two: RoundState = _round(_table([], BIG, SEVENS_QUEENS), ["9999Q7K", "AAAAJ", "sb34"])
	assert_int(_play(two, "9999Q7")).is_equal(OK)
	assert_int(_table_play(two).card_count).is_equal(6)
	assert_int(_play(two, "AAAA")).is_equal(DOES_NOT_BEAT)


## Promotion of the Masses with a wild rank: the player's 7 standing in for a 3 is a
## promoted 3, over a villager's 2s; a villager's 3s and 7s stay plain and low.
func test_wild_ranks_with_promotion_of_the_masses() -> void:
	var table: SeatRules = _table(["promotion_of_the_masses"], _no_reform(), SEVENS)
	var trick: RoundState = _round(table, ["37K", "22Q", "456"], 1)
	assert_int(_play(trick, "22")).is_equal(OK)
	_pass(trick)
	assert_int(_play(trick, "37")).is_equal(OK)
	assert_int(_table_play(trick).main_rank).is_equal(Ranks.THREE)
	var low: RoundState = _round(table, ["44K", "337Q", "568"])
	assert_int(_play(low, "44")).is_equal(OK)
	assert_int(_play(low, "37")).is_equal(ILLEGAL)
	assert_int(_play(low, "33")).is_equal(DOES_NOT_BEAT)
	# With bigger bombs too: the player's five promoted 3s beat a villager's four 2s.
	var big: SeatRules = _table(["promotion_of_the_masses"], BIG, SEVENS)
	var bomb: RoundState = _round(big, ["3333K", "2222Q", "456"], 1, {0: "3"})
	assert_int(_play(bomb, "2222")).is_equal(OK)
	_pass(bomb)
	assert_int(_play(bomb, "33333")).is_equal(OK)


## Shock Brigade with a wild rank: the player's 7 fills a 4-card Straight. A villager has
## no 4-card Straight to answer with, and no wild 7 to fill one; a Bomb answers, and the
## player's Bomb of five answers that.
func test_wild_ranks_and_bigger_bombs_with_shock_brigade() -> void:
	var table: SeatRules = _table(["shock_brigade"], _no_reform(), SEVENS)
	var short: RoundState = _round(table, ["5677K", "689T3333", "JQKA"])
	assert_int(_play(short, "5677")).is_equal(OK)
	assert_int(_table_play(short).type).is_equal(Pattern.Type.STRAIGHT)
	assert_int(_table_play(short).card_count).is_equal(4)
	assert_bool(_offers(short, Pattern.Type.STRAIGHT)).is_false()
	assert_int(_play(short, "689T")).is_equal(ILLEGAL)
	assert_int(_play(short, "3333")).is_equal(OK)
	var big: SeatRules = _table(["shock_brigade"], BIG, _no_wild())
	var trick: RoundState = _round(big, ["34569999J", "KKKKAAAAQ", "J78"], 0, {0: "9"})
	assert_int(_play(trick, "3456")).is_equal(OK)
	assert_int(_play(trick, "KKKK")).is_equal(OK)
	_pass(trick)
	assert_int(_play(trick, "99999")).is_equal(OK)
	assert_int(_play(trick, "AAAA")).is_equal(DOES_NOT_BEAT)


## The player's reading picker and hint read the player's rules: the same cards read two
## ways for the player and one way, or none, for a villager.
func test_readings_follow_the_seat_that_holds_the_cards() -> void:
	var table: SeatRules = _table([], _no_reform(), SEVENS)
	var round_state: RoundState = _round(table, ["9997K", "9", "3456"])
	var ids: Array[int] = []
	for card: CardInstance in round_state.view_for(PLAYER).own_cards:
		if card.base_rank() == Ranks.NINE or card.base_rank() == Ranks.SEVEN:
			ids.append(card.id())
	var mine: PlayReading = round_state.read_play(PLAYER, ids)
	assert_int(mine.readings.size()).is_greater(1)
	assert_int(mine.pattern.type).is_equal(Pattern.Type.BOMB)
	# Two cards a Pair for the player read no way at all for a villager.
	var pair: Array[Pattern] = Readings.of(
		RankText.counts("97"), table.rules_for(PLAYER), table.standing_for(PLAYER)
	)
	assert_int(pair.size()).is_equal(1)
	assert_int(pair[0].type).is_equal(Pattern.Type.PAIR)
	assert_bool(pair[0].spent.is_empty()).is_false()
	for villager: int in [1, 2]:
		var none: Array[Pattern] = Readings.of(
			RankText.counts("97"), table.rules_for(villager), table.standing_for(villager)
		)
		assert_array(none).is_empty()


## Cultural Revolution with a wild rank: after a villager's Bomb the player's order turns
## over, and a Bomb with a stand-in still falls below one without.
func test_wild_ranks_with_cultural_revolution() -> void:
	var table: SeatRules = _table(["cultural_revolution"], _no_reform(), SEVENS)
	var trick: RoundState = _round(table, ["8888KKK7", "9999Q", "3456"], 1)
	assert_int(_play(trick, "9999")).is_equal(OK)
	_pass(trick)
	assert_int(_play(trick, "KKK7")).is_equal(DOES_NOT_BEAT)
	assert_int(_play(trick, "8888")).is_equal(OK)
