class_name LadderParams
extends Resource
## The numbers behind debuff ladders.

## Weights for the round's own tier, one below, two below, and so on.
@export var tier_weights: Array[int]
## Total severity a Set's ladder may reach, indexed by RunState.SetType.
@export var severity_budgets: Array[int]
