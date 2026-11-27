class_name HandLevels
extends RefCounted
## Each hand type's current level, saved with the run. Directives raise them.

## The level every hand type starts at.
const FIRST_LEVEL: int = 1

var _levels: PackedByteArray = PackedByteArray()
var _max_level: int


func _init(highest: int) -> void:
	_max_level = highest
	_levels.resize(Pattern.Type.size())
	_levels.fill(FIRST_LEVEL)


## Levels as saved: one number per Pattern.Type, PASS included. A value out of range is
## brought back inside it, and a missing one starts at the first level.
static func from_array(values: Array, highest: int) -> HandLevels:
	var levels: HandLevels = HandLevels.new(highest)
	for type: int in mini(values.size(), Pattern.Type.size()):
		levels._levels[type] = clampi(int(values[type]), FIRST_LEVEL, highest)
	return levels


## The levels as saved, one per Pattern.Type, PASS included; from_array reads them back.
func to_array() -> Array[int]:
	var values: Array[int] = []
	for level: int in _levels:
		values.append(level)
	return values


## The type's level now, from FIRST_LEVEL up to max_level().
func level_of(type: Pattern.Type) -> int:
	return _levels[type]


## The highest level a hand type can reach.
func max_level() -> int:
	return _max_level


## True when the type is at max_level() and cannot be raised.
func is_max(type: Pattern.Type) -> bool:
	return _levels[type] >= _max_level


## Raises the type by one level, never past max_level().
func raise(type: Pattern.Type) -> void:
	_levels[type] = mini(_levels[type] + 1, _max_level)
