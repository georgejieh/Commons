class_name Personality
extends Resource
## One villager's way of playing: a tier plus five parameters. Personality.Level values
## become numbers through one PersonalityTable.

enum Level { LOW, MID, HIGH }

## A BotConfig.Tier.
@export var tier: int
## How readily the villager bombs: a level of PersonalityTable.bomb_aggression.
@export var bomb_aggression: Level
## How readily the villager helps a teammate: a level of PersonalityTable.cooperation.
@export var cooperation: Level
## How truthfully the villager declares need: a level of PersonalityTable.honesty.
@export var honesty: Level
## How eagerly the villager bids: a level of PersonalityTable.ambition.
@export var ambition: Level
## How much the villager holds a grudge: a level of PersonalityTable.grudge.
@export var grudge: Level
