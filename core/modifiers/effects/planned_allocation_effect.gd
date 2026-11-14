class_name PlannedAllocationEffect
extends ModifierEffect
## A chosen rank is dealt to the holder more often than chance (P4.9), through the deal
## hook's bounded swaps.

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
	var bias: DealBias = DealBias.new(holder_seat, parameters[RANK], parameters[PERCENT] / 100.0)
	Dealer.rebias(context.deal, bias, context.stream)
