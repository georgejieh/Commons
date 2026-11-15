class_name SeedGrainEffect
extends ModifierEffect
## Every seat's plays gain flat Grain for each Quota met while it is held. The count
## rises at each met Quota's end.

const GRAIN: String = "grain"
const MET: String = "met"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([GRAIN])


func play_scored(context: PlayContext) -> void:
	context.add_grain += _grain()


func set_end(context: SetContext) -> void:
	if context.target_met:
		memo.add(MET, 1)
		memo.fire(parameters[GRAIN])


func state_values() -> Dictionary[String, Variant]:
	return {"grain": _grain(), "met": memo.value(MET), "count": _grain()}


func _grain() -> int:
	return parameters[GRAIN] * memo.value(MET)
