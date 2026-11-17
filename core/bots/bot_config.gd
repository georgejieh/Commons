class_name BotConfig
extends RefCounted
## What makes one bot differ from another.

enum Tier { EASY, MEDIUM, HARD, EXPERT }

const DEFAULT_WEIGHTS: BotWeights = preload("res://data/bots/default_weights.tres")
const TABLE: PersonalityTable = preload("res://data/bots/personality_table.tres")
## Cooperation is a chance, so loyalty never lifts it past certain.
const MAX_COOPERATION: float = 1.0

var weights: BotWeights
var tier: Tier
## Seeds a search's deals of the unseen cards. The run sets it from its ai stream.
var search_seed: int
## Neutral until a personality sets them.
var bomb_shift: float = 0.0
var cooperation: float = 1.0
## What a warm family's memory of the player adds to its cooperation while the player is
## its teammate (ADR 0025). The run sets it each round; 0 for everyone else.
var loyalty: float = 0.0
var honesty: float = 1.0
## The share of true need a lie adds.
var lie_share: float = 0.0
var ambition: float = 0.0
var grudge: float = 0.0
## How much this bot holds against each seat, from villager memory.
var memory: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0])
## The chance, from 0 to 1, that this bot tries on a decision; the rest it slacks (P4.4).
var effort: float = 1.0
## A bonus per Pattern.Type added to every play the bot scores, so it favors the hand
## types someone else played (P4.7). Empty for none.
var type_bias: PackedFloat32Array = PackedFloat32Array()
## The authored villager that answers every decision in place of the tiers, or null for a
## bot that thinks (ADR 0026). The run that holds the script sets it.
var scripted: ScriptedVillager = null


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
	config.lie_share = TABLE.lie_share[personality.honesty]
	config.ambition = TABLE.ambition[personality.ambition]
	config.grudge = TABLE.grudge[personality.grudge]
	return config


## A copy that shares nothing the run changes, for a search that reads it on another
## thread (P5.0). The weights and script are shared: nothing changes them in play.
func copy() -> BotConfig:
	var made: BotConfig = BotConfig.new(weights, tier, search_seed)
	made.bomb_shift = bomb_shift
	made.cooperation = cooperation
	made.loyalty = loyalty
	made.honesty = honesty
	made.lie_share = lie_share
	made.ambition = ambition
	made.grudge = grudge
	made.memory = memory.duplicate()
	made.effort = effort
	made.type_bias = type_bias.duplicate()
	made.scripted = scripted
	return made


## Cooperation with loyalty added, never past MAX_COOPERATION, nor below its own.
func team_cooperation() -> float:
	return maxf(cooperation, minf(cooperation + loyalty, MAX_COOPERATION))


## True for a tier that searches before it plays, Expert today (ADR 0030).
func searches() -> bool:
	return tier == Tier.EXPERT


func search_candidates() -> int:
	return weights.expert_candidates


func search_samples() -> int:
	return weights.expert_samples


## The policy rollouts play by.
func rollout_config() -> BotConfig:
	return BotConfig.new(weights, Tier.MEDIUM)


## Card counting, endgame blocking and seat roles start at Hard.
func reads_the_table() -> bool:
	return tier >= Tier.HARD
