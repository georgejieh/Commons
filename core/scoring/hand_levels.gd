class_name HandLevels
extends RefCounted
## Each hand type's current level. Directives raise them.

const FIRST_LEVEL: int = 1

var _levels: PackedByteArray = PackedByteArray()
var _max_level: int


func _init(max_level: int) -> void:
	_max_level = max_level
	_levels.resize(Pattern.Type.size())
	_levels.fill(FIRST_LEVEL)


func level_of(type: Pattern.Type) -> int:
	return _levels[type]


func raise(type: Pattern.Type) -> void:
	_levels[type] = mini(_levels[type] + 1, _max_level)
