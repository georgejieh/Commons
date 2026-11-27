class_name BotConfig
extends RefCounted
## What makes one bot differ from another.

## How a bot decides: Easy plays greedily, Medium by the scored policy, Hard also reads the
## table, and Expert searches before it plays.
enum Tier { EASY, MEDIUM, HARD, EXPERT }

## The tuning numbers a bot scores and decides by unless it is given others.
const DEFAULT_WEIGHTS: BotWeights = preload("res://data/bots/default_weights.tres")
## The numbers each personality trait level sets, read by from_personality and take_traits.
const TABLE: PersonalityTable = preload("res://data/bots/personality_table.tres")
## Cooperation is a chance, so loyalty never lifts it past certain.
const MAX_COOPERATION: float = 1.0

## The tuning numbers this bot scores and decides by. Shared between copies, never changed.
var weights: BotWeights
## How this bot decides; fixed when it is made.
var tier: Tier
## Seeds a search's deals of the unseen cards. The run sets it from its ai stream.
var search_seed: int
## Added to the cards at which this bot counts a landlord as running away, so a high value
## has it bomb sooner; 0 until a personality sets it.
var bomb_shift: float = 0.0
## The chance, from 0 to 1, that this bot passes on its teammate's play; 1 until a
## personality sets it.
var cooperation: float = 1.0
## What a warm family's memory of the player adds to its cooperation while the player is
## its teammate (ADR 0025). The run sets it each round; 0 for everyone else.
var loyalty: float = 0.0
## The chance, from 0 to 1, that this bot declares its true need in a Mutual Aid trade.
var honesty: float = 1.0
## The share of true need a lie adds.
var lie_share: float = 0.0
## Taken off the bid thresholds, so a high value has this bot bid on weaker hands.
var ambition: float = 0.0
## Score this bot adds, per point of memory, for answering a seat it holds a grudge against.
var grudge: float = 0.0
## How much this bot holds against each seat, from villager memory.
var memory: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0])
## The chance, from 0 to 1, that this bot tries on a decision; the rest it slacks.
var effort: float = 1.0
## A bonus per Pattern.Type added to every play the bot scores, so it favors the hand
## types someone else played. Empty for none.
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


## A config of the personality's tier with its five traits set, as a villager plays.
static func from_personality(personality: Personality, seed_value: int = 0) -> BotConfig:
	var tier_value: Tier = personality.tier
	var config: BotConfig = BotConfig.new(DEFAULT_WEIGHTS, tier_value, seed_value)
	config.take_traits(personality)
	return config


## Plays by the personality's five traits from now on; the tier is left as it is. A
## family's trait shifts use it as a meter crosses their band (ADR 0043).
func take_traits(personality: Personality) -> void:
	bomb_shift = TABLE.bomb_aggression[personality.bomb_aggression]
	cooperation = TABLE.cooperation[personality.cooperation]
	honesty = TABLE.honesty[personality.honesty]
	lie_share = TABLE.lie_share[personality.honesty]
	ambition = TABLE.ambition[personality.ambition]
	grudge = TABLE.grudge[personality.grudge]


## A copy that shares nothing the run changes, for a search that reads it on another
## thread. The weights and script are shared: nothing changes them in play.
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


## True for a tier that searches before it plays (ADR 0030).
func searches() -> bool:
	return tier == Tier.EXPERT


## How many candidate plays an Expert search weighs.
func search_candidates() -> int:
	return weights.expert_candidates


## How many deals of the unseen cards an Expert search plays each candidate out on.
func search_samples() -> int:
	return weights.expert_samples


## The policy rollouts play by.
func rollout_config() -> BotConfig:
	return BotConfig.new(weights, Tier.MEDIUM)


## Card counting, endgame blocking and seat roles start at Hard.
func reads_the_table() -> bool:
	return tier >= Tier.HARD
