class_name VillageBook
extends Resource
## Every family the village can hold, the sent-down youth templates that replace them,
## and the roster's numbers (P4.5).

@export var families: Array[FamilyDef] = []
@export var youth_templates: Array[FamilyDef] = []
## Surname keys for arriving youth. A draw skips surnames already in the village.
@export var youth_surnames: Array[String] = []
## Sets a family spends in reeducation before it returns.
@export var reeducation_sets: int = 2
## Sets seated per tier gained, for rising families.
@export var rise_sets: int = 2
## Opponents every Set must have.
@export var opponents: int = 2


func family(family_id: String) -> FamilyDef:
	for definition: FamilyDef in families + youth_templates:
		if definition.id == family_id:
			return definition
	return null
