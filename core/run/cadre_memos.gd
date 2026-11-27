class_name CadreMemos
extends RefCounted
## Every held Cadre's own run state, by Cadre ID (ADR 0021). An entry is made the first
## time a Cadre's state is asked for, and dropped when the Cadre is lost, so a Cadre
## bought again starts fresh.

var _entries: Dictionary[String, CadreMemo] = {}


## Rebuilds the memos from the run save; data must pass is_valid.
static func from_dict(data: Dictionary) -> CadreMemos:
	var memos: CadreMemos = CadreMemos.new()
	for cadre_id: Variant in data:
		memos._entries[str(cadre_id)] = CadreMemo.from_dict(data[cadre_id])
	return memos


## True when data has the saved shape: a map of Cadre IDs to memos.
static func is_valid(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var data: Dictionary = value
	for cadre_id: Variant in data:
		if not cadre_id is String or not CadreMemo.is_valid(data[cadre_id]):
			return false
	return true


## The memos as a map of Cadre IDs to saved memos, for the run save.
func to_dict() -> Dictionary:
	var data: Dictionary[String, Dictionary] = {}
	for cadre_id: String in _entries:
		data[cadre_id] = _entries[cadre_id].to_dict()
	return data


## The Cadre's state, made empty the first time it is asked for.
func entry(cadre_id: String) -> CadreMemo:
	if not _entries.has(cadre_id):
		_entries[cadre_id] = CadreMemo.new()
	return _entries[cadre_id]


## True when the Cadre has a state entry; unlike entry(), it makes none.
func has(cadre_id: String) -> bool:
	return _entries.has(cadre_id)


## A copy of the Cadre's state, empty when it has none, for views.
func peek(cadre_id: String) -> CadreMemo:
	return _entries[cadre_id].copy() if _entries.has(cadre_id) else CadreMemo.new()


## The IDs of every Cadre with a state entry.
func ids() -> Array[String]:
	var result: Array[String] = []
	result.assign(_entries.keys())
	return result


## Starts a Cadre's state again, as when it is bought.
func reset(cadre_id: String) -> CadreMemo:
	_entries.erase(cadre_id)
	return entry(cadre_id)


## Drops the state of every Cadre no longer held: one exchanged at reeducation or
## destroyed by a boss.
func keep_only(held: Array[String]) -> void:
	for cadre_id: String in ids():
		if not held.has(cadre_id):
			_entries.erase(cadre_id)


## A Year has ended: every held Cadre has been held one Year longer.
func new_year(held: Array[String]) -> void:
	for cadre_id: String in held:
		entry(cadre_id).add(CadreMemo.YEARS, 1)
