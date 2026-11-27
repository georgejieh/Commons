class_name StakhanoviteEffect
extends ModifierEffect
## The holder's Straights gain Zeal, given in hundredths, for each card beyond the
## shortest legal length. Each Straight of growth_length or more cards the holder plays
## raises that Zeal per card by zeal_percent_growth for the rest of the run, from the
## next Straight on (ADR 0021).

## Parameter key: the flat Zeal per card beyond the base length, in hundredths.
const ZEAL_PERCENT_PER_CARD: String = "zeal_percent_per_card"
## Parameter key: the Straight length beyond which cards add Zeal.
const BASE_LENGTH: String = "base_length"
## Parameter key: what each long Straight adds to the Zeal per card, in hundredths.
const ZEAL_PERCENT_GROWTH: String = "zeal_percent_growth"
## Parameter key: the Straight length that counts as long.
const GROWTH_LENGTH: String = "growth_length"
## Memo key: the long Straights the holder has played.
const LONG_STRAIGHTS: String = "long_straights"


## Needs the Zeal per card, the base length, the growth and the long length.
func required_parameters() -> PackedStringArray:
	return PackedStringArray(
		[ZEAL_PERCENT_PER_CARD, BASE_LENGTH, ZEAL_PERCENT_GROWTH, GROWTH_LENGTH]
	)


## Adds the Zeal for each card of a Straight beyond the base length.
func play_scored(context: PlayContext) -> void:
	if context.pattern.type != Pattern.Type.STRAIGHT:
		return
	var extra: int = maxi(0, context.pattern.card_count - parameters[BASE_LENGTH])
	context.add_zeal += fraction(extra * _per_card())


## Counts a long Straight the holder plays, which raises the Zeal per card.
func turn_taken(context: TurnContext) -> void:
	if context.seat != holder_seat or context.is_pass():
		return
	var pattern: Pattern = context.pattern
	if pattern.type == Pattern.Type.STRAIGHT and pattern.card_count >= parameters[GROWTH_LENGTH]:
		memo.add(LONG_STRAIGHTS, 1)
		memo.fire()


## The Zeal per card now, which is also its badge.
func state_values() -> Dictionary[String, Variant]:
	var zeal: float = fraction(_per_card())
	return {"zeal": zeal, "count": zeal}


## Zeal per card in hundredths: the data's, plus what long Straights have added.
func _per_card() -> int:
	return (
		parameters[ZEAL_PERCENT_PER_CARD]
		+ parameters[ZEAL_PERCENT_GROWTH] * memo.value(LONG_STRAIGHTS)
	)
