class_name BotTable
extends RefCounted
## The rules a bot plays under, from the same SeatRules the round reads.

var rules: RuleSet
var rank_map: PackedByteArray


func _init(seat_rules: RuleSet, seat_map: PackedByteArray) -> void:
	rules = seat_rules
	rank_map = seat_map
