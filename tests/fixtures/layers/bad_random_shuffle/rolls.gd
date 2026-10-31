extends RefCounted
## Fixture: uses randomness outside the stream service.


func mix(cards: Array[int]) -> void:
	cards.shuffle()
