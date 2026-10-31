extends RefCounted
## Fixture: uses randomness outside the stream service.


func roll() -> int:
	return randi_range(1, 6)
