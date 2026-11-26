class_name PlotUpgradeParams
extends Resource
## The upgrades the black market sells for the private plot: room for more cards,
## and more swaps each round. The cards themselves are its stall's (CardStallParams).

## Coupons for one more card of plot capacity.
@export var capacity_cost: int = 6
## The most steps of plot capacity a run can buy.
@export var capacity_max: int = 2
## Coupons for one more swap each round.
@export var swap_cost: int = 8
## The most steps of swaps a run can buy.
@export var swap_max: int = 1
