extends RefCounted
## Fixture: follows every layer rule, including allowed data paths.

const CONFIG_PATH: String = "res://data/config.tres"


func roll(stream: RandomStream) -> int:
	return stream.next_int(1, 6)


func random_is_fine_in_comments_and_strings() -> String:
	return "randi() and shuffle() are only words here"  # randf()
