extends RefCounted
## Fixture: uses randomness outside the stream service.


func pick(cards: Array[int]) -> int:
	return cards.pick_random()
