# gdlint: disable=max-public-methods
# Over 20 public methods: one read-only accessor per rule parameter, as the params hold.
class_name RuleSet
extends RefCounted
## Every legality parameter, frozen at construction. Modifiers edit a copy of the
## params and build a new RuleSet; nothing changes one in place.

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


func min_straight_length() -> int:
	return _params.min_straight_length


func min_pair_chain_length() -> int:
	return _params.min_pair_chain_length


func min_airplane_length() -> int:
	return _params.min_airplane_length


func two_may_chain() -> bool:
	return _params.two_may_chain


## The highest base rank a chain may reach.
func last_chain_rank() -> int:
	return Ranks.TWO if _params.two_may_chain else Ranks.LAST_CHAINABLE


func single_wings_allowed() -> bool:
	return _params.single_wings_allowed


func pair_wings_allowed() -> bool:
	return _params.pair_wings_allowed


func single_wings_may_pair() -> bool:
	return _params.single_wings_may_pair


func joker_or_two_may_be_wing() -> bool:
	return _params.joker_or_two_may_be_wing


func rocket_may_be_kicker() -> bool:
	return _params.rocket_may_be_kicker


func four_two_singles_allowed() -> bool:
	return _params.four_two_singles_allowed


func four_two_pairs_allowed() -> bool:
	return _params.four_two_pairs_allowed


func four_two_singles_may_share_rank() -> bool:
	return _params.four_two_singles_may_share_rank


func five_plus_is_bomb() -> bool:
	return _params.five_plus_is_bomb


func is_wild(rank: int) -> bool:
	return _params.wild_ranks.has(rank)


func wild_ranks() -> Array[int]:
	return _params.wild_ranks.duplicate()


func rocket_above_wild_bomb() -> bool:
	return _params.rocket_above_wild_bomb


func anti_spring_doubles() -> bool:
	return _params.anti_spring_doubles


func announces_at(cards_left: int) -> bool:
	return _params.announce_at.has(cards_left)


## True when the seat must play on its first chance to pass if anything beats the table.
func must_answer_once() -> bool:
	return _params.must_answer_once


## True when every other seat sees this seat's hand.
func hand_shown() -> bool:
	return _params.hand_shown
