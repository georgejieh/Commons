class_name RandomStreams
extends RefCounted
## The run's independent random streams. Each seed derives from the run seed and the
## stream's name by a stable hash, so a new stream never disturbs the others.

const DEAL: String = "deal"
const SHOP: String = "shop"
const DEBUFF: String = "debuff"
const AI: String = "ai"
const EVENTS: String = "events"
const COSMETIC: String = "cosmetic"
const NAMES: PackedStringArray = [DEAL, SHOP, DEBUFF, AI, EVENTS, COSMETIC]

const FNV_OFFSET_BASIS: int = -3750763034362895579
const FNV_PRIME: int = 1099511628211

var _run_seed: int
var _streams: Dictionary[String, RandomStream] = {}


func _init(run_seed: int) -> void:
	_run_seed = run_seed
	for stream_name: String in NAMES:
		_streams[stream_name] = RandomStream.new(derive_seed(run_seed, stream_name))


static func from_dict(data: Dictionary) -> RandomStreams:
	var streams: RandomStreams = RandomStreams.new(str(data["run_seed"]).to_int())
	var states: Dictionary = data["states"]
	for stream_name: String in NAMES:
		streams.stream(stream_name).load_state(str(states[stream_name]))
	return streams


static func derive_seed(run_seed: int, stream_name: String) -> int:
	return stable_hash(("%d:%s" % [run_seed, stream_name]).to_utf8_buffer())


## FNV-1a, 64-bit. String.hash() is not a documented stable format, and saves outlive engines.
static func stable_hash(bytes: PackedByteArray) -> int:
	var hash_value: int = FNV_OFFSET_BASIS
	for byte: int in bytes:
		hash_value = (hash_value ^ byte) * FNV_PRIME
	return hash_value


func stream(stream_name: String) -> RandomStream:
	return _streams[stream_name]


## The seed is text for the same reason stream states are.
func to_dict() -> Dictionary:
	var states: Dictionary[String, String] = {}
	for stream_name: String in NAMES:
		states[stream_name] = _streams[stream_name].save_state()
	return {"run_seed": str(_run_seed), "states": states}
