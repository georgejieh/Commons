class_name CardStallParams
extends Resource
## The cards a stall offers each visit: the black market's for the private plot
## and the state store's for the communal deck (ADR 0042).

## Cards offered each visit.
@export var offers: int = 2
## The ranks the offers are drawn from, as Ranks values.
@export var ranks: Array[int] = []
## The coupons each of those ranks costs, in the same order.
@export var costs: Array[int] = []
## The suit each offer takes, by offer, in place of the one drawn; empty draws them all.
## Only the arrival sets one (ADR 0026), and the draw still happens, so the stream moves
## the same.
@export var suits: Array[int] = []
## The percent of offers that carry an enhancement, drawn evenly from them all. 0 draws
## no enhancement and leaves the stream alone.
@export var marked_percent: int = 0
## The coupons a card with an enhancement costs more.
@export var mark_cost: int = 0
