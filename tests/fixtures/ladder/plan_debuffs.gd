class_name PlanDebuffs
extends RefCounted
## The Plan's 20 debuffs as tiers and levers only, standing in for the real pool until
## P4.12 implements them. IDs follow the Plan's names.

const L: Dictionary[String, ModifierDef.Lever] = {
	"scoring": ModifierDef.Lever.SCORING,
	"economy": ModifierDef.Lever.ECONOMY,
	"hand": ModifierDef.Lever.HAND,
	"meters": ModifierDef.Lever.METERS,
	"rank": ModifierDef.Lever.RANK,
}
## ID, tier, lever.
const TABLE: Array[Array] = [
	["ration_cut", 1, "scoring"],
	["paperwork", 1, "scoring"],
	["morning_meeting", 1, "scoring"],
	["short_supply", 1, "economy"],
	["slogan_of_the_week", 1, "scoring"],
	["levy", 2, "hand"],
	["work_point_audit", 2, "meters"],
	["night_shift", 2, "hand"],
	["grain_tax", 2, "economy"],
	["straightened_lines", 2, "scoring"],
	["shared_kitchen", 2, "hand"],
	["criticism_meeting", 3, "rank"],
	["confiscation", 3, "scoring"],
	["glass_walls", 3, "hand"],
	["redistribution", 3, "hand"],
	["overtime", 3, "scoring"],
	["show_trial", 4, "meters"],
	["hungry_winter", 4, "meters"],
	["plot_seized", 4, "hand"],
	["inverted_order", 4, "rank"],
]


static func pool() -> Array[ModifierDef]:
	var definitions: Array[ModifierDef] = []
	for row: Array in TABLE:
		definitions.append(make(row[0], row[1], L[row[2]]))
	return definitions


static func make(id: String, tier: int, lever: ModifierDef.Lever) -> ModifierDef:
	var definition: ModifierDef = ModifierDef.new()
	definition.id = id
	definition.kind = ModifierDef.Kind.DEBUFF
	definition.tier = tier
	definition.lever = lever
	return definition
