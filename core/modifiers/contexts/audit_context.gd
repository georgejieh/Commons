class_name AuditContext
extends RefCounted
## Passed to the audit hook before declared needs are checked (P4.3).

## How many faces of the audit die mean a check. A hook adds to it. To edit.
var faces: int


func _init(
	faces_value: int,
) -> void:
	faces = faces_value
