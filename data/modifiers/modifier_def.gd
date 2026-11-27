class_name ModifierDef
extends Resource
## One modifier of any kind. Behavior lives in the effect script registered under id.

enum Kind { CADRE, REFORM, DEBUFF, BOSS_TWIST }
enum Tag { COLLECTIVE, PRIVATE }
enum Lever { RULE, RANK, SCORING, ECONOMY, HAND, METERS, INFO }
## How often a Cadre reaches a counter, which indexes ShopParams.rarity_weights.
enum Rarity { COMMON, UNCOMMON, RARE }

## Debuffs have four severity tiers. Other kinds leave tier at 0.
const MAX_TIER: int = 4
## Parameters named with this prefix hold Zeal in hundredths, so text shows 50 as 0.5.
const ZEAL_PERCENT_PREFIX: String = "zeal_percent"
## Parameters named with this prefix hold a multiplier in hundredths, so 150 shows as 1.5.
const TIMES_PERCENT_PREFIX: String = "times_percent"
const PERCENT: float = 100.0

## The ID the registries, the saves and the pools name it by.
@export var id: String
## Which kind of modifier it is.
@export var kind: Kind
## Whether it is collective or private; a private Cadre breeds Resentment.
@export var tag: Tag
## Which part of the game it changes.
@export var lever: Lever
## A debuff's severity tier, from 1 to MAX_TIER; 0 for any other kind.
@export var tier: int
## Hook names from the Hooks class.
@export var hooks: Array[String]
## The numbers its effect script reads, by name.
@export var parameters: Dictionary[String, int]
## How rare it is, which indexes ShopParams.rarity_weights.
@export var rarity: Rarity
## What it costs at the counter, in coupons.
@export var cost: int
## Finished runs needed before it is offered (ADR 0021); RunUnlocks reads it (ADR 0025).
@export var unlock_tier: int = 0
## The string key of its name.
@export var name_key: String
## The string key of its rules text.
@export var text_key: String
## True when a collective Cadre's scoring also pays on the holder's teammate's plays while
## the holder is a peasant (ADR 0039). A Cadre never acts for the holder's opponents, and
## its rules and ranks are the holder's alone, so nothing else can say more.
@export var counts_for_teammate: bool = false
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


## The parameters as a rules text prints them: a parameter whose name begins with one of
## the prefixes holds hundredths and is written as a multiple.
static func text_numbers(
	numbers: Dictionary[String, int], hundredths_prefixes: Array[String]
) -> Dictionary[String, Variant]:
	var values: Dictionary[String, Variant] = {}
	for key: String in numbers:
		var in_hundredths: bool = false
		for prefix: String in hundredths_prefixes:
			in_hundredths = in_hundredths or key.begins_with(prefix)
		if in_hundredths:
			values[key] = multiple(numbers[key] / PERCENT)
		else:
			values[key] = numbers[key]
	return values


## The values that fill text_key's placeholders: the parameters, with Zeal and
## multipliers in hundredths written as multiples.
func text_values() -> Dictionary[String, Variant]:
	return text_numbers(parameters, [ZEAL_PERCENT_PREFIX, TIMES_PERCENT_PREFIX])
