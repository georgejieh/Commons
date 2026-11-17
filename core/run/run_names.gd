class_name RunNames
extends RefCounted
## Who is who in a run (ADR 0028): a given name for the player and for every family of
## the roster, drawn as the run starts, and one for each sent-down youth as they arrive.
## Names come from the generation's era pool on the run's own names stream, so naming
## moves no other draw. A run never holds a given name twice, never a blocked one, and
## never one that with its holder's surname is a blocked pair; a pool that runs dry
## hands on to the next. Surnames are compared as they read, so the caller passes each
## surname key's text; the run keeps the youth surnames' for later arrivals. A run that
## names nobody, the demo or the arrival, keeps only the player's surname.

const BOOK: NameBook = preload("res://data/villagers/names.tres")
## The player's entry among the given names.
const PLAYER: String = "player"

## False for a run that names nobody new.
var active: bool = false
## The generation whose pool names this run, from 1; 0 names it as the first.
var generation: int = 0
## The player's family name as it reads.
var player_surname: String = ""
## Given names by family ID, and the player's under PLAYER.
var given: Dictionary[String, String] = {}
## The text of each youth surname key, for those who arrive later.
var youth_texts: Dictionary[String, String] = {}


## Names a new run: the player first, then every family of the roster in order. texts
## gives each surname key's text; a key it lacks reads as itself.
static func start(
	state: RunState,
	village: VillageBook,
	surname: String,
	generation_in: int,
	texts: Dictionary[String, String],
	book: NameBook = BOOK
) -> void:
	var names: RunNames = RunNames.new()
	names.active = true
	names.generation = generation_in
	names.player_surname = surname
	for key: String in village.youth_surnames:
		names.youth_texts[key] = texts.get(key, key)
	state.names = names
	var stream: RandomStream = state.streams.stream(RandomStreams.NAMING)
	names.given[PLAYER] = names._draw(stream, surname, book)
	for entry: RosterEntry in state.roster:
		var key: String = Roster.name_key(village, entry)
		names.given[entry.family_id] = names._draw(stream, texts.get(key, key), book)


## The player's given name in a run of this seed and generation, before it starts: the
## first draw start() makes.
static func player_given(
	run_seed: int, generation_in: int, surname: String, book: NameBook = BOOK
) -> String:
	var stream: RandomStream = RandomStream.new(
		RandomStreams.derive_seed(run_seed, RandomStreams.NAMING)
	)
	var names: RunNames = RunNames.new()
	names.generation = generation_in
	return names._draw(stream, surname, book)


## A youth has arrived: they get a given name of their own.
static func name_arrival(state: RunState, entry: RosterEntry, book: NameBook = BOOK) -> void:
	var names: RunNames = state.names
	if not names.active:
		return
	var surname: String = names.youth_texts.get(entry.name_key, entry.name_key)
	var stream: RandomStream = state.streams.stream(RandomStreams.NAMING)
	names.given[entry.family_id] = names._draw(stream, surname, book)


## Names a full run saved before names were (schema 14) from its seed and generation, as
## start() would have, then its youth in the order they arrived, under the fallback
## surname, the only one a profile could hold then. Writes the names, and the names
## stream's state, into the checkpoint; a damaged one is left unnamed for the validator.
static func name_saved(
	checkpoint: Dictionary,
	village: VillageBook,
	texts: Dictionary[String, String],
	book: NameBook = BOOK
) -> void:
	var names: RunNames = RunNames.new()
	checkpoint["names"] = names.to_dict()
	var roster: Variant = checkpoint.get("roster")
	var streams: Variant = checkpoint.get("streams")
	if not RunIdentity.is_valid(checkpoint.get("identity")) or not roster is Array:
		return
	if not streams is Dictionary:
		return
	var saved: Dictionary = streams
	if not saved.get("states") is Dictionary:
		return
	var identity: RunIdentity = RunIdentity.from_dict(checkpoint["identity"])
	if not identity.is_full():
		return
	names.active = true
	names.player_surname = book.fallback_surname
	names.generation = identity.generation
	for key: String in village.youth_surnames:
		names.youth_texts[key] = texts.get(key, key)
	var run_seed: int = str(checkpoint.get("seed", "0")).to_int()
	var stream: RandomStream = RandomStream.new(
		RandomStreams.derive_seed(run_seed, RandomStreams.NAMING)
	)
	names.given[PLAYER] = names._draw(stream, names.player_surname, book)
	for found: Variant in roster:
		if not found is Dictionary:
			return
		var entry: Dictionary = found
		if not entry.get("family_id") is String:
			return
		var key: String = str(entry.get("name_key", ""))
		var family: FamilyDef = village.family(entry["family_id"])
		if key.is_empty() and family != null:
			key = family.name_key
		names.given[entry["family_id"]] = names._draw(stream, texts.get(key, key), book)
	var states: Dictionary = saved["states"]
	states[RandomStreams.NAMING] = stream.save_state()
	checkpoint["names"] = names.to_dict()


## True when a youth surname key reads as the player's surname, letter case aside: a
## youth never shares the player's.
func shares_player_surname(key: String) -> bool:
	if player_surname.is_empty():
		return false
	var text: String = youth_texts.get(key, key)
	return text.to_lower() == player_surname.to_lower()


## The family's given name, or "" for one the run has not named.
func given_name(family_id: String) -> String:
	return given.get(family_id, "")


func player_given_name() -> String:
	return given_name(PLAYER)


## A pool name nobody in the run holds and that is not blocked with surname, from the
## generation's pool, or the next pool's when it has none left; "" if every pool is dry.
func _draw(stream: RandomStream, surname: String, book: NameBook) -> String:
	var held: Array[String] = []
	held.assign(given.values())
	var first: int = book.pool_index(generation)
	for step: int in book.pools.size():
		var pool: NamePool = book.pools[(first + step) % book.pools.size()]
		var open: Array[String] = []
		for candidate: String in pool.names:
			if not held.has(candidate) and not book.blocked(surname, candidate):
				open.append(candidate)
		if not open.is_empty():
			return open[stream.next_int(0, open.size() - 1)]
	return ""


static func from_dict(data: Dictionary) -> RunNames:
	var names: RunNames = RunNames.new()
	names.active = bool(data["active"])
	names.generation = int(data["generation"])
	names.player_surname = str(data["player_surname"])
	for key: String in data["given"]:
		names.given[key] = str(data["given"][key])
	for key: String in data["youth_texts"]:
		names.youth_texts[key] = str(data["youth_texts"][key])
	return names


func to_dict() -> Dictionary:
	return {
		"active": active,
		"generation": generation,
		"player_surname": player_surname,
		"given": given.duplicate(),
		"youth_texts": youth_texts.duplicate(),
	}


## True when value holds every field with the right kind of value.
static func is_valid(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var data: Dictionary = value
	if not data.get("active") is bool or not data.get("player_surname") is String:
		return false
	var number: Variant = data.get("generation")
	if not (number is int or number is float) or number < 0 or number != floorf(number):
		return false
	return _texts_valid(data.get("given")) and _texts_valid(data.get("youth_texts"))


## A map of strings to strings.
static func _texts_valid(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var map: Dictionary = value
	for key: Variant in map:
		if not key is String or not map[key] is String:
			return false
	return true
