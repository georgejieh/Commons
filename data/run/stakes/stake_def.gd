class_name StakeDef
extends Resource
## One stake (ADR 0025): a harder rule set, which keeps every rule of the stakes below it.
## It carries only numbers the game already has; a stake's effect is the sum of its own
## and every lower stake's (RunStakes.total).

## The ID the profile records it by.
@export var id: String
## The string key of its name.
@export var name_key: String
## Its rule line, filled from text_values().
@export var text_key: String
## Every Quota's target rises this many percent.
@export var target_percent: int = 0
## Cadres the state store offers fewer of.
@export var store_slot_cut: int = 0
## Famine the run starts with.
@export var famine: int = 0
## Denunciation the run starts with.
@export var denunciation: int = 0
## More faces of the audit die that mean an audit, still under its cap.
@export var audit_faces: int = 0
## More severity every debuff ladder may spend.
@export var ladder_severity: int = 0


func text_values() -> Dictionary[String, Variant]:
	return {
		"percent": target_percent,
		"slots": store_slot_cut,
		"famine": famine,
		"denunciation": denunciation,
		"faces": audit_faces,
		"severity": ladder_severity,
	}
