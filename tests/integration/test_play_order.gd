extends GdUnitTestSuite
## A play lies on the trick as a player reads it, never out of rank order. The run hands a
## play's cards over in the order they were chosen, so the pile lays them by its reading: body
## low to high, each rank together, then kickers, a wild card with the rank it stands for.

const SEED: int = 3
## Any mark that makes a card not plain.
const ENHANCEMENT: String = "gilded"


## The cause: a villager takes plain cards before marked ones, and a plot card's number
## is past every deck card's, so a run holding either reaches the table out of rank order.
func test_a_villagers_run_with_a_marked_card_comes_out_of_rank_order() -> void:
	var hand: Hand = Hand.new()
	var cards: Array[CardInstance] = _cards([0, 1, 4, 5, 8, 9])
	cards[0].set_enhancement(ENHANCEMENT)
	for card: CardInstance in cards:
		hand.add(card)
	var reading: Pattern = _read(cards)
	var picked: Array[CardInstance] = CardSelection.pick(hand, reading)
	assert_array(_ranks(picked)).is_equal([0, 1, 1, 2, 2, 0])
	var order: Array[int] = PlayOrder.arrange(picked, reading)
	assert_array(_ranks(_pick(picked, order))).is_equal([0, 0, 1, 1, 2, 2])


func test_a_pair_run_lies_low_to_high_with_its_pairs_together() -> void:
	var cards: Array[CardInstance] = _cards([8, 0, 5, 9, 1, 4])
	var reading: Pattern = _read(cards)
	assert_int(reading.type).is_equal(Pattern.Type.PAIR_CHAIN)
	assert_array(_ids(_pick(cards, PlayOrder.arrange(cards, reading)))).is_equal([0, 1, 4, 5, 8, 9])


func test_a_plane_lies_body_first_then_its_wings() -> void:
	# Fives and Sixes as trios, with a Three and a King as wings.
	var cards: Array[CardInstance] = _cards([40, 12, 0, 8, 13, 9, 14, 10])
	var reading: Pattern = _read(cards)
	assert_int(reading.type).is_equal(Pattern.Type.AIRPLANE_SINGLES)
	assert_array(_ids(_pick(cards, PlayOrder.arrange(cards, reading)))).is_equal(
		[8, 9, 10, 12, 13, 14, 0, 40]
	)


func test_a_wild_card_lies_with_the_rank_it_stands_for() -> void:
	# Fours and Sixes, one Five, and a Seven standing in for the second Five.
	var cards: Array[CardInstance] = _cards([16, 12, 4, 8, 13, 5])
	var reading: Pattern = Pattern.new(
		Pattern.Type.PAIR_CHAIN, Ranks.FOUR, 3, 6, PackedByteArray(), Ranks.FOUR
	)
	reading.spent = CardSelection.printed_counts(cards)
	assert_array(_ids(_pick(cards, PlayOrder.arrange(cards, reading)))).is_equal(
		[4, 5, 8, 16, 12, 13]
	)


## A seat whose rank order is turned over still reads a run as its printed sequence.
func test_a_changed_rank_order_keeps_the_run_in_sequence() -> void:
	var inverted: PackedByteArray = PackedByteArray()
	for rank: int in Ranks.COUNT:
		inverted.append(Ranks.COUNT - 1 - rank)
	var cards: Array[CardInstance] = _cards([9, 4, 1, 8, 5, 0])
	var counts: PackedByteArray = CardSelection.printed_counts(cards)
	var reading: Pattern = Classifier.classify(counts, RuleSet.default_rules(), inverted).pattern
	assert_object(reading).is_not_null()
	assert_array(_ids(_pick(cards, PlayOrder.arrange(cards, reading)))).is_equal([0, 1, 4, 5, 8, 9])


## The trick itself lays the cards in that order, wherever they fly from.
func test_the_pile_lays_a_play_as_it_reads() -> void:
	AppKit.fresh_saves(self)
	var app: App = AppKit.make(self)
	app.new_run(SEED)
	var table: TableScreen = app.show_screen(ScreenId.TABLE, true)
	await await_idle_frame()
	var pile: TrickPile = table.pile
	var motion: TableMotion = table.motion
	motion.set_still(true)
	var cards: Array[CardInstance] = _cards([8, 0, 5, 9, 1, 4])
	pile.show_play(cards, Vector2.ZERO, [], _read(cards))
	assert_array(pile.top_ids()).is_equal([0, 1, 4, 5, 8, 9])
	var views: Array[CardView] = pile.top_views()
	for index: int in range(1, views.size()):
		assert_float(views[index].position.x).is_greater(views[index - 1].position.x)
	pile.clear()
	motion.set_still(false)
	Saves.run_service().delete()


func _read(cards: Array[CardInstance]) -> Pattern:
	var counts: PackedByteArray = CardSelection.printed_counts(cards)
	return Classifier.classify(counts, RuleSet.default_rules(), Ranks.identity_map()).pattern


func _cards(ids: Array[int]) -> Array[CardInstance]:
	var cards: Array[CardInstance] = []
	for card_id: int in ids:
		cards.append(Deck.new().card(card_id))
	return cards


func _pick(cards: Array[CardInstance], order: Array[int]) -> Array[CardInstance]:
	var picked: Array[CardInstance] = []
	for index: int in order:
		picked.append(cards[index])
	return picked


func _ids(cards: Array[CardInstance]) -> Array[int]:
	var ids: Array[int] = []
	for card: CardInstance in cards:
		ids.append(card.id())
	return ids


func _ranks(cards: Array[CardInstance]) -> Array[int]:
	var ranks: Array[int] = []
	for card: CardInstance in cards:
		ranks.append(card.base_rank())
	return ranks
