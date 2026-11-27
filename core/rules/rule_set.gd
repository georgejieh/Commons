# gdlint: disable=max-public-methods
# Over 20 public methods: one read-only accessor per rule parameter, as the params hold.
class_name RuleSet
extends RefCounted
## Every legality parameter, frozen at construction. Modifiers edit a copy of the
## params and build a new RuleSet; nothing changes one in place.

## The rule values a RuleSet uses by default: the base game's.
const DEFAULT_PARAMS: RuleParams = preload("res://data/rules/default_rules.tres")

var _params: RuleParams


func _init(params: RuleParams) -> void:
	_params = params.copy()
	# Only a rank from 3 to 2 can be wild (ADR 0029), and a rank listed twice is one. Every
	# reader of the wild ranks trusts this.
	var wild: Array[int] = []
	for rank: int in params.wild_ranks:
		if Ranks.is_valid(rank) and rank <= Ranks.TWO and not wild.has(rank):
			wild.append(rank)
	_params.wild_ranks = wild


## A rule set of the default parameters, before any modifier edits them.
static func default_rules() -> RuleSet:
	return RuleSet.new(DEFAULT_PARAMS)


## True when both were built from the same parameters, as two seats' rules are unless a
## modifier changed one seat's (ADR 0039).
func same_as(other: RuleSet) -> bool:
	if other == self:
		return true
	for property: Dictionary in _params.get_property_list():
		if property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var name: String = property["name"]
		if _params.get(name) != other._params.get(name):
			return false
	return true


## The fewest cards in a straight.
func min_straight_length() -> int:
	return _params.min_straight_length


## The fewest pairs in a run of pairs.
func min_pair_chain_length() -> int:
	return _params.min_pair_chain_length


## The fewest trios in an airplane.
func min_airplane_length() -> int:
	return _params.min_airplane_length


## True when a 2 may be part of a straight, a pair chain or an airplane.
func two_may_chain() -> bool:
	return _params.two_may_chain


## The highest base rank a chain may reach.
func last_chain_rank() -> int:
	return Ranks.TWO if _params.two_may_chain else Ranks.LAST_CHAINABLE


## True when a trio or an airplane may carry single cards as wings.
func single_wings_allowed() -> bool:
	return _params.single_wings_allowed


## True when a trio or an airplane may carry pairs as wings.
func pair_wings_allowed() -> bool:
	return _params.pair_wings_allowed


## True when a pair may fill two single wings, so 4-4-4-5-5-5-9-9 is legal.
func single_wings_may_pair() -> bool:
	return _params.single_wings_may_pair


## True when a joker or a 2 may be a wing.
func joker_or_two_may_be_wing() -> bool:
	return _params.joker_or_two_may_be_wing


## True when both jokers may be kickers, on wings or on a four of a kind.
func rocket_may_be_kicker() -> bool:
	return _params.rocket_may_be_kicker


## True when a four of a kind may carry two single cards.
func four_two_singles_allowed() -> bool:
	return _params.four_two_singles_allowed


## True when a four of a kind may carry two pairs.
func four_two_pairs_allowed() -> bool:
	return _params.four_two_pairs_allowed


## True when the two singles a four of a kind carries may be of one rank.
func four_two_singles_may_share_rank() -> bool:
	return _params.four_two_singles_may_share_rank


## True when five or more of a kind is a bomb.
func five_plus_is_bomb() -> bool:
	return _params.five_plus_is_bomb


## True when a card of the rank stands in for any rank from 3 to 2 (ADR 0029).
func is_wild(rank: int) -> bool:
	return _params.wild_ranks.has(rank)


## A copy of the wild ranks, each from 3 to 2 and listed once.
func wild_ranks() -> Array[int]:
	return _params.wild_ranks.duplicate()


## True when the rocket beats a bomb made with wild cards.
func rocket_above_wild_bomb() -> bool:
	return _params.rocket_above_wild_bomb


## True when an Anti-Spring scores its multiplier, as a Spring does.
func anti_spring_doubles() -> bool:
	return _params.anti_spring_doubles


## True when a seat with this many cards left is called out to the table.
func announces_at(cards_left: int) -> bool:
	return _params.announce_at.has(cards_left)


## True when the seat must play on its first chance to pass if anything beats the table.
func must_answer_once() -> bool:
	return _params.must_answer_once


## True when every other seat sees this seat's hand.
func hand_shown() -> bool:
	return _params.hand_shown
