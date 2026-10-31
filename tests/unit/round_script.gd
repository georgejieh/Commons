class_name RoundScript
extends RefCounted
## Builds rounds for tests.


## Deals stacked hands from text. Each seat's text picks the next unused deck cards.
static func stacked_deal(seat_texts: Array[String], kitty_text: String) -> DealResult:
	var pool: Array[CardInstance] = []
	for deck_id: int in Deck.generate():
		pool.append(CardInstance.from_deck_id(deck_id))
	var deal: DealResult = DealResult.new()
	for text: String in seat_texts:
		var hand: Hand = Hand.new()
		for card: CardInstance in _take(pool, text):
			hand.add(card)
		deal.hands.append(hand)
	deal.kitty = _take(pool, kitty_text)
	return deal


## Returns the seat's lowest-ID cards for the text, as an action.
static func play(round_state: RoundState, text: String) -> RoundAction:
	var rules: RuleSet = RuleSet.default_rules()
	var map: PackedByteArray = Ranks.identity_map()
	return round_state.action_for(Classifier.classify(RankText.counts(text), rules, map).pattern)


static func _take(pool: Array[CardInstance], text: String) -> Array[CardInstance]:
	var taken: Array[CardInstance] = []
	for symbol: String in text:
		var rank: int = RankText.rank(symbol)
		for index: int in pool.size():
			if pool[index].base_rank() == rank:
				taken.append(pool[index])
				pool.remove_at(index)
				break
	return taken
