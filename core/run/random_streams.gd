class_name RandomStreams
extends RefCounted
## The run's independent random streams. Each seed derives from the run seed and the
## stream's name by a stable hash, so a new stream never disturbs the others.

## The stream that deals and shuffles the cards.
const DEAL: String = "deal"
## The stream the shops draw their offers on.
const SHOP: String = "shop"
## The stream that draws the debuff ladders.
const DEBUFF: String = "debuff"
## The stream the bots draw on.
const AI: String = "ai"
## The stream for the village's draws, such as seating and arrivals.
const EVENTS: String = "events"
## The stream for draws that change how the game looks or sounds and no play.
const COSMETIC: String = "cosmetic"
## Need audits, apart from ai so a check never shifts a bot's draws.
const AUDIT: String = "audit"
## Given names (ADR 0028), apart from events so naming a run moves no other draw.
const NAMING: String = "names"
## Every stream's name; each is made with the run and saved with it.
const NAMES: PackedStringArray = [DEAL, SHOP, DEBUFF, AI, EVENTS, COSMETIC, AUDIT, NAMING]

## FNV-1a's 64-bit starting hash, as a signed integer.
const FNV_OFFSET_BASIS: int = -3750763034362895579
## FNV-1a's 64-bit multiplier.
const FNV_PRIME: int = 1099511628211

var _run_seed: int
var _streams: Dictionary[String, RandomStream] = {}


func _init(run_seed: int) -> void:
	_run_seed = run_seed
	for stream_name: String in NAMES:
		_streams[stream_name] = RandomStream.new(derive_seed(run_seed, stream_name))


## Rebuilds the streams from the run save, each at the state it was saved in.
static func from_dict(data: Dictionary) -> RandomStreams:
	var streams: RandomStreams = RandomStreams.new(str(data["run_seed"]).to_int())
	var states: Dictionary = data["states"]
	# A stream added after the save starts fresh from its derived seed.
	for stream_name: String in NAMES:
		if states.has(stream_name):
			streams.stream(stream_name).load_state(str(states[stream_name]))
	return streams


## The seed of the named stream for a run seed, by a stable hash.
static func derive_seed(run_seed: int, stream_name: String) -> int:
	return stable_hash(("%d:%s" % [run_seed, stream_name]).to_utf8_buffer())


## FNV-1a, 64-bit. String.hash() is not a documented stable format, and saves outlive engines.
static func stable_hash(bytes: PackedByteArray) -> int:
	var hash_value: int = FNV_OFFSET_BASIS
	for byte: int in bytes:
		hash_value = (hash_value ^ byte) * FNV_PRIME
	return hash_value


## The named stream, which must be one of NAMES.
func stream(stream_name: String) -> RandomStream:
	return _streams[stream_name]


## The seed is text for the same reason stream states are.
func to_dict() -> Dictionary:
	var states: Dictionary[String, String] = {}
	for stream_name: String in NAMES:
		states[stream_name] = _streams[stream_name].save_state()
	return {"run_seed": str(_run_seed), "states": states}
