class_name CardSelection
extends RefCounted
## Turns a pattern into card instances, and player picks back into a pattern. A pattern
## spends printed ranks, which differ from its reading when a wild card stands in.


## Bots take the least valuable instances: plain before enhanced, then lowest ID.
## Returns nothing if the hand can't make the pattern.
static func pick(hand: Hand, pattern: Pattern) -> Array[CardInstance]:
	var needed: PackedByteArray = pattern.spent_counts()
	var cards: Array[CardInstance] = hand.cards()
	cards.sort_custom(_is_less_valuable)
	var chosen: Array[CardInstance] = []
	for card: CardInstance in cards:
		if needed[card.base_rank()] > 0:
			needed[card.base_rank()] -= 1
			chosen.append(card)
	if chosen.size() != pattern.card_count:
		return []
	return chosen


## Validates a player's own selection through the classifier, as printed.
static func classify_cards(
	cards: Array[CardInstance], rules: RuleSet, rank_map: PackedByteArray
) -> Classification:
	return Classifier.classify(printed_counts(cards), rules, rank_map)


## Every legal reading of the cards, strongest first (Readings).
static func readings(
	cards: Array[CardInstance], rules: RuleSet, rank_map: PackedByteArray
) -> Array[Pattern]:
	return Readings.of(printed_counts(cards), rules, rank_map)


static func printed_counts(cards: Array[CardInstance]) -> PackedByteArray:
	var counts: PackedByteArray = PackedByteArray()
	counts.resize(Ranks.COUNT)
	for card: CardInstance in cards:
		counts[card.base_rank()] += 1
	return counts


static func _is_less_valuable(first: CardInstance, second: CardInstance) -> bool:
	var first_plain: bool = _is_plain(first)
	if first_plain != _is_plain(second):
		return first_plain
	return first.id() < second.id()


static func _is_plain(card: CardInstance) -> bool:
	var enhanced: bool = card.enhancement_id() != CardInstance.NO_ID
	var sealed: bool = card.seal_id() != CardInstance.NO_ID
	return not enhanced and not sealed and card.owner_stamp() == CardInstance.NO_OWNER
