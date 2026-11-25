class_name UnseenCards
extends RefCounted
## Counts what a seat has not seen: the round's cards as the seat knows them less its own
## hand and every card played. The kitty counts as unseen until played, because it went
## into the landlord's hand. Another seat's plot card is a card the seat could not know
## of, so a rank it has seen more of than it knew stays at none unseen.


static func from_view(view: SeatView) -> PackedByteArray:
	var seen: PackedByteArray = view.own_counts.duplicate()
	for play: PublicPlay in view.public.history:
		if play.pattern.type != Pattern.Type.PASS:
			for rank: int in Ranks.COUNT:
				seen[rank] += play.counts[rank]
	var unseen: PackedByteArray = PackedByteArray()
	unseen.resize(Ranks.COUNT)
	for rank: int in Ranks.COUNT:
		unseen[rank] = maxi(0, view.deck_counts[rank] - seen[rank])
	return unseen


static func mask_of(counts: PackedByteArray) -> int:
	var mask: int = 0
	for rank: int in Ranks.COUNT:
		if counts[rank] > 0:
			mask |= 1 << rank
	return mask
