class_name ModifierDef
extends Resource
## One modifier of any kind. Behavior lives in the effect script registered under id.

enum Kind { CADRE, CAMPAIGN, DIRECTIVE, REFORM, DEBUFF, BOSS_TWIST }
enum Tag { COLLECTIVE, PRIVATE }
enum Lever { RULE, RANK, SCORING, ECONOMY, HAND, METERS, INFO }

## Debuffs have four severity tiers. Other kinds leave tier at 0.
const MAX_TIER: int = 4

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
@export var name_key: String
@export var text_key: String
