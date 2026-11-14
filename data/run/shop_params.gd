class_name ShopParams
extends Resource
## One counter's numbers (P4.10): the state store's or the black market's.

## Cadres offered per visit.
@export var slots: int = 3
## Cadres the player can hold at once.
@export var cadre_slots: int = 5
## Coupons for the first reroll, and how much each later one adds.
@export var reroll_base: int = 2
@export var reroll_step: int = 1
## Weight of each rarity, common first, when drawing stock.
@export var rarity_weights: Array[int] = [60, 30, 10]
## What an item costs here, as a percent of its listed cost, rounded up.
@export var price_percent: int = 100
## How many of one item this counter sells in a run. 0 means no limit.
@export var stock_per_item: int = 0
