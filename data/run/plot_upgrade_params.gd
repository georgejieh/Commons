class_name PlotUpgradeParams
extends Resource
## What the black market sells for the private plot (P4.10): cards to put in it, and
## upgrades to its size and to the swaps each round.

## Cards offered each visit, the ranks they are drawn from (as Ranks values), and the
## coupons each of those ranks costs.
@export var card_offers: int = 2
@export var card_ranks: Array[int] = [10, 11, 12]
@export var card_costs: Array[int] = [3, 4, 6]
## The suit each offer takes, by offer, in place of the one drawn; empty draws them all.
## Only the arrival sets one (ADR 0026), and the draw still happens, so the stream moves
## the same.
@export var card_suits: Array[int] = []

## Coupons for one more card of plot capacity, and the most steps a run can buy.
@export var capacity_cost: int = 6
@export var capacity_max: int = 2
## Coupons for one more swap each round, and the most steps a run can buy.
@export var swap_cost: int = 8
@export var swap_max: int = 1
