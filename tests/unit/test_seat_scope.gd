extends GdUnitTestSuite
## ADR 0039: SeatScope, the one place that says whose seat a modifier acts for, and the
## rule it keeps for every Cadre in the pool: none changes what a villager may play or
## what a villager's cards beat, and none pays on a play by the holder's opponents.

const HOLDER: int = 0


func _def(kind: ModifierDef.Kind, tag: ModifierDef.Tag, for_teammate: bool) -> ModifierDef:
	var definition: ModifierDef = ModifierDef.new()
	definition.kind = kind
	definition.tag = tag
	definition.counts_for_teammate = for_teammate
	return definition


func test_reach_follows_how_a_modifier_is_held() -> void:
	var collective: ModifierDef = _def(ModifierDef.Kind.CADRE, ModifierDef.Tag.COLLECTIVE, true)
	var private: ModifierDef = _def(ModifierDef.Kind.CADRE, ModifierDef.Tag.PRIVATE, false)
	var debuff: ModifierDef = _def(ModifierDef.Kind.DEBUFF, ModifierDef.Tag.PRIVATE, false)
	var boss: ModifierDef = _def(ModifierDef.Kind.BOSS_TWIST, ModifierDef.Tag.PRIVATE, false)
	var reform: ModifierDef = _def(ModifierDef.Kind.REFORM, ModifierDef.Tag.COLLECTIVE, false)
	assert_int(SeatScope.rules_reach(collective)).is_equal(SeatScope.Reach.HOLDER)
	assert_int(SeatScope.rules_reach(private)).is_equal(SeatScope.Reach.HOLDER)
	assert_int(SeatScope.score_reach(collective)).is_equal(SeatScope.Reach.SIDE)
	assert_int(SeatScope.score_reach(private)).is_equal(SeatScope.Reach.HOLDER)
	for other: ModifierDef in [debuff, boss, reform]:
		assert_int(SeatScope.rules_reach(other)).is_equal(SeatScope.Reach.TABLE)
		assert_int(SeatScope.score_reach(other)).is_equal(SeatScope.Reach.TABLE)


func test_reaches_the_holder_and_a_peasant_holders_teammate() -> void:
	# reach, seat, landlord, expected; the holder is seat 0.
	var cases: Array[Array] = [
		[SeatScope.Reach.TABLE, 2, 2, true],
		[SeatScope.Reach.HOLDER, 0, 2, true],
		[SeatScope.Reach.HOLDER, 1, 2, false],
		[SeatScope.Reach.SIDE, 0, 0, true],
		[SeatScope.Reach.SIDE, 1, 2, true],
		[SeatScope.Reach.SIDE, 2, 2, false],
		[SeatScope.Reach.SIDE, 1, 0, false],
		[SeatScope.Reach.SIDE, 2, 0, false],
		[SeatScope.Reach.SIDE, 1, Seats.NONE, false],
		[SeatScope.Reach.SIDE, 0, Seats.NONE, true],
	]
	for case: Array in cases:
		var reached: bool = SeatScope.reaches(case[0], HOLDER, case[1], case[2])
		assert_bool(reached).override_failure_message(str(case)).is_equal(case[3])


func test_only_a_collective_scoring_cadre_may_count_for_the_teammate() -> void:
	var keys: Dictionary[String, bool] = {}
	var definition: ModifierDef = ResourceLoader.load("res://data/modifiers/shock_brigade.tres")
	var wrong: ModifierDef = definition.duplicate()
	wrong.counts_for_teammate = true
	var problems: PackedStringArray = ModifierValidator.validate(wrong, keys)
	(
		assert_bool(Array(problems).any(func(line: String) -> bool: return "teammate" in line))
		. is_true()
	)
	var canteen: ModifierDef = ResourceLoader.load("res://data/modifiers/canteen.tres")
	problems = ModifierValidator.validate(canteen, keys)
	(
		assert_bool(Array(problems).any(func(line: String) -> bool: return "teammate" in line))
		. is_false()
	)


## Every Cadre in the pool, held by seat 0, leaves the other seats' rules, orders and
## standings exactly as a table with no modifier has them, on both sides of a bomb, as
## landlord or peasant, whatever the holder's stamps.
func test_no_cadre_changes_a_villagers_rules_or_ranks() -> void:
	var plain: SeatRules = SeatRules.new(ModifierStack.new())
	for cadre: ModifierDef in RunLoop.all_cadres():
		var stack: ModifierStack = ModifierStack.new()
		stack.add(cadre, HOLDER)
		var table: SeatRules = SeatRules.new(stack)
		for landlord: int in [HOLDER, 1]:
			table.start_round(landlord)
			table.set_stamped(HOLDER, 0xFFF)
			for bombed: bool in [false, true]:
				table.set_trick_bombed(bombed)
				table.refresh()
				for seat: int in [1, 2]:
					var name: String = "%s %d %d %s" % [cadre.id, landlord, seat, bombed]
					var same: bool = table.rules_for(seat).same_as(plain.rules_for(seat))
					assert_bool(same).override_failure_message(name).is_true()
					var order: PackedByteArray = table.map_in(seat, bombed)
					(
						assert_bool(order == Ranks.identity_map())
						. override_failure_message(name)
						. is_true()
					)
					var standing: PackedByteArray = table.standing_in(seat, bombed)
					(
						assert_bool(standing == Standing.identity())
						. override_failure_message(name)
						. is_true()
					)


func _card(rank: int, suit: int) -> CardInstance:
	return CardInstance.from_deck_id(rank * Deck.SUITS + suit)


## Plays of many shapes, with Model, stamped and kitty cards among them.
func _plays() -> Array[Array]:
	var model: CardInstance = _card(Ranks.FIVE, 1)
	CardModifiers.enhance(model, CardInstance.MODEL)
	var stamped: CardInstance = _card(Ranks.NINE, 1)
	CardModifiers.stamp(stamped, HOLDER)
	var plays: Array[Array] = [[model], [stamped], [_card(Ranks.TWO, 1)]]
	plays.append([_card(Ranks.SEVEN, 0), _card(Ranks.SEVEN, 1)])
	plays.append([_card(Ranks.EIGHT, 0), _card(Ranks.EIGHT, 1), _card(Ranks.EIGHT, 2)])
	var bomb: Array[CardInstance] = []
	var straight: Array[CardInstance] = []
	for suit: int in Deck.SUITS:
		bomb.append(_card(Ranks.JACK, suit))
	for rank: int in range(Ranks.THREE, Ranks.EIGHT):
		straight.append(_card(rank, 3))
	plays.append(bomb)
	plays.append(straight)
	plays.append([CardInstance.from_deck_id(Deck.SMALL_JOKER_ID)])
	return plays


func _total(stack: ModifierStack, cards: Array, seat: int, landlord: int) -> float:
	var played: Array[CardInstance] = []
	played.assign(cards)
	var pattern: Pattern = (
		CardSelection.classify_cards(played, RuleSet.default_rules(), Ranks.identity_map()).pattern
	)
	var facts: PlayFacts = PlayFacts.new(
		landlord, 0, PackedInt32Array([3, 3, 3]), PackedFloat64Array([30, 40, 50]), 4
	)
	var breakdown: ScoreBreakdown = Scorer.score_play(
		played, pattern, 1, seat, seat == landlord, stack, Scorer.DEFAULT_PARAMS, 3, facts
	)
	return breakdown.total


## Every Cadre in the pool, held by seat 0 with a met Quota and a run's wins behind it,
## scores the holder's opponents' plays exactly as no Cadre would: the landlord's while the
## holder is a peasant, and both peasants' while the holder is landlord.
func test_no_cadre_pays_on_an_opponents_play() -> void:
	var empty: ModifierStack = ModifierStack.new()
	for cadre: ModifierDef in RunLoop.all_cadres():
		var memo: CadreMemo = CadreMemo.new()
		for key: String in ["met", "wins", "bombs", "long_straights"]:
			memo.put(key, 2)
		var stack: ModifierStack = ModifierStack.new()
		stack.add(cadre, HOLDER, memo)
		# seat, landlord
		for at: Vector2i in [Vector2i(2, 2), Vector2i(1, 0), Vector2i(2, 0)]:
			for cards: Array in _plays():
				var name: String = "%s %s %d" % [cadre.id, at, cards.size()]
				var theirs: float = _total(stack, cards, at.x, at.y)
				var plain: float = _total(empty, cards, at.x, at.y)
				assert_float(theirs).override_failure_message(name).is_equal(plain)
