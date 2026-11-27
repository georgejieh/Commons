class_name ContentStamp
extends RefCounted
## What a run save was written against (ADR 0033): the game's version and a fingerprint
## of everything a run draws by slot. A save is a checkpoint and the commands since, and
## a command names a shelf's slot, so it replays truly only against the pools it was
## made with. The stamp is kept beside the save under its seal. A save whose stamp is
## not this build's, or that has none, resumes at its checkpoint, the start of its Quota,
## with the commands since left out.

## The stamp's key in a save's extras.
const KEY: String = "content"
## The project setting that holds the game's version.
const VERSION_SETTING: String = "application/config/version"
## Kinds of value a definition's fingerprint reads: plain ones, the same on every launch.
const PLAIN: Array[int] = [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME]

static var _current: String = ""


## This build's stamp.
static func current() -> String:
	if _current.is_empty():
		var version: String = str(ProjectSettings.get_setting(VERSION_SETTING, ""))
		_current = of(drawn(), version)
	return _current


## Everything a run draws from, in a fixed order: the pools' definitions, the bosses
## and their pool's numbers (ADR 0043), the village and every family it seats with its
## personality and trait shifts, then the numbers that size each shelf and the ladder.
static func drawn() -> Array[Resource]:
	var found: Array[Resource] = []
	found.append_array(RunPools.STORE_CADRES.cadres)
	found.append_array(RunPools.MARKET_CADRES.cadres)
	found.append_array(RunPools.DIRECTIVES.directives)
	found.append_array(RunPools.STORE_CAMPAIGNS.campaigns)
	found.append_array(RunPools.MARKET_CAMPAIGNS.campaigns)
	found.append_array(RunPools.REFORMS.reforms)
	found.append_array(RunPools.DEBUFFS.debuffs)
	found.append_array(RunPools.BOSSES.all())
	found.append(RunPools.BOSSES)
	found.append_array(_village(RunDefaults.VILLAGE))
	found.append_array([RunPools.STORE, RunPools.MARKET, RunPools.LADDER, RunPools.PLOT_CARDS])
	found.append_array([RunPools.DECK_CARDS, RunDefaults.PLOT_UPGRADES, RunDefaults.PARAMS])
	found.append_array(RunPools.STORE.envelopes + RunPools.MARKET.envelopes)
	return found


## The village book and each family and sent-down youth it seats, each with its
## personality and trait shifts, which choose and play the villagers a Quota seats.
static func _village(village: VillageBook) -> Array[Resource]:
	var found: Array[Resource] = [village]
	for family: FamilyDef in village.families + village.youth_templates:
		found.append(family)
		if family.personality != null:
			found.append(family.personality)
		found.append_array(family.shifts)
	return found


## The stamp of these definitions under a version: the version, then a hash of each
## definition's plain values, its dictionaries and its arrays of plain values.
static func of(definitions: Array[Resource], version: String) -> String:
	var lines: PackedStringArray = []
	for definition: Resource in definitions:
		lines.append(_line(definition))
	return "%s:%s" % [version, "\n".join(lines).sha256_text()]


## This build's stamp as a save's extras, for a tool that writes a save itself.
static func extras() -> Dictionary:
	return {KEY: current()}


## True when a save's extras carry this build's stamp.
static func matches(saved: Dictionary) -> bool:
	return str(saved.get(KEY, "")) == current()


## A save's data as it stood at its checkpoint: no commands since, and no decisions written
## for them, so the villagers decide again.
static func at_checkpoint(data: Dictionary) -> Dictionary:
	var kept: Dictionary = data.duplicate()
	kept["commands"] = []
	kept["decisions"] = []
	kept.erase(RunRecord.WRITTEN_KEY)
	return kept


static func _line(definition: Resource) -> String:
	var parts: PackedStringArray = []
	for property: Dictionary in definition.get_property_list():
		if not int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			continue
		var value: Variant = definition.get(str(property["name"]))
		if _is_plain(value):
			parts.append("%s=%s" % [property["name"], var_to_str(value)])
	return ";".join(parts)


## True for a plain value, a dictionary of them, or an array of them: never a Resource,
## whose text would name it by where it sits in memory.
static func _is_plain(value: Variant) -> bool:
	if value is Dictionary:
		var entries: Dictionary = value
		for key: Variant in entries:
			if not PLAIN.has(typeof(key)) or not PLAIN.has(typeof(entries[key])):
				return false
		return true
	if value is Array:
		var items: Array = value
		for item: Variant in items:
			if not PLAIN.has(typeof(item)):
				return false
		return true
	if typeof(value) >= TYPE_PACKED_BYTE_ARRAY:
		return true
	return PLAIN.has(typeof(value))
