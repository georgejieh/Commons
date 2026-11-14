class_name AuditContext
extends RefCounted
## Passed to the audit hook before declared needs are checked (P4.3).

## The chance, from 0 to 1, that each declaration is checked. To edit.
var chance: float


func _init(
	chance_value: float,
) -> void:
	chance = chance_value
