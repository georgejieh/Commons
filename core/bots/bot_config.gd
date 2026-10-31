class_name BotConfig
extends RefCounted
## What makes one bot differ from another.

const DEFAULT_WEIGHTS: BotWeights = preload("res://data/bots/default_weights.tres")

var weights: BotWeights


func _init(bot_weights: BotWeights = DEFAULT_WEIGHTS) -> void:
	weights = bot_weights
