extends GdUnitTestSuite
## ADR 0039: a Cadre works for the household that holds it. Golden tricks for the four
## Cadres that change what may be played or what beats what, from both sides: what the
## holder may play and beat, and what a villager may and may not play against it. Seat 1
## holds the Cadre. The landlord leads, and turns go 0, 1, 2.

const HOLDER: int = 1
const OK: RoundState.Reason = RoundState.Reason.OK
const DOES_NOT_BEAT: RoundState.Reason = RoundState.Reason.DOES_NOT_BEAT
const ILLEGAL: RoundState.Reason = RoundState.Reason.ILLEGAL_PLAY


func _table(id: String) -> SeatRules:
	var stack: ModifierStack = ModifierStack.new()
	stack.add(ResourceLoader.load("res://data/modifiers/%s.tres" % id), HOLDER)
	return SeatRules.new(stack)


func _round(table: SeatRules, seats: Array[String], landlord: int = 0) -> RoundState:
	return RoundState.new(RoundScript.stacked_deal(seats, ""), landlord, table)


## The seat to act plays its lowest-ID cards of these ranks, read as its rules read them.
func _play(round_state: RoundState, text: String) -> RoundState.Reason:
	var seat: int = round_state.seat_to_act()
	var wanted: PackedByteArray = RankText.counts(text)
	var ids: Array[int] = []
	for card: CardInstance in round_state.view_for(seat).own_cards:
		if wanted[card.base_rank()] > 0:
			wanted[card.base_rank()] -= 1
			ids.append(card.id())
	return round_state.apply(RoundAction.new(seat, ids))


func _pass(round_state: RoundState) -> void:
	assert_int(round_state.apply(RoundAction.new(round_state.seat_to_act()))).is_equal(OK)


func _offers(round_state: RoundState, type: Pattern.Type, cards: int) -> bool:
	return round_state.legal_moves().any(
		func(move: Pattern) -> bool: return move.type == type and move.card_count == cards
	)


## Promotion moves only the holder's 3s above 2s. Every other rank of the holder's stays
## level with the same rank of a villager's, so the Cadre never weakens a card it passes.
func test_promotion_raises_the_holders_threes_alone() -> void:
	var table: SeatRules = _table("promotion_of_the_masses")
	var answer: RoundState = _round(table, ["2K9", "3AK", "s45"])
	assert_int(_play(answer, "2")).is_equal(OK)
	assert_int(_play(answer, "3")).is_equal(OK)
	# The villager's small joker still beats a promoted 3.
	assert_int(_play(answer, "s")).is_equal(OK)
	var level: RoundState = _round(table, ["K9", "KA", "56"])
	assert_int(_play(level, "K")).is_equal(OK)
	assert_int(_play(level, "K")).is_equal(DOES_NOT_BEAT)
	assert_int(_play(level, "A")).is_equal(OK)
	# A villager's 3 is still the lowest card there is, and their 2 does not beat the
	# holder's 3.
	var lead: RoundState = _round(table, ["49", "3AK", "23J"])
	assert_int(_play(lead, "4")).is_equal(OK)
	assert_int(_play(lead, "3")).is_equal(OK)
	assert_int(_play(lead, "2")).is_equal(DOES_NOT_BEAT)
	assert_bool(_offers(lead, Pattern.Type.SINGLE, 1)).is_false()
	var low: RoundState = _round(table, ["49", "4AK", "35J"])
	_play(low, "4")
	_pass(low)
	assert_int(_play(low, "3")).is_equal(DOES_NOT_BEAT)
	assert_int(_play(low, "5")).is_equal(OK)


## After any bomb the holder's order turns over until the trick ends; the villagers' does
## not. A villager's 9s bomb is beaten by the holder's 8s, now high, but not by the
## holder's Ks, now low; and a villager still answers the holder's bomb in plain order.
func test_cultural_revolution_turns_only_the_holders_order() -> void:
	var table: SeatRules = _table("cultural_revolution")
	var trick: RoundState = _round(table, ["99993", "8888KKKK", "AAAA4"])
	assert_int(_play(trick, "9999")).is_equal(OK)
	assert_bool(table.map_for(0) == Ranks.identity_map()).is_true()
	assert_bool(table.map_for(2) == Ranks.identity_map()).is_true()
	assert_int(table.map_for(HOLDER)[Ranks.THREE]).is_equal(Ranks.BIG_JOKER)
	assert_int(_play(trick, "KKKK")).is_equal(DOES_NOT_BEAT)
	assert_int(_play(trick, "8888")).is_equal(OK)
	assert_int(_play(trick, "AAAA")).is_equal(OK)
	var after: RoundState = _round(table, ["99993", "8888K", "77774"])
	_play(after, "9999")
	_play(after, "8888")
	# The villager's 7s are below the holder's 8s in plain order and in turned order alike.
	assert_int(_play(after, "7777")).is_equal(DOES_NOT_BEAT)
	_pass(after)
	_pass(after)
	assert_bool(table.map_for(HOLDER) == Ranks.identity_map()).is_true()


## The holder may lead a 4-card Straight. A villager has no 4-card Straight to answer it
## with, or to lead, so against one they may pass or bomb; against a 5-card Straight they
## answer as always.
func test_shock_brigade_lets_the_holder_alone_play_short_straights() -> void:
	var table: SeatRules = _table("shock_brigade")
	var short: RoundState = _round(table, ["49TJQKA", "5678K", "6789T3333"], HOLDER)
	assert_int(_play(short, "5678")).is_equal(OK)
	assert_bool(_offers(short, Pattern.Type.STRAIGHT, 4)).is_false()
	assert_bool(_offers(short, Pattern.Type.BOMB, 4)).is_true()
	assert_int(_play(short, "789T")).is_equal(ILLEGAL)
	assert_int(_play(short, "3333")).is_equal(OK)
	var lead: RoundState = _round(table, ["34567K", "56789Q", "6789TJ"])
	assert_int(_play(lead, "3456")).is_equal(ILLEGAL)
	assert_int(_play(lead, "34567")).is_equal(OK)
	assert_int(_play(lead, "56789")).is_equal(OK)
	var long: RoundState = _round(table, ["34Q", "56789K", "6789TJ"], HOLDER)
	assert_int(_play(long, "56789")).is_equal(OK)
	assert_int(_play(long, "6789T")).is_equal(OK)


## The holder may lead a 2-pair Pair Run; a villager may neither lead one nor answer one,
## except with a bomb or the Rocket.
func test_double_share_plough_lets_the_holder_alone_play_two_pair_runs() -> void:
	var table: SeatRules = _table("double_share_plough")
	var held: RoundState = _round(table, ["3478", "5566K", "77889999"], HOLDER)
	assert_int(_play(held, "5566")).is_equal(OK)
	assert_bool(_offers(held, Pattern.Type.PAIR_CHAIN, 4)).is_false()
	assert_int(_play(held, "7788")).is_equal(ILLEGAL)
	assert_int(_play(held, "9999")).is_equal(OK)
	var lead: RoundState = _round(table, ["77889", "5566K", "34TT"])
	assert_int(_play(lead, "7788")).is_equal(ILLEGAL)
	assert_int(_play(lead, "9")).is_equal(OK)
