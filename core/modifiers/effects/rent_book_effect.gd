class_name RentBookEffect
extends ModifierEffect
## Each round the holder wins as landlord adds flat Zeal, given in hundredths, to all the
## holder's later plays as landlord for the run, and adds Resentment when the holder is
## the player (ADR 0032). A landlord wins by going out first, so the count is kept on
## the turn that empties the landlord's hand, in the Cadre's memo.

const ZEAL_PERCENT: String = "zeal_percent"
const RESENTMENT: String = "resentment"
const WINS: String = "wins"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([ZEAL_PERCENT, RESENTMENT])


func play_scored(context: PlayContext) -> void:
	if context.is_landlord:
		context.add_zeal += _zeal_percent() / 100.0


func turn_taken(context: TurnContext) -> void:
	if context.seat != holder_seat or context.seat != context.landlord:
		return
	if context.is_pass() or context.cards_left != 0:
		return
	memo.add(WINS, 1)
	memo.fire()
	if context.seat == context.player:
		context.resentment += parameters[RESENTMENT]


func state_values() -> Dictionary[String, Variant]:
	var zeal: float = _zeal_percent() / 100.0
	return {"zeal": zeal, "wins": memo.value(WINS), "count": zeal}


func _zeal_percent() -> int:
	return parameters[ZEAL_PERCENT] * memo.value(WINS)
