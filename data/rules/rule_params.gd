class_name RuleParams
extends Resource
## The editable numbers and switches a RuleSet is built from.

## The fewest cards in a straight.
@export var min_straight_length: int
## The fewest pairs in a run of pairs.
@export var min_pair_chain_length: int
## The fewest triples in an airplane.
@export var min_airplane_length: int
## Whether a 2 may be part of a straight, a run of pairs or an airplane.
@export var two_may_chain: bool
## Whether a triple or an airplane may carry single cards as wings.
@export var single_wings_allowed: bool
## Whether a triple or an airplane may carry pairs as wings.
@export var pair_wings_allowed: bool
## Pagat: 4-4-4-5-5-5-9-9 is legal, so a pair may fill two single wings.
@export var single_wings_may_pair: bool
## Whether a joker or a 2 may be a wing.
@export var joker_or_two_may_be_wing: bool
## Pagat: both jokers may never be kickers, on wings or on a quad.
@export var rocket_may_be_kicker: bool
## Whether four of a kind may carry two single cards.
@export var four_two_singles_allowed: bool
## Whether four of a kind may carry two pairs.
@export var four_two_pairs_allowed: bool
## Whether the two single cards four of a kind carries may be the same rank.
@export var four_two_singles_may_share_rank: bool
## Whether five or more of a kind is a bomb.
@export var five_plus_is_bomb: bool
## The ranks that are wild: a card of one stands in for any rank (ADR 0029).
@export var wild_ranks: Array[int]
## Whether the rocket beats a bomb made with wild cards.
@export var rocket_above_wild_bomb: bool
## Whether an anti-spring scores its multiplier, as a spring does (ScoreParams).
@export var anti_spring_doubles: bool
## Hand sizes that are called out to the table.
@export var announce_at: Array[int]
## On its first chance to pass in a round, the seat must play when anything beats the
## table (Night Shift, ADR 0023).
@export var must_answer_once: bool = false
## Every other seat sees the seat's hand (Glass Walls, ADR 0023).
@export var hand_shown: bool = false


## Returns a copy sharing nothing, because duplicate() shares the arrays.
func copy() -> RuleParams:
	var result: RuleParams = duplicate()
	result.wild_ranks = wild_ranks.duplicate()
	result.announce_at = announce_at.duplicate()
	return result
