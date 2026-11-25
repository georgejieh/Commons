class_name VillageDrift
extends RefCounted
## How far each family has drifted from its own definition over the generations (ADR
## 0028): for each of its five personality levels an offset in steps, and for its voice
## a shift of its base pitch as a fraction. Each generation from the second, every level
## moves one step with the village's drift chance, up or down evenly, never past LOW or
## HIGH (a move off the end is no move), and the pitch shifts by up to the pitch step
## either way, never more than the pitch limit in all. The draws come from a stream
## seeded by the generation alone, so the same profile always gives the same village.
## The shared definitions are never changed: personality() hands out a copy.

const TRAITS: Array[String] = ["bomb_aggression", "cooperation", "honesty", "ambition", "grudge"]
const STREAM: String = "drift"
const LEVELS_KEY: String = "levels"
const PITCH_KEY: String = "pitch"

## Offsets in steps by family ID, then by trait; a trait not held has not moved.
var levels: Dictionary[String, Dictionary] = {}
## The pitch shift by family ID, as a fraction of its own pitch.
var pitch: Dictionary[String, float] = {}


## The drift after the generation's own: previous, moved by a draw for generation. The
## first generation is the village as it is defined, so it adds nothing.
static func next(previous: VillageDrift, generation: int, village: VillageBook) -> VillageDrift:
	var drift: VillageDrift = VillageDrift.from_dict(previous.to_dict())
	if generation < 2:
		return drift
	var stream: RandomStream = RandomStream.new(RandomStreams.derive_seed(generation, STREAM))
	for family: FamilyDef in village.families:
		drift._move(family, stream, village)
	return drift


## A copy of the family's personality with its drift applied.
func personality(family: FamilyDef) -> Personality:
	var drifted: Personality = family.personality.duplicate() as Personality
	for trait_name: String in TRAITS:
		var level: int = int(drifted.get(trait_name)) + offset(family.id, trait_name)
		drifted.set(trait_name, clampi(level, Personality.Level.LOW, Personality.Level.HIGH))
	return drifted


## The steps a family's trait has moved.
func offset(family_id: String, trait_name: String) -> int:
	var moved: Dictionary = levels.get(family_id, {})
	return int(moved.get(trait_name, 0))


## What the family's own pitch is multiplied by.
func pitch_factor(family_id: String) -> float:
	return 1.0 + pitch.get(family_id, 0.0)


func is_empty() -> bool:
	return levels.is_empty() and pitch.is_empty()


func _move(family: FamilyDef, stream: RandomStream, village: VillageBook) -> void:
	var held: Dictionary = levels.get(family.id, {})
	var moved: Dictionary = held.duplicate()
	for trait_name: String in TRAITS:
		# Both draws every time, so one family's luck never shifts another's.
		var roll: float = stream.next_float()
		var step: int = stream.next_int(0, 1) * 2 - 1
		if roll >= village.drift_chance:
			continue
		var now: int = int(moved.get(trait_name, 0))
		var level: int = int(family.personality.get(trait_name)) + now + step
		if level >= Personality.Level.LOW and level <= Personality.Level.HIGH:
			moved[trait_name] = now + step
	if not moved.is_empty():
		levels[family.id] = moved
	var turn: float = (stream.next_float() * 2.0 - 1.0) * village.pitch_step
	var shift: float = pitch.get(family.id, 0.0) + turn
	pitch[family.id] = clampf(shift, -village.pitch_limit, village.pitch_limit)


static func from_dict(data: Dictionary) -> VillageDrift:
	var drift: VillageDrift = VillageDrift.new()
	for family_id: String in data:
		var row: Dictionary = data[family_id]
		var moved: Dictionary = {}
		for trait_name: String in row[LEVELS_KEY]:
			moved[trait_name] = int(row[LEVELS_KEY][trait_name])
		if not moved.is_empty():
			drift.levels[family_id] = moved
		drift.pitch[family_id] = RunState.float_from_text(str(row[PITCH_KEY]))
	return drift


## Every family that has drifted, its levels and its pitch, the pitch as exact text.
func to_dict() -> Dictionary:
	var data: Dictionary = {}
	var families: Array[String] = []
	families.assign(levels.keys())
	for family_id: String in pitch:
		if not families.has(family_id):
			families.append(family_id)
	for family_id: String in families:
		var moved: Dictionary = levels.get(family_id, {})
		data[family_id] = {
			LEVELS_KEY: moved.duplicate(),
			PITCH_KEY: RunState.float_text(pitch.get(family_id, 0.0)),
		}
	return data


## True when value is a map of families to their levels, each a known trait and a whole
## offset no more than two steps, and their pitch as 16 hex digits.
static func is_valid(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var data: Dictionary = value
	for family_id: Variant in data:
		if not family_id is String or not data[family_id] is Dictionary:
			return false
		var row: Dictionary = data[family_id]
		if not row.get(LEVELS_KEY) is Dictionary or not row.get(PITCH_KEY) is String:
			return false
		var text: String = row[PITCH_KEY]
		if text.length() != 16 or not text.is_valid_hex_number():
			return false
		var moved: Dictionary = row[LEVELS_KEY]
		for trait_name: Variant in moved:
			var steps: Variant = moved[trait_name]
			if not TRAITS.has(trait_name) or not RunState.is_whole(steps):
				return false
			if absf(steps) > Personality.Level.HIGH:
				return false
	return true
