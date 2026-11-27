class_name SteelTargetEffect
extends ModifierEffect
## Each Bomb or Rocket the holder plays adds flat Zeal, given in hundredths, to all the
## holder's later plays for the run, and adds Resentment when the holder is the player.

## Parameter key: the Zeal each Bomb or Rocket played adds, in hundredths.
const ZEAL_PERCENT: String = "zeal_percent"
## Parameter key: the Resentment each one adds when the holder is the player.
const RESENTMENT: String = "resentment"
## Memo key: the Bombs and Rockets the holder has played.
const BOMBS: String = "bombs"


## Needs the Zeal per Bomb and the Resentment.
func required_parameters() -> PackedStringArray:
	return PackedStringArray([ZEAL_PERCENT, RESENTMENT])


## Adds the Zeal the Bombs played so far have earned.
func play_scored(context: PlayContext) -> void:
	context.add_zeal += fraction(_zeal_percent())


## Counts a Bomb or Rocket the holder plays, and adds the Resentment for the player.
func turn_taken(context: TurnContext) -> void:
	if context.seat != holder_seat or not context.is_bomb():
		return
	memo.add(BOMBS, 1)
	memo.fire()
	if context.seat == context.player:
		context.resentment += parameters[RESENTMENT]


## The Zeal and Bombs so far, with the Zeal as its badge.
func state_values() -> Dictionary[String, Variant]:
	var zeal: float = fraction(_zeal_percent())
	return {"zeal": zeal, "bombs": memo.value(BOMBS), "count": zeal}


func _zeal_percent() -> int:
	return parameters[ZEAL_PERCENT] * memo.value(BOMBS)
