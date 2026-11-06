class_name RosterEntry
extends RefCounted
## One family's standing in the village for this run.

enum Status { ACTIVE, DEAD, DEPOSED, REEDUCATION }

var family_id: String
var status: Status = Status.ACTIVE
## Sets left before a family in reeducation returns.
var return_timer: int = 0
## For sent-down youth: the template they play by, and the surname they arrived with.
var template_id: String = ""
var name_key: String = ""
## Sets this family has been seated this run, for rising families.
var sets_seated: int = 0


func _init(id: String) -> void:
	family_id = id


static func from_dict(data: Dictionary) -> RosterEntry:
	var entry: RosterEntry = RosterEntry.new(str(data["family_id"]))
	entry.status = int(data["status"]) as Status
	entry.return_timer = int(data["return_timer"])
	entry.template_id = str(data.get("template_id", ""))
	entry.name_key = str(data.get("name_key", ""))
	entry.sets_seated = int(data.get("sets_seated", 0))
	return entry


func to_dict() -> Dictionary:
	return {
		"family_id": family_id,
		"status": status,
		"return_timer": return_timer,
		"template_id": template_id,
		"name_key": name_key,
		"sets_seated": sets_seated,
	}
