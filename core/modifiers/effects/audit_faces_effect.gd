class_name AuditFacesEffect
extends ModifierEffect
## More faces of the audit die mean an audit, for every claim, the holder's too. The
## audit's own cap still holds, so a check is never certain (ADR 0023).

## Parameter key: the faces added to the audit die's check.
const FACES: String = "faces"


## Needs the faces it adds.
func required_parameters() -> PackedStringArray:
	return PackedStringArray([FACES])


## Adds the faces to the audit.
func audit(context: AuditContext) -> void:
	context.faces += parameters[FACES]
