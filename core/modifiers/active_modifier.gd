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


func _init(modifier: ModifierDef, modifier_effect: ModifierEffect) -> void:
	definition = modifier
	effect = modifier_effect


func order_group() -> int:
	match definition.kind:
		ModifierDef.Kind.DEBUFF:
			return GROUP_DEBUFF
		ModifierDef.Kind.BOSS_TWIST:
			return GROUP_BOSS
	return GROUP_CADRE
