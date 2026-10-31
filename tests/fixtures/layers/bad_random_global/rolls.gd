extends RefCounted
## Fixture: uses randomness outside the stream service.


func roll() -> void:
	randomize()
	seed(1)
	print(randi(), randf(), randi_range(1, 6), randf_range(0.0, 1.0))
	print(randfn(0.0, 1.0), rand_from_seed(1))
