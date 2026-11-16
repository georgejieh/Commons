class_name VillageBook
extends Resource
## Every family the village can hold, the sent-down youth templates that replace them,
## and the roster's numbers (P4.5).

@export var families: Array[FamilyDef] = []
@export var youth_templates: Array[FamilyDef] = []
## Surname keys for arriving youth. A draw skips surnames already in the village.
@export var youth_surnames: Array[String] = []
## Sets a family misses while in reeducation.
@export var reeducation_sets: int = 1
## Sets seated per tier gained, for rising families.
@export var rise_sets: int = 2
## Opponents every Set must have.
@export var opponents: int = 2
## The most families that may starve in one Year (ADR 0025), so a long famine does not
## empty the village in a season.
@export var starvations_per_year: int = 1
## The village's drift from one generation to the next (ADR 0028): the chance each
## personality level moves a step, the most a generation shifts a voice's pitch either
## way, and the most it may shift in all, both as fractions of the family's own.
@export var drift_chance: float = 0.15
@export var pitch_step: float = 0.04
@export var pitch_limit: float = 0.12


func family(family_id: String) -> FamilyDef:
	for definition: FamilyDef in families + youth_templates:
		if definition.id == family_id:
			return definition
	return null
