class_name SteelTargetEffect
extends ModifierEffect
## Each Bomb or Rocket the holder plays adds flat Zeal, given in hundredths, to all the
## holder's later plays for the run, and adds Resentment when the holder is the player.

const ZEAL_PERCENT: String = "zeal_percent"
const RESENTMENT: String = "resentment"
const BOMBS: String = "bombs"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([ZEAL_PERCENT, RESENTMENT])


func play_scored(context: PlayContext) -> void:
	if context.seat == holder_seat:
		context.add_zeal += _zeal_percent() / 100.0


func turn_taken(context: TurnContext) -> void:
	if context.seat != holder_seat or not context.is_bomb():
		return
	memo.add(BOMBS, 1)
	memo.fire()
	if context.seat == context.player:
		context.resentment += parameters[RESENTMENT]


func state_values() -> Dictionary[String, Variant]:
	var zeal: float = _zeal_percent() / 100.0
	return {"zeal": zeal, "bombs": memo.value(BOMBS), "count": zeal}


func _zeal_percent() -> int:
	return parameters[ZEAL_PERCENT] * memo.value(BOMBS)
