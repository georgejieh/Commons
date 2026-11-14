extends GdUnitTestSuite
## P4.2: Resentment rises from its three sources, reaches Denunciation through one data
## curve, and becomes every bot's grudge against the player.

const PARAMS: ResentmentParams = preload("res://data/run/resentment.tres")

var _state: RunState
var _events: Array[RunEvent] = []


func before_test() -> void:
	_state = RunState.new(42)
	_events.clear()


func test_a_private_purchase_adds_its_amount() -> void:
	Resentment.add(_state, PARAMS.private_purchase, Resentment.PRIVATE_PURCHASE, PARAMS, _events)
	assert_int(_state.resentment).is_equal(PARAMS.private_purchase)
	assert_int(_events[0].type).is_equal(RunEvent.Type.RESENTMENT)
	assert_str(_events[0].text).is_equal(Resentment.PRIVATE_PURCHASE)


func test_only_private_cadres_count() -> void:
	var pool: Array[ModifierDef] = RunLoop.all_cadres()
	var held: Array[String] = []
	var private: int = 0
	for definition: ModifierDef in pool:
		held.append(definition.id)
		if definition.tag == ModifierDef.Tag.PRIVATE:
			private += 1
	assert_int(private).is_greater(0)
	assert_int(Resentment.private_cadres(held, pool)).is_equal(private)
	assert_int(Resentment.private_cadres([], pool)).is_equal(0)


func test_only_the_players_own_stamps_count() -> void:
	var cards: Array[CardInstance] = []
	for deck_id: int in 4:
		cards.append(CardInstance.from_deck_id(deck_id))
	CardModifiers.stamp(cards[0], 0)
	CardModifiers.stamp(cards[1], 0)
	CardModifiers.stamp(cards[2], 1)
	assert_int(Resentment.stamped(cards, 0)).is_equal(2)


func test_resentment_clamps_to_its_range() -> void:
	Resentment.add(_state, PARAMS.max * 3, Resentment.PRIVATE_PURCHASE, PARAMS, _events)
	assert_int(_state.resentment).is_equal(PARAMS.max)
	Resentment.add(_state, -PARAMS.max * 3, Resentment.PRIVATE_PURCHASE, PARAMS, _events)
	assert_int(_state.resentment).is_equal(0)


func test_denunciation_follows_the_single_curve() -> void:
	var last: int = 0
	for resentment: int in range(0, PARAMS.max + 1):
		var owed: int = Resentment.denunciation(resentment, PARAMS)
		var sampled: float = PARAMS.denunciation.sample(float(resentment) / PARAMS.max)
		assert_int(owed).is_equal(roundi(sampled))
		assert_int(owed).is_greater_equal(last)
		last = owed
	assert_int(Resentment.denunciation(0, PARAMS)).is_equal(0)
	assert_int(last).is_greater(0)


func test_grudge_rises_with_resentment() -> void:
	assert_float(Resentment.grudge(0, PARAMS)).is_equal(0.0)
	assert_float(Resentment.grudge(PARAMS.max, PARAMS)).is_equal(PARAMS.grudge_at_max)
