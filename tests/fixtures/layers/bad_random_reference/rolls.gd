extends RefCounted
## Fixture: reaches randomness or evaluation indirectly.


func roll(cards: Array[int]) -> void:
	var draw: Callable = randi
	var mix: Callable = cards.shuffle
	print(draw.call(), mix.call())
