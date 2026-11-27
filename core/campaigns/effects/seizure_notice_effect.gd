class_name SeizureNoticeEffect
extends CampaignEffect
## Takes the highest card from the opponent holding the most cards and gives them the
## player's lowest. Highest and lowest are by each seat's own rank order, ties by card ID,
## the higher ID for the card taken and the lower for the card given. An opponent is on
## the other side; ties go to the next seat in turn order. A seat with a single card is
## never traded with, so neither hand hands over its last card.

const RESENTMENT: String = "resentment"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([RESENTMENT])


func check(context: CampaignContext) -> Reason:
	var sizes: PackedInt32Array = context.round_state.remaining()
	if sizes[context.player] < 2 or sizes[target(context)] < 2:
		return Reason.HAND_TOO_SMALL
	return Reason.OK


func apply(context: CampaignContext) -> void:
	var seat: int = target(context)
	var taken: CardInstance = _extreme(context, seat, true)
	var given: CardInstance = _extreme(context, context.player, false)
	context.trade(seat, [given.id()], [taken.id()])
	context.resent(parameters[RESENTMENT])


## The opponent with the most cards, the first in turn order after the player on a tie.
static func target(context: CampaignContext) -> int:
	var landlord: int = context.round_state.landlord()
	if landlord != context.player:
		return landlord
	var sizes: PackedInt32Array = context.round_state.remaining()
	var best: int = Seats.NONE
	var seat: int = Seats.next(context.player)
	while seat != context.player:
		if best == Seats.NONE or sizes[seat] > sizes[best]:
			best = seat
		seat = Seats.next(seat)
	return best


## The seat's highest card, or its lowest, by its own rank order.
static func _extreme(context: CampaignContext, seat: int, highest: bool) -> CardInstance:
	var rank_map: PackedByteArray = context.seat_table(seat).rank_map
	var chosen: CardInstance = null
	for card: CardInstance in context.round_state.view_for(seat).own_cards:
		if chosen == null or _ahead(card, chosen, rank_map, highest):
			chosen = card
	return chosen


static func _ahead(
	card: CardInstance, other: CardInstance, rank_map: PackedByteArray, highest: bool
) -> bool:
	var rank: int = rank_map[card.base_rank()]
	var other_rank: int = rank_map[other.base_rank()]
	if rank != other_rank:
		return rank > other_rank if highest else rank < other_rank
	return card.id() > other.id() if highest else card.id() < other.id()
