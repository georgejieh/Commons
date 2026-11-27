class_name ReformRegistry
extends RefCounted
## Maps Reform IDs to effect scripts. Definitions stay data; behaviour stays here.


## True when a Reform ID has an effect script; a definition without one is a data error.
static func has_effect(reform_id: String) -> bool:
	return _build(reform_id) != null


## Returns a new effect for the definition, with its parameters.
static func create(definition: ReformDef) -> ReformEffect:
	var effect: ReformEffect = _build(definition.id)
	effect.parameters = definition.parameters.duplicate()
	return effect


static func _build(reform_id: String) -> ReformEffect:
	match reform_id:
		"supply_cooperative":
			return SupplyCooperativeEffect.new()
		"work_point_reform":
			return WorkPointReformEffect.new()
		"enlarged_committee":
			return EnlargedCommitteeEffect.new()
		"grain_reserve":
			return GrainReserveEffect.new()
		"couriers_bag":
			return CouriersBagEffect.new()
		"unplanned_economy":
			return UnplannedEconomyEffect.new()
		"mass_line":
			return MassLineEffect.new()
		"industrialization":
			return IndustrializationEffect.new()
	return null
