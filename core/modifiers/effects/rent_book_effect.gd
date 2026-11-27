class_name RentBookEffect
extends ModifierEffect
## Each round the holder wins as landlord adds flat Zeal, given in hundredths, to all the
## holder's later plays as landlord for the run, and adds Resentment when the holder is
## the player (ADR 0032). A landlord wins by going out first, so the count is kept on
## the turn that empties the landlord's hand, in the Cadre's memo.

## Parameter key: the Zeal each landlord win adds, in hundredths.
const ZEAL_PERCENT: String = "zeal_percent"
## Parameter key: the Resentment each win adds when the holder is the player.
const RESENTMENT: String = "resentment"
## Memo key: the rounds the holder has won as landlord.
const WINS: String = "wins"


## Needs the Zeal per win and the Resentment.
func required_parameters() -> PackedStringArray:
	return PackedStringArray([ZEAL_PERCENT, RESENTMENT])


## Adds the Zeal the wins have earned to the holder's plays as landlord.
func play_scored(context: PlayContext) -> void:
	if context.is_landlord:
		context.add_zeal += fraction(_zeal_percent())


## Counts a win when the landlord holder goes out, and adds the Resentment for the player.
func turn_taken(context: TurnContext) -> void:
	if context.seat != holder_seat or context.seat != context.landlord:
		return
	if context.is_pass() or context.cards_left != 0:
		return
	memo.add(WINS, 1)
	memo.fire()
	if context.seat == context.player:
		context.resentment += parameters[RESENTMENT]


## The Zeal and wins so far, with the Zeal as its badge.
func state_values() -> Dictionary[String, Variant]:
	var zeal: float = fraction(_zeal_percent())
	return {"zeal": zeal, "wins": memo.value(WINS), "count": zeal}


func _zeal_percent() -> int:
	return parameters[ZEAL_PERCENT] * memo.value(WINS)
