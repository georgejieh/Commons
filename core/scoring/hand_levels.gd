class_name HandLevels
extends RefCounted
## Each hand type's current level, saved with the run. Directives raise them.

const FIRST_LEVEL: int = 1

var _levels: PackedByteArray = PackedByteArray()
var _max_level: int


func _init(max_level: int) -> void:
	_max_level = max_level
	_levels.resize(Pattern.Type.size())
	_levels.fill(FIRST_LEVEL)


## Levels as saved: one number per Pattern.Type, PASS included. A value out of range is
## brought back inside it, and a missing one starts at the first level.
static func from_array(values: Array, max_level: int) -> HandLevels:
	var levels: HandLevels = HandLevels.new(max_level)
	for type: int in mini(values.size(), Pattern.Type.size()):
		levels._levels[type] = clampi(int(values[type]), FIRST_LEVEL, max_level)
	return levels


func to_array() -> Array[int]:
	var values: Array[int] = []
	for level: int in _levels:
		values.append(level)
	return values


func level_of(type: Pattern.Type) -> int:
	return _levels[type]


func max_level() -> int:
	return _max_level


func is_max(type: Pattern.Type) -> bool:
	return _levels[type] >= _max_level


func raise(type: Pattern.Type) -> void:
	_levels[type] = mini(_levels[type] + 1, _max_level)
