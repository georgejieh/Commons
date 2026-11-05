class_name ShopParams
extends Resource
## The state store's numbers (P4.10).

## Cadres offered per visit.
@export var slots: int = 3
## Cadres the player can hold at once.
@export var cadre_slots: int = 5
## Coupons for the first reroll, and how much each later one adds.
@export var reroll_base: int = 2
@export var reroll_step: int = 1
## Weight of each rarity, common first, when drawing stock.
@export var rarity_weights: Array[int] = [60, 30, 10]
