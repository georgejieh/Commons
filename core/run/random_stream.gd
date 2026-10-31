class_name RandomStream
extends RefCounted
## One named random generator. The only script in core allowed to hold an engine generator.

const HALF_BITS: int = 32
const HALF_MASK: int = 0xFFFFFFFF

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(stream_seed: int) -> void:
	_rng.seed = stream_seed


## Returns an integer from low to high inclusive.
func next_int(low: int, high: int) -> int:
	return _rng.randi_range(low, high)


## Returns a float from 0 to 1.
func next_float() -> float:
	return _rng.randf()


## Returns the state as hex text, because JSON numbers cannot hold 64 bits.
func save_state() -> String:
	var state: int = _rng.state
	return "%08x%08x" % [(state >> HALF_BITS) & HALF_MASK, state & HALF_MASK]


func load_state(text: String) -> void:
	var high: int = text.substr(0, 8).hex_to_int()
	var low: int = text.substr(8).hex_to_int()
	_rng.state = (high << HALF_BITS) | low
