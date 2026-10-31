class_name Dealer
extends RefCounted
## Shuffles on the deal stream and deals. Biases use bounded swaps after the shuffle,
## so a deal is always O(n) with no rejection sampling.

const SEATS: int = 3
const HAND_SIZE: int = 17
const KITTY_SIZE: int = 3


static func deal(
	cards: Array[CardInstance], stream: RandomStream, biases: Array[DealBias] = []
) -> DealResult:
	var order: Array[CardInstance] = arrange(cards, stream, biases)
	var result: DealResult = DealResult.new()
	for seat: int in SEATS:
		var hand: Hand = Hand.new()
		for offset: int in HAND_SIZE:
			hand.add(order[seat * HAND_SIZE + offset])
		result.hands.append(hand)
	result.kitty = order.slice(SEATS * HAND_SIZE)
	return result


## Returns the cards in deal order: seat 0's hand, seat 1's, seat 2's, then the kitty.
static func arrange(
	cards: Array[CardInstance], stream: RandomStream, biases: Array[DealBias] = []
) -> Array[CardInstance]:
	var order: Array[CardInstance] = cards.duplicate()
	_fisher_yates(order, stream)
	for bias: DealBias in biases:
		_apply_bias(order, bias, stream)
	return order


static func _fisher_yates(order: Array[CardInstance], stream: RandomStream) -> void:
	for index: int in range(order.size() - 1, 0, -1):
		_swap(order, index, stream.next_int(0, index))


## Moves each outside copy of the rank into the seat with the chance that lifts its
## total odds from q to multiplier × q: q + (1 − q) × p = multiplier × q.
static func _apply_bias(order: Array[CardInstance], bias: DealBias, stream: RandomStream) -> void:
	var first: int = bias.seat * HAND_SIZE
	var chance: float = float(HAND_SIZE) / order.size()
	var swap_chance: float = (bias.multiplier - 1.0) * chance / (1.0 - chance)

	var exchangeable: PackedInt32Array = []
	for index: int in range(first, first + HAND_SIZE):
		if order[index].base_rank != bias.rank:
			exchangeable.append(index)

	for index: int in order.size():
		if exchangeable.is_empty():
			return
		var in_seat: bool = index >= first and index < first + HAND_SIZE
		if in_seat or order[index].base_rank != bias.rank:
			continue
		if stream.next_float() < swap_chance:
			var pick: int = stream.next_int(0, exchangeable.size() - 1)
			_swap(order, index, exchangeable[pick])
			exchangeable[pick] = exchangeable[-1]
			exchangeable.resize(exchangeable.size() - 1)


static func _swap(order: Array[CardInstance], first: int, second: int) -> void:
	var held: CardInstance = order[first]
	order[first] = order[second]
	order[second] = held
