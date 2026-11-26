class_name HouseholdPool
extends Resource
## Every household run setup offers, in the order it shows them (ADR 0025).

## Every household.
@export var households: Array[HouseholdDef] = []
## The household run setup opens on.
@export var default_id: String = "poor_peasants"


## The household with this ID, or null.
func household(household_id: String) -> HouseholdDef:
	for definition: HouseholdDef in households:
		if definition.id == household_id:
			return definition
	return null
