extends RefCounted
## Fixture: reaches randomness or evaluation indirectly.


func mix(cards: Array[int]) -> void:
	Callable.create(cards, "shuffle").call()
