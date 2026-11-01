class_name Personality
extends Resource
## One villager's way of playing: a tier plus five parameters. Personality.Level values
## become numbers through one PersonalityTable.

enum Level { LOW, MID, HIGH }

## A BotConfig.Tier.
@export var tier: int
@export var bomb_aggression: Level
@export var cooperation: Level
@export var honesty: Level
@export var ambition: Level
@export var grudge: Level
