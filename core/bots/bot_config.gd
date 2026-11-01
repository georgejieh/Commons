class_name BotConfig
extends RefCounted
## What makes one bot differ from another.

enum Tier { EASY, MEDIUM, HARD, EXPERT }

const DEFAULT_WEIGHTS: BotWeights = preload("res://data/bots/default_weights.tres")
const TABLE: PersonalityTable = preload("res://data/bots/personality_table.tres")

var weights: BotWeights
var tier: Tier
## Seeds a search's deals of the unseen cards. The run sets it from its ai stream.
var search_seed: int
## Neutral until a personality sets them.
var bomb_shift: float = 0.0
var cooperation: float = 1.0
var honesty: float = 1.0
var ambition: float = 0.0
var grudge: float = 0.0
## How much this bot holds against each seat, from villager memory.
var memory: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0])


func _init(
	bot_weights: BotWeights = DEFAULT_WEIGHTS, bot_tier: Tier = Tier.HARD, seed_value: int = 0
) -> void:
	weights = bot_weights
	tier = bot_tier
	search_seed = seed_value


static func from_personality(personality: Personality, seed_value: int = 0) -> BotConfig:
	var tier_value: Tier = personality.tier as Tier
	var config: BotConfig = BotConfig.new(DEFAULT_WEIGHTS, tier_value, seed_value)
	config.bomb_shift = TABLE.bomb_aggression[personality.bomb_aggression]
	config.cooperation = TABLE.cooperation[personality.cooperation]
	config.honesty = TABLE.honesty[personality.honesty]
	config.ambition = TABLE.ambition[personality.ambition]
	config.grudge = TABLE.grudge[personality.grudge]
	return config


func search_candidates() -> int:
	return weights.expert_candidates if tier == Tier.EXPERT else weights.hard_candidates


func search_samples() -> int:
	return weights.expert_samples if tier == Tier.EXPERT else weights.hard_samples


## The policy rollouts play by.
func rollout_config() -> BotConfig:
	return BotConfig.new(weights, Tier.MEDIUM)


## Card counting, endgame blocking and seat roles start at Hard.
func reads_the_table() -> bool:
	return tier >= Tier.HARD
