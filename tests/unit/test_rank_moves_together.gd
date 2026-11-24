extends GdUnitTestSuite
## The rank-moving Cadres held together (ADR 0039): Promotion of the Masses, Rehabilitation
## and Class Label, in every slot order. In the holder's standings every rank none of them
## moved stays at its printed standing, so it ties a villager's same rank, and each moved
## rank sits in the gap just above the rank its seat order puts it over.

const HOLDER: int = 0
const VILLAGER: int = 1
const PROMOTION: String = "promotion_of_the_masses"
const REHABILITATION: String = "rehabilitation"
const CLASS_LABEL: String = "class_label"
const REVOLUTION: String = "cultural_revolution"
const INVERTED: String = "inverted_order"
## Rehabilitation's pick and Years held: some stop short of the 2, some reach it.
const REHAB_PICKS: Array[Vector2i] = [
	Vector2i(Ranks.ACE, 0),
	Vector2i(Ranks.KING, 1),
	Vector2i(Ranks.NINE, 0),
	Vector2i(Ranks.NINE, 5),
	Vector2i(Ranks.THREE, 0),
	Vector2i(Ranks.FIVE, 9),
]
## Class Label's fully stamped ranks, as bit masks.
const STAMPS: Array[int] = [
	1 << Ranks.THREE,
	1 << Ranks.KING,
	(1 << Ranks.FIVE) | (1 << Ranks.NINE),
	(1 << Ranks.ACE) | (1 << Ranks.FOUR),
]


func _def(id: String) -> ModifierDef:
	return ResourceLoader.load("res://data/modifiers/%s.tres" % id)


func _memo(pick: Vector2i) -> CadreMemo:
	var memo: CadreMemo = CadreMemo.new()
	memo.put(CadreMemo.RANK, pick.x)
	memo.put(CadreMemo.YEARS, pick.y)
	return memo


## Every ordered pair and triple of the three Cadres.
func _orders() -> Array[Array]:
	var ids: Array[String] = [PROMOTION, REHABILITATION, CLASS_LABEL]
	var orders: Array[Array] = []
	for first: String in ids:
		for second: String in ids:
			if second == first:
				continue
			orders.append([first, second])
			for third: String in ids:
				if third != first and third != second:
					orders.append([first, second, third])
	return orders


## The ranks the held Cadres may move.
func _moving(order: Array, pick: Vector2i, stamped: int) -> Dictionary[int, bool]:
	var moving: Dictionary[int, bool] = {}
	for id: String in order:
		if id == PROMOTION:
			moving[_def(PROMOTION).parameters["rank"]] = true
		elif id == REHABILITATION:
			moving[pick.x] = true
		elif id == CLASS_LABEL:
			for rank: int in Ranks.TWO:
				if stamped & (1 << rank) != 0:
					moving[rank] = true
	return moving


func _table(order: Array, pick: Vector2i, stamped: int) -> SeatRules:
	var stack: ModifierStack = ModifierStack.new()
	for id: String in order:
		stack.add(_def(id), HOLDER, _memo(pick) if id == REHABILITATION else null)
	var table: SeatRules = SeatRules.new(stack)
	table.start_round(HOLDER)
	table.set_stamped(HOLDER, stamped)
	table.refresh()
	return table


## Every combination this suite checks: order, Rehabilitation's pick, Class Label's stamps.
func _cases() -> Array[Array]:
	var cases: Array[Array] = []
	for order: Array in _orders():
		for pick: Vector2i in REHAB_PICKS:
			for stamped: int in STAMPS:
				if not order.has(CLASS_LABEL) and stamped != STAMPS[0]:
					continue
				if not order.has(REHABILITATION) and pick != REHAB_PICKS[0]:
					continue
				cases.append([order, pick, stamped])
	return cases


func _name(case: Array) -> String:
	return "%s pick %s stamps %x" % [case[0], case[1], case[2]]


func _single(table: SeatRules, seat: int, rank: int) -> Pattern:
	var counts: PackedByteArray = PackedByteArray()
	counts.resize(Ranks.COUNT)
	counts[rank] = 1
	var read: Classification = Classifier.classify(
		counts, table.rules_for(seat), table.standing_for(seat)
	)
	return read.pattern


func _beats(table: SeatRules, seat: int, rank: int, other: int, other_rank: int) -> bool:
	return PlayComparator.beats(
		_single(table, seat, rank), _single(table, other, other_rank), table.rules_for(seat)
	)


func test_unmoved_ranks_keep_their_printed_standing() -> void:
	for case: Array in _cases():
		var table: SeatRules = _table(case[0], case[1], case[2])
		var moving: Dictionary[int, bool] = _moving(case[0], case[1], case[2])
		var standing: PackedByteArray = table.standing_for(HOLDER)
		for rank: int in Ranks.COUNT:
			if not moving.has(rank):
				var label: String = "%s rank %d" % [_name(case), rank]
				assert_int(standing[rank]).override_failure_message(label).is_equal(
					Standing.identity()[rank]
				)


func test_standings_order_every_pair_as_the_seats_own_order() -> void:
	for case: Array in _cases():
		var table: SeatRules = _table(case[0], case[1], case[2])
		for bombed: bool in [false, true]:
			var order: PackedByteArray = table.map_in(HOLDER, bombed)
			var standing: PackedByteArray = table.standing_in(HOLDER, bombed)
			for a: int in Ranks.COUNT:
				for b: int in Ranks.COUNT:
					var label: String = "%s %d %d" % [_name(case), a, b]
					(
						assert_int(signi(standing[a] - standing[b]))
						. override_failure_message(label)
						. is_equal(signi(order[a] - order[b]))
					)


## An unmoved rank ties a villager's same rank and beats the one below; a moved rank beats
## a villager's rank it was put over and loses to the next printed rank above that.
func test_holder_ranks_meet_a_villagers_as_their_seat_order_says() -> void:
	for case: Array in _cases():
		var table: SeatRules = _table(case[0], case[1], case[2])
		var moving: Dictionary[int, bool] = _moving(case[0], case[1], case[2])
		var order: PackedByteArray = table.map_for(HOLDER)
		for rank: int in Ranks.COUNT:
			var label: String = "%s rank %d" % [_name(case), rank]
			if not moving.has(rank):
				(
					assert_bool(_beats(table, HOLDER, rank, VILLAGER, rank))
					. override_failure_message(label)
					. is_false()
				)
				(
					assert_bool(_beats(table, VILLAGER, rank, HOLDER, rank))
					. override_failure_message(label)
					. is_false()
				)
				if rank > 0:
					(
						assert_bool(_beats(table, HOLDER, rank, VILLAGER, rank - 1))
						. override_failure_message(label)
						. is_true()
					)
				continue
			var under: int = _unmoved_under(order, moving, rank)
			if under == Ranks.INVALID:
				continue
			(
				assert_bool(_beats(table, HOLDER, rank, VILLAGER, under))
				. override_failure_message(label)
				. is_true()
			)
			if under + 1 < Ranks.COUNT:
				(
					assert_bool(_beats(table, VILLAGER, under + 1, HOLDER, rank))
					. override_failure_message(label)
					. is_true()
				)
			if under == Ranks.TWO:
				assert_bool(_beats(table, VILLAGER, Ranks.SMALL_JOKER, HOLDER, rank)).is_true()


## The highest rank no Cadre moved that the seat's order puts below rank.
func _unmoved_under(order: PackedByteArray, moving: Dictionary[int, bool], rank: int) -> int:
	var found: int = Ranks.INVALID
	for other: int in Ranks.COUNT:
		if moving.has(other) or order[other] >= order[rank]:
			continue
		if found == Ranks.INVALID or order[other] > order[found]:
			found = other
	return found


## The reviewer's probe: Rehabilitation (the A, bought this Year) then Promotion. The
## holder's K must tie a villager's K, and the promoted 3 must beat a villager's 2.
func test_rehabilitation_then_promotion_keeps_the_kings_level() -> void:
	var table: SeatRules = _table([REHABILITATION, PROMOTION], Vector2i(Ranks.ACE, 0), 0)
	assert_bool(_beats(table, VILLAGER, Ranks.KING, HOLDER, Ranks.KING)).is_false()
	assert_bool(_beats(table, HOLDER, Ranks.THREE, VILLAGER, Ranks.TWO)).is_true()
	assert_bool(_beats(table, HOLDER, Ranks.ACE, VILLAGER, Ranks.TWO)).is_true()


func _has_single(moves: Array[Pattern], rank: int) -> bool:
	for move: Pattern in moves:
		if move.type == Pattern.Type.SINGLE and move.main_rank == rank:
			return true
	return false


func _rehab_then_promotion(order: Array) -> SeatRules:
	var stack: ModifierStack = ModifierStack.new()
	for id: String in order:
		var memo: CadreMemo = _memo(Vector2i(Ranks.ACE, 0)) if id == REHABILITATION else null
		stack.add(_def(id), HOLDER, memo)
	return SeatRules.new(stack)


## Plays text for the seat to act, then passes until seat is to act.
func _lead(round_state: RoundState, text: String, seat: int) -> void:
	assert_int(round_state.apply(RoundScript.play(round_state, text))).is_equal(
		RoundState.Reason.OK
	)
	while round_state.seat_to_act() != seat:
		round_state.apply(RoundAction.new(round_state.seat_to_act()))


## Through the round, with Rehabilitation and Promotion held in either order: a villager
## may not play a K over the holder's K but may play an A, and the holder may play its
## promoted 3 over a villager's 2.
func test_the_round_keeps_the_kings_level_and_the_three_over_the_two() -> void:
	for order: Array in [[REHABILITATION, PROMOTION], [PROMOTION, REHABILITATION]]:
		var label: String = str(order)
		var table: SeatRules = _rehab_then_promotion(order)
		var deal: DealResult = RoundScript.stacked_deal(["K4", "KA5", "66"], "")
		var round_state: RoundState = RoundState.new(deal, HOLDER, table)
		_lead(round_state, "K", VILLAGER)
		var moves: Array[Pattern] = round_state.legal_moves()
		assert_bool(_has_single(moves, Ranks.KING)).override_failure_message(label).is_false()
		assert_bool(_has_single(moves, Ranks.ACE)).override_failure_message(label).is_true()
		table = _rehab_then_promotion(order)
		deal = RoundScript.stacked_deal(["3Q", "27", "88"], "")
		round_state = RoundState.new(deal, VILLAGER, table)
		_lead(round_state, "2", HOLDER)
		moves = round_state.legal_moves()
		assert_bool(_has_single(moves, Ranks.THREE)).override_failure_message(label).is_true()
		assert_bool(_has_single(moves, Ranks.QUEEN)).override_failure_message(label).is_false()


## Every rank-moving Cadre at once, two of each, with one or both order reversals among
## them (Cultural Revolution after a bomb and the Inverted Order debuff), in many slot
## orders and on both sides of a bomb: the 2 and the jokers stay on their printed
## standings, any rank on a printed standing is on its own (or its own turned over), and
## standings keep the seat's order. Moved ranks pile into one gap here, so a gap that
## overflowed would show, and a turn that left the scale would break the order.
func test_every_rank_mover_at_once_stays_inside_its_gaps() -> void:
	var ids: Array[String] = [
		PROMOTION,
		REHABILITATION,
		CLASS_LABEL,
		REVOLUTION,
		PROMOTION,
		REHABILITATION,
		CLASS_LABEL,
		INVERTED,
	]
	var picks: Array[Vector2i] = [
		Vector2i(Ranks.FIVE, 2), Vector2i(Ranks.THREE, 9), Vector2i(Ranks.FOUR, 0)
	]
	for turn: int in ids.size() * 6:
		var stack: ModifierStack = ModifierStack.new()
		var rehabs: int = turn
		for index: int in ids.size():
			var id: String = ids[(index * (turn % 7 + 1) + turn) % ids.size()]
			# Every third turn holds one reversal, the rest both.
			if turn % 3 == 0 and id == (REVOLUTION if turn % 2 == 0 else INVERTED):
				continue
			var memo: CadreMemo = null
			if id == REHABILITATION:
				memo = _memo(picks[rehabs % picks.size()])
				rehabs += 1
			stack.add(_def(id), HOLDER, memo)
		var table: SeatRules = SeatRules.new(stack)
		table.start_round(HOLDER)
		table.set_stamped(HOLDER, 0xFFF)
		table.refresh()
		for bombed: bool in [false, true]:
			_assert_gaps_hold(table, bombed, "turn %d bombed %s" % [turn, bombed])


func _assert_gaps_hold(table: SeatRules, bombed: bool, name: String) -> void:
	var standing: PackedByteArray = table.standing_in(HOLDER, bombed)
	var order: PackedByteArray = table.map_in(HOLDER, bombed)
	var turned: PackedByteArray = Standing.identity()
	ReversedRanks.reverse(turned, Standing.STEP)
	for rank: int in Ranks.COUNT:
		var label: String = "%s rank %d: %s" % [name, rank, Array(standing)]
		var own: Array[int] = [Standing.identity()[rank], turned[rank]]
		if standing[rank] % Standing.STEP == 0:
			assert_bool(own.has(standing[rank])).override_failure_message(label).is_true()
		elif rank >= Ranks.TWO:
			fail(label)
		for other: int in Ranks.COUNT:
			(
				assert_int(signi(standing[rank] - standing[other]))
				. override_failure_message(label)
				. is_equal(signi(order[rank] - order[other]))
			)


## Cultural Revolution turns the order over after a bomb, Rehabilitation then lifts its 4
## past the turned-over 3 into the gap above the top standing, and Inverted Order turns it
## back: the 4 must end up lowest in standings as in the seat's order, inside the scale.
func test_a_rank_above_the_top_turns_over_to_below_the_bottom() -> void:
	var stack: ModifierStack = ModifierStack.new()
	stack.add(_def(REVOLUTION), HOLDER)
	stack.add(_def(REHABILITATION), HOLDER, _memo(Vector2i(Ranks.FOUR, 0)))
	stack.add(_def(INVERTED), HOLDER)
	var table: SeatRules = SeatRules.new(stack)
	table.start_round(HOLDER)
	table.set_trick_bombed(true)
	var order: PackedByteArray = table.map_in(HOLDER, true)
	var standing: PackedByteArray = table.standing_in(HOLDER, true)
	for rank: int in Ranks.COUNT:
		if rank != Ranks.FOUR:
			assert_int(order[Ranks.FOUR]).is_less(order[rank])
			assert_int(standing[Ranks.FOUR]).is_less(standing[rank])
	_assert_gaps_hold(table, true, "climb")
	# Every rank but the 4 stands level with a villager's same rank.
	for rank: int in Ranks.COUNT:
		if rank != Ranks.FOUR:
			assert_int(standing[rank]).is_equal(table.standing_in(VILLAGER, true)[rank])
