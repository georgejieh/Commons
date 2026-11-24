class_name ActiveModifier
extends RefCounted
## A modifier in play. Slot and ladder order are the order entries were added.

const ORDER_GROUPS: int = 3
const GROUP_CADRE: int = 0
const GROUP_DEBUFF: int = 1
const GROUP_BOSS: int = 2

var definition: ModifierDef
var effect: ModifierEffect
var enabled: bool = true
## Whose seats its rule and rank hooks build, and whose plays its scoring hooks score
## (ADR 0039), read once from how it is held.
var rules_reach: SeatScope.Reach
var score_reach: SeatScope.Reach


func _init(modifier: ModifierDef, modifier_effect: ModifierEffect) -> void:
	definition = modifier
	effect = modifier_effect
	rules_reach = SeatScope.rules_reach(modifier)
	score_reach = SeatScope.score_reach(modifier)


## True when its rule and rank hooks build this seat.
func builds_for(seat: int) -> bool:
	return SeatScope.reaches(rules_reach, effect.holder_seat, seat, Seats.NONE)


## True when its scoring hooks score this seat's play in a round with this landlord.
func scores_for(seat: int, landlord: int) -> bool:
	return SeatScope.reaches(score_reach, effect.holder_seat, seat, landlord)


func order_group() -> int:
	match definition.kind:
		ModifierDef.Kind.DEBUFF:
			return GROUP_DEBUFF
		ModifierDef.Kind.BOSS_TWIST:
			return GROUP_BOSS
	return GROUP_CADRE
