class_name ActiveModifier
extends RefCounted
## A modifier in play. Slot and ladder order are the order entries were added.

## How many groups entries run in: Cadres first, then debuffs, then the boss's rule.
const ORDER_GROUPS: int = 3
## The order group of a Cadre and anything not a debuff or a boss rule; runs first.
const GROUP_CADRE: int = 0
## The order group of a debuff; runs after Cadres.
const GROUP_DEBUFF: int = 1
## The order group of a boss twist; runs last.
const GROUP_BOSS: int = 2

## The definition this entry runs, as loaded from data.
var definition: ModifierDef
## The effect script that does what the definition says; its holder_seat is who holds it.
var effect: ModifierEffect
## False once something has switched it off, as Appeal does a debuff; a disabled entry runs no hook.
var enabled: bool = true
## Whose seats its rule and rank hooks build (ADR 0039), read once from how it is held.
var rules_reach: SeatScope.Reach
## Whose plays its scoring hooks score (ADR 0039), read once from how it is held.
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


## The group this entry runs in, by its kind: Cadres, then debuffs, then boss twists.
func order_group() -> int:
	match definition.kind:
		ModifierDef.Kind.DEBUFF:
			return GROUP_DEBUFF
		ModifierDef.Kind.BOSS_TWIST:
			return GROUP_BOSS
	return GROUP_CADRE
