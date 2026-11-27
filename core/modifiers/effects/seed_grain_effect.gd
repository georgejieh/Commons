class_name SeedGrainEffect
extends ModifierEffect
## Plays gain flat Grain for each Quota met while it is held, for the holder and the
## holder's teammate (SeatScope, ADR 0039). The count rises at each met Quota's end: the
## player's Quota, whoever sat where.

## Parameter key: the flat Grain each Quota met adds.
const GRAIN: String = "grain"
## Memo key: the Quotas met while it was held.
const MET: String = "met"


## Needs the Grain per Quota met.
func required_parameters() -> PackedStringArray:
	return PackedStringArray([GRAIN])


## Adds the Grain the Quotas met so far have earned.
func play_scored(context: PlayContext) -> void:
	context.add_grain += _grain()


## Counts a met Quota.
func set_end(context: SetContext) -> void:
	if context.target_met:
		memo.add(MET, 1)
		memo.fire(parameters[GRAIN])


## The Grain and Quotas met so far, with the Grain as its badge.
func state_values() -> Dictionary[String, Variant]:
	return {"grain": _grain(), "met": memo.value(MET), "count": _grain()}


func _grain() -> int:
	return parameters[GRAIN] * memo.value(MET)
