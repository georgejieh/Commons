class_name EffectRegistry
extends RefCounted
## Maps modifier IDs to effect scripts. Definitions stay data; behavior stays here.


static func has_effect(modifier_id: String) -> bool:
	return _build(modifier_id) != null


## Returns a new effect for the definition, held by the seat.
static func create(definition: ModifierDef, holder_seat: int) -> ModifierEffect:
	var effect: ModifierEffect = _build(definition.id)
	effect.parameters = definition.parameters
	effect.holder_seat = holder_seat
	return effect


static func _build(modifier_id: String) -> ModifierEffect:
	match modifier_id:
		"cultural_revolution":
			return CulturalRevolutionEffect.new()
		"promotion_of_the_masses":
			return PromotionEffect.new()
		"criticism_meeting":
			return RankAsEffect.new()
		"inverted_order":
			return InvertedOrderEffect.new()
	return null
