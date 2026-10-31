extends GdUnitTestSuite
## Card instances survive serialization, including through JSON.

const ITERATIONS: int = 10000
const SEED: int = 1101


func test_dictionary_round_trip_is_lossless_for_random_instances() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	var failures: int = 0
	for _i: int in ITERATIONS:
		var data: Dictionary = _random_card(rng).to_dict()
		if CardInstance.from_dict(data).to_dict() != data:
			failures += 1
		var through_json: Variant = JSON.parse_string(JSON.stringify(data))
		if _normalized(CardInstance.from_dict(through_json).to_dict()) != _normalized(data):
			failures += 1
	assert_int(failures).is_equal(0)


func test_base_instances_reuse_deck_ids() -> void:
	for deck_id: int in Deck.generate():
		var card: CardInstance = CardInstance.from_deck_id(deck_id)
		assert_int(card.id).is_equal(deck_id)
		assert_int(card.base_rank).is_equal(Deck.rank_of(deck_id))
		assert_int(card.suit).is_equal(Deck.suit_of(deck_id))
		assert_int(card.origin).is_equal(CardInstance.Origin.DECK)


func test_new_instance_has_no_enhancement_seal_or_stamp() -> void:
	var card: CardInstance = CardInstance.from_deck_id(0)
	assert_str(card.enhancement_id()).is_equal(CardInstance.NO_ID)
	assert_str(card.seal_id()).is_equal(CardInstance.NO_ID)
	assert_int(card.owner_stamp()).is_equal(CardInstance.NO_OWNER)


func _random_card(rng: RandomNumberGenerator) -> CardInstance:
	var from_plot: bool = rng.randi_range(0, 1) == 1
	var card_id: int = rng.randi_range(0, 53)
	var origin: CardInstance.Origin = CardInstance.Origin.DECK
	if from_plot:
		card_id = CardInstance.FIRST_PLOT_ID + rng.randi_range(0, 100000)
		origin = CardInstance.Origin.PLOT
	var card: CardInstance = CardInstance.new(
		card_id, rng.randi_range(0, 14), rng.randi_range(-1, 3), origin
	)
	card.set_enhancement("" if rng.randi_range(0, 1) == 0 else "enh_%d" % rng.randi_range(0, 9))
	card.set_seal("" if rng.randi_range(0, 1) == 0 else "seal_%d" % rng.randi_range(0, 9))
	card.set_owner_stamp(rng.randi_range(-1, 2))
	return card


## JSON numbers come back as floats, so compare as text.
func _normalized(data: Dictionary) -> String:
	return JSON.stringify(data, "", true)
