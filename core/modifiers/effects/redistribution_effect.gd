class_name RedistributionEffect
extends ModifierEffect
## Each round, after the kitty and before the plot swap: every seat passes cards drawn at
## random on the deal stream to the seat on its left, all at once (ADR 0023). Seats draw
## in seat order, each from its hand in card ID order.

const CARDS: String = "cards"
const FIRST_SEAT: int = 0


func required_parameters() -> PackedStringArray:
	return PackedStringArray([CARDS])


func round_start(context: RoundContext) -> void:
	if context.round_state == null or context.stream == null:
		return
	# Seat a passes to b, b to c and c to a: two one-for-one trades make the turn.
	var a: int = FIRST_SEAT
	var b: int = Seats.left(a)
	var c: int = Seats.left(b)
	# Every seat draws before a card moves, in seat order: a, then c, then b.
	var from_a: Array[int] = _draw(context, a)
	var from_c: Array[int] = _draw(context, c)
	var from_b: Array[int] = _draw(context, b)
	_trade(context, a, from_a, b, from_b)
	_trade(context, a, from_b, c, from_c)
	context.moves.append(CardPass.new(a, b, from_a))
	context.moves.append(CardPass.new(b, c, from_b))
	context.moves.append(CardPass.new(c, a, from_c))


func _draw(context: RoundContext, seat: int) -> Array[int]:
	var pool: Array[int] = []
	for card: CardInstance in context.round_state.view_for(seat).own_cards:
		pool.append(card.id())
	pool.sort()
	var picked: Array[int] = []
	while picked.size() < parameters[CARDS] and not pool.is_empty():
		picked.append(pool.pop_at(context.stream.next_int(0, pool.size() - 1)))
	return picked


## Trades as RoundContext.trade does, but records no move: the three passes are
## recorded as the table shows them, not as the two trades that make them.
func _trade(
	context: RoundContext, seat_a: int, ids_a: Array[int], seat_b: int, ids_b: Array[int]
) -> void:
	var done: RoundState.Reason = context.round_state.trade(seat_a, ids_a, seat_b, ids_b)
	assert(done == RoundState.Reason.OK, "Redistribution's trade was refused")
