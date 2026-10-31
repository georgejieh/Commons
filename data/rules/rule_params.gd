class_name RuleParams
extends Resource
## The editable numbers and switches a RuleSet is built from.

@export var min_straight_length: int
@export var min_pair_chain_length: int
@export var min_airplane_length: int
@export var two_may_chain: bool
@export var single_wings_allowed: bool
@export var pair_wings_allowed: bool
## Pagat: 4-4-4-5-5-5-9-9 is legal, so a pair may fill two single wings.
@export var single_wings_may_pair: bool
@export var joker_or_two_may_be_wing: bool
## Pagat: both jokers may never be kickers, on wings or on a quad.
@export var rocket_may_be_kicker: bool
@export var four_two_singles_allowed: bool
@export var four_two_pairs_allowed: bool
@export var four_two_singles_may_share_rank: bool
@export var five_plus_is_bomb: bool
@export var wild_ranks: Array[int]
@export var rocket_above_wild_bomb: bool
@export var anti_spring_doubles: bool
## Hand sizes that are called out to the table.
@export var announce_at: Array[int]


## Returns a copy sharing nothing, because duplicate() shares the arrays.
func copy() -> RuleParams:
	var result: RuleParams = duplicate()
	result.wild_ranks = wild_ranks.duplicate()
	result.announce_at = announce_at.duplicate()
	return result
