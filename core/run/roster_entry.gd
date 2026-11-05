class_name RosterEntry
extends RefCounted
## One family's standing in the village for this run.

enum Status { ACTIVE, DEAD, DEPOSED, REEDUCATION }

var family_id: String
var status: Status = Status.ACTIVE
## Sets left before a family in reeducation returns.
var return_timer: int = 0


func _init(id: String) -> void:
	family_id = id


static func from_dict(data: Dictionary) -> RosterEntry:
	var entry: RosterEntry = RosterEntry.new(str(data["family_id"]))
	entry.status = int(data["status"]) as Status
	entry.return_timer = int(data["return_timer"])
	return entry


func to_dict() -> Dictionary:
	return {"family_id": family_id, "status": status, "return_timer": return_timer}
