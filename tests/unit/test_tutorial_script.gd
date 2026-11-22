extends GdUnitTestSuite
## The arrival's authored data (ADR 0026): each round deals 54 different valid cards in
## hands of 17 and a kitty of 3; the player holds exactly the hands the ADR lists; every
## play step names cards the player holds; every villager's play uses its own cards; the
## Quota cannot be met in two rounds, draws no debuff, and the counters hold what the
## script puts there.

## The player's ranks per round, as the ADR lists them: round 2 with the kitty.
const HANDS: Array[Array] = [
	["9", "10", "J", "Q", "K", "A", "5", "5", "3", "3", "3", "3", "4", "4", "4", "6", "6"],
	[
		"3",
		"4",
		"5",
		"6",
		"7",
		"8",
		"9",
		"8",
		"9",
		"10",
		"J",
		"Q",
		"K",
		"A",
		"2",
		"2",
		"2",
		"4",
		"4",
		"5",
	],
]
const RANK_NAMES: Array[String] = [
	"3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A", "2", "SJ", "BJ"
]
const SCRIPT: TutorialScript = preload("res://data/run/tutorial/arrival.tres")


func _ranks(ids: Array) -> Array[String]:
	var names: Array[String] = []
	for card_id: int in ids:
		names.append(RANK_NAMES[Deck.rank_of(card_id)])
	names.sort()
	return names


func _sorted(names: Array) -> Array[String]:
	var copy: Array[String] = []
	copy.assign(names)
	copy.sort()
	return copy


func test_each_deal_is_54_different_valid_cards() -> void:
	assert_int(SCRIPT.rounds.size()).is_equal(2)
	for authored: TutorialRound in SCRIPT.rounds:
		var deal: Array = Array(authored.deal)
		assert_int(deal.size()).is_equal(Deck.SIZE)
		var seen: Dictionary[int, bool] = {}
		for card_id: int in deal:
			assert_bool(card_id >= 0 and card_id < Deck.SIZE).is_true()
			seen[card_id] = true
		assert_int(seen.size()).is_equal(Deck.SIZE)
		var cards: Array[CardInstance] = []
		for card_id: int in deal:
			cards.append(CardInstance.from_deck_id(card_id))
		var dealt: DealResult = Dealer.deal_in_order(cards)
		for hand: Hand in dealt.hands:
			assert_int(hand.cards().size()).is_equal(Dealer.HAND_SIZE)
		assert_int(dealt.kitty.size()).is_equal(Dealer.KITTY_SIZE)
		assert_int(authored.seats.size()).is_equal(Seats.COUNT)


func test_the_player_holds_the_hands_the_adr_lists() -> void:
	var first: Array = Array(SCRIPT.rounds[0].deal).slice(0, Dealer.HAND_SIZE)
	assert_array(_ranks(first)).is_equal(_sorted(HANDS[0]))
	var second: Array = Array(SCRIPT.rounds[1].deal)
	var with_kitty: Array = second.slice(0, Dealer.HAND_SIZE) + second.slice(Seats.COUNT * 17)
	assert_array(_ranks(with_kitty)).is_equal(_sorted(HANDS[1]))


## Each play step plays cards the player holds that round, and each card once.
func test_play_steps_use_the_players_cards_once() -> void:
	var held: Array = Array(SCRIPT.rounds[0].deal).slice(0, Dealer.HAND_SIZE)
	var second: Array = Array(SCRIPT.rounds[1].deal)
	var later: Array = second.slice(0, Dealer.HAND_SIZE) + second.slice(Seats.COUNT * 17)
	var played: Array[int] = []
	for step: TutorialStep in SCRIPT.steps:
		if step.id == "11":
			held = later
			played.clear()
		for card_id: int in step.cards:
			assert_bool(held.has(card_id)).override_failure_message(step.id).is_true()
			assert_bool(played.has(card_id)).override_failure_message(step.id).is_false()
			played.append(card_id)
	assert_int(played.size()).is_equal(20)


## A villager only ever plays its own dealt cards (the landlord's kitty included).
func test_villagers_play_their_own_cards() -> void:
	var landlords: Array[int] = [2, 0]
	for index: int in SCRIPT.rounds.size():
		var authored: TutorialRound = SCRIPT.rounds[index]
		var deal: Array = Array(authored.deal)
		for seat: int in range(1, Seats.COUNT):
			var own: Array = deal.slice(seat * Dealer.HAND_SIZE, (seat + 1) * Dealer.HAND_SIZE)
			if landlords[index] == seat:
				own += deal.slice(Seats.COUNT * Dealer.HAND_SIZE)
			for play: PackedInt32Array in authored.seats[seat].plays:
				for card_id: int in play:
					assert_bool(own.has(card_id)).is_true()


func test_the_quota_cannot_be_met_and_draws_no_debuff() -> void:
	var sets: SetConfig = SetConfig.new(SCRIPT.sets)
	assert_int(sets.max_rounds()).is_equal(2)
	# A figure a player can read, more than twice what the authored plays score (about
	# 2.8K); test_tutorial_run plays it through to the missed Quota.
	assert_float(sets.target(1, RunState.SetType.SMALL)).is_equal(6000.0)
	var stream: RandomStream = RandomStreams.new(SCRIPT.seed_value).stream(RandomStreams.DEBUFF)
	var ladder: Array[String] = DebuffLadder.draw(
		RunLoop.DEFAULT_POOL.debuffs, RunState.SetType.SMALL, 2, stream, SCRIPT.ladder
	)
	assert_array(ladder).is_equal([RunState.NO_DEBUFF, RunState.NO_DEBUFF])
	assert_int(SCRIPT.starting_coupons).is_equal(10)
	assert_int(SCRIPT.steps.size()).is_equal(20)
	assert_str(SCRIPT.store_cadre).is_equal("iron_rice_bowl")
