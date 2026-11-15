class_name SeatRules
extends RefCounted
## One RuleSet and one effective-rank map per seat. Queries only read the cache.
## refresh() rebuilds it, at O(modifiers × 15), when something has marked it stale.

## Counts rebuilds, so tests can prove queries never cause one.
var rebuilds: int = 0

var _stack: ModifierStack
var _base_params: RuleParams
var _rules: Array[RuleSet] = []
var _maps: Array[PackedByteArray] = []
var _landlord: int = Seats.NONE
var _trick_bombed: bool = false
## Per seat, a bit per rank whose every card in hand carries that seat's own stamp.
var _stamped: PackedInt32Array = PackedInt32Array()
var _seen_revision: int = -1
var _dirty: bool = true
## A uniform table never rebuilds.
var _fixed: bool = false


func _init(stack: ModifierStack, base_params: RuleParams = RuleSet.DEFAULT_PARAMS) -> void:
	_stack = stack
	_base_params = base_params
	_stamped.resize(Seats.COUNT)
	refresh()


## The same rules and map for every seat, with no modifiers.
static func uniform(rules: RuleSet, rank_map: PackedByteArray) -> SeatRules:
	var table: SeatRules = SeatRules.new(ModifierStack.new())
	for seat: int in Seats.COUNT:
		table._rules[seat] = rules
		table._maps[seat] = rank_map
	table._fixed = true
	return table


func rules_for(seat: int) -> RuleSet:
	return _rules[seat]


func map_for(seat: int) -> PackedByteArray:
	return _maps[seat]


func start_round(landlord: int) -> void:
	_landlord = landlord
	_trick_bombed = false
	_stamped.fill(0)
	_dirty = true
	refresh()


func set_trick_bombed(bombed: bool) -> void:
	if bombed != _trick_bombed:
		_trick_bombed = bombed
		_dirty = true
		refresh()


## Which ranks the seat holds only its own stamped cards of (ADR 0021). The round sets
## it before each action; a change marks the cache stale.
func set_stamped(seat: int, mask: int) -> void:
	if _stamped[seat] != mask:
		_stamped[seat] = mask
		_dirty = true


## Rebuilds if the flag is set or the stack has changed. Returns true if it rebuilt.
## The round calls this before each action, so a stack change applies at once.
func refresh() -> bool:
	if _fixed or (not _dirty and _seen_revision == _stack.revision):
		return false
	_seen_revision = _stack.revision
	_dirty = false
	rebuilds += 1
	_rules.clear()
	_maps.clear()
	for seat: int in Seats.COUNT:
		var params: RuleParams = _base_params.copy()
		_stack.run_build_ruleset(RulesetContext.new(seat, _landlord, params))
		_rules.append(RuleSet.new(params))
		var rank_map: PackedByteArray = Ranks.identity_map()
		var context: RankMapContext = RankMapContext.new(seat, _landlord, _trick_bombed, rank_map)
		context.stamped = _stamped[seat]
		_stack.run_build_rank_map(context)
		_maps.append(rank_map)
	return true
