class_name UnseenCards
extends RefCounted
## Counts what a seat has not seen: the deck less its own hand and every card played.
## The kitty counts as unseen until played, because it went into the landlord's hand.

const PER_RANK: int = 4
const PER_JOKER: int = 1


static func from_view(view: SeatView) -> PackedByteArray:
	var seen: PackedByteArray = view.own_counts.duplicate()
	for play: PublicPlay in view.public.history:
		if play.pattern.type != Pattern.Type.PASS:
			for rank: int in Ranks.COUNT:
				seen[rank] += play.counts[rank]
	var unseen: PackedByteArray = PackedByteArray()
	unseen.resize(Ranks.COUNT)
	for rank: int in Ranks.COUNT:
		var in_deck: int = PER_JOKER if rank >= Ranks.SMALL_JOKER else PER_RANK
		unseen[rank] = maxi(0, in_deck - seen[rank])
	return unseen


static func mask_of(counts: PackedByteArray) -> int:
	var mask: int = 0
	for rank: int in Ranks.COUNT:
		if counts[rank] > 0:
			mask |= 1 << rank
	return mask
