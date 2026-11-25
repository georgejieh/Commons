class_name PlannedAllocationEffect
extends ModifierEffect
## A chosen rank is dealt to the holder more often than chance, through the deal
## hook's bounded swaps. The player picks the rank when buying it (ADR 0021); the data's
## rank stands in when none was picked.

const RANK: String = "rank"
## 200 makes each copy twice as likely to reach the holder.
const PERCENT: String = "percent"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([RANK, PERCENT])


func rank_parameters() -> PackedStringArray:
	return PackedStringArray([RANK])


func on_deal(context: DealContext) -> void:
	if context.stream == null:
		return
	var bias: DealBias = DealBias.new(holder_seat, picked(), parameters[PERCENT] / 100.0)
	Dealer.rebias(context.deal, bias, context.stream)


func picked() -> int:
	return memo.value(CadreMemo.RANK, parameters[RANK])


func state_values() -> Dictionary[String, Variant]:
	return {"rank": picked()}
