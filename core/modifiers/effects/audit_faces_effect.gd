class_name AuditFacesEffect
extends ModifierEffect
## More faces of the audit die mean an audit, for every claim, the holder's too. The
## audit's own cap still holds, so a check is never certain (ADR 0023).

const FACES: String = "faces"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([FACES])


func audit(context: AuditContext) -> void:
	context.faces += parameters[FACES]
