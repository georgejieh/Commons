class_name PlotUpgradeParams
extends Resource
## The upgrades the black market sells for the private plot (P4.10): room for more cards,
## and more swaps each round. The cards themselves are its stall's (CardStallParams).

## Coupons for one more card of plot capacity, and the most steps a run can buy.
@export var capacity_cost: int = 6
@export var capacity_max: int = 2
## Coupons for one more swap each round, and the most steps a run can buy.
@export var swap_cost: int = 8
@export var swap_max: int = 1
