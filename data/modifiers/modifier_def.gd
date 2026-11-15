class_name ModifierDef
extends Resource
## One modifier of any kind. Behavior lives in the effect script registered under id.

enum Kind { CADRE, CAMPAIGN, DIRECTIVE, REFORM, DEBUFF, BOSS_TWIST }
enum Tag { COLLECTIVE, PRIVATE }
enum Lever { RULE, RANK, SCORING, ECONOMY, HAND, METERS, INFO }

## Debuffs have four severity tiers. Other kinds leave tier at 0.
const MAX_TIER: int = 4
## Parameters named with this prefix hold Zeal in hundredths, so text shows 50 as 0.5.
const ZEAL_PERCENT_PREFIX: String = "zeal_percent"
## Parameters named with this prefix hold a multiplier in hundredths, so 150 shows as 1.5.
const TIMES_PERCENT_PREFIX: String = "times_percent"
const PERCENT: float = 100.0

@export var id: String
@export var kind: Kind
@export var tag: Tag
@export var lever: Lever
@export var tier: int
## Hook names from the Hooks class.
@export var hooks: Array[String]
@export var parameters: Dictionary[String, int]
@export var rarity: int
@export var cost: int
## Finished runs needed before it is offered (ADR 0021, read from P4.14).
@export var unlock_tier: int = 0
@export var name_key: String
@export var text_key: String
## True when the effect changes every seat's play, not only its holder's.
@export var table_wide: bool = false
## True when buying it asks the player to pick a rank first (ADR 0021).
@export var needs_rank: bool = false
## The line that says where a Cadre with run state stands, or empty when it keeps none.
@export var state_key: String = ""


## A multiple as rules text prints it: a whole one with no decimal, as "2", and any
## other as "1.5".
static func multiple(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(roundi(value))
	return String.num(value)


## The values that fill text_key's placeholders: the parameters, with Zeal and
## multipliers in hundredths written as multiples.
func text_values() -> Dictionary[String, Variant]:
	var values: Dictionary[String, Variant] = {}
	for key: String in parameters:
		if key.begins_with(ZEAL_PERCENT_PREFIX) or key.begins_with(TIMES_PERCENT_PREFIX):
			values[key] = multiple(parameters[key] / PERCENT)
		else:
			values[key] = parameters[key]
	return values
