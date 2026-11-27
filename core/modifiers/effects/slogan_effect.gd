class_name SloganEffect
extends ModifierEffect
## The holder's plays of one hand type, named with the ladder, score at a share of their
## Rate, rounded up, before any Rate cap (ADR 0023). The run binds the type it drew.

## Bound by the run from the ladder's draw, never in data.
const TYPE: String = "type"
const RATE_PERCENT: String = "rate_percent"
const NO_TYPE: int = -1
## The hand types a slogan may name: every one from Single to Bomb, so never a pass or
## the Rocket.
const FIRST_TYPE: int = Pattern.Type.SINGLE
const LAST_TYPE: int = Pattern.Type.BOMB


## Draws the named hand type on the ladder's stream.
static func draw(stream: RandomStream) -> int:
	return stream.next_int(FIRST_TYPE, LAST_TYPE)


func required_parameters() -> PackedStringArray:
	return PackedStringArray([RATE_PERCENT])


func play_scored(context: PlayContext) -> void:
	var named: int = parameters.get(TYPE, NO_TYPE)
	if context.seat != holder_seat or context.pattern.type != named:
		return
	context.rate_percent = mini(context.rate_percent, parameters[RATE_PERCENT])
