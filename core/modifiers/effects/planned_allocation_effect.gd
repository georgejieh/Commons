class_name PlannedAllocationEffect
extends ModifierEffect
## A chosen rank is dealt to the holder more often than chance, through the deal
## hook's bounded swaps. The player picks the rank when buying it (ADR 0021); the data's
## rank stands in when none was picked.

## Parameter key: the rank dealt more often, used when none was picked at the purchase.
const RANK: String = "rank"
## 200 makes each copy twice as likely to reach the holder.
const PERCENT: String = "percent"


## Needs the rank and the percent.
func required_parameters() -> PackedStringArray:
	return PackedStringArray([RANK, PERCENT])


## The rank must be a valid rank.
func rank_parameters() -> PackedStringArray:
	return PackedStringArray([RANK])


## Swaps cards after the deal so copies of the rank reach the holder more often.
func on_deal(context: DealContext) -> void:
	var bias: DealBias = DealBias.new(holder_seat, picked(), fraction(parameters[PERCENT]))
	Dealer.rebias(context.deal, bias, context.stream)


## The rank the player picked when buying it, or the data's rank when none was picked.
func picked() -> int:
	return memo.value(CadreMemo.RANK, parameters[RANK])


## The rank, for the Cadre's state line.
func state_values() -> Dictionary[String, Variant]:
	return {"rank": picked()}
