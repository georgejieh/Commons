extends RefCounted
## Fixture: reaches a global class outside core.


func scan_core() -> PackedStringArray:
	return LayerCheck.scan("res://core")
