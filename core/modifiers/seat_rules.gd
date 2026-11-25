class_name SeatRules
extends RefCounted
## One RuleSet, one effective-rank map and one set of standings per seat. Queries only
## read the cache. refresh() rebuilds it, at O(modifiers × 15), when something has marked
## it stale. Maps and standings are built for the trick as it stands and for the other
## side of a bomb too, so a bot can follow a trick past one (ADR 0039).

## Each seat's rank maps a rebuild makes: its order and its standings, on each side of a
## bomb in the trick.
const MAPS_PER_SEAT: int = 4

## Counts rebuilds, so tests can prove queries never cause one.
var rebuilds: int = 0

var _stack: ModifierStack
var _base_params: RuleParams
var _rules: Array[RuleSet] = []
## By seat, then again by seat for the other side of a bomb: before one when the trick is
## bombed, after one when it is not.
var _maps: Array[PackedByteArray] = []
var _standings: Array[PackedByteArray] = []
var _landlord: int = Seats.NONE
var _trick_bombed: bool = false
## Per seat, a bit per rank whose every card in hand carries that seat's own stamp.
var _stamped: PackedInt32Array = PackedInt32Array()
var _seen_revision: int = -1
var _dirty: bool = true
## The round's wild ranks (ADR 0029), added to the base rules of _wild_seat, or of every
## seat while that is Seats.NONE, before modifiers.
var _wild_ranks: Array[int] = []
var _wild_seat: int = Seats.NONE
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
	var standings: PackedByteArray = Standing.of(rank_map)
	for seat: int in Seats.COUNT:
		table._rules[seat] = rules
		for side: int in [0, Seats.COUNT]:
			table._maps[side + seat] = rank_map
			table._standings[side + seat] = standings
	table._fixed = true
	return table


func rules_for(seat: int) -> RuleSet:
	return _rules[seat]


## The seat's own order, 0 to 14, for anything that reads one seat's cards.
func map_for(seat: int) -> PackedByteArray:
	return _maps[seat]


## The seat's standings (Standing), which every play's comparison key reads.
func standing_for(seat: int) -> PackedByteArray:
	return _standings[seat]


## The seat's order and standings on one side of a bomb in the trick.
func map_in(seat: int, bombed: bool) -> PackedByteArray:
	return _maps[_side(bombed) + seat]


func standing_in(seat: int, bombed: bool) -> PackedByteArray:
	return _standings[_side(bombed) + seat]


## True once a bomb has been played in the trick.
func trick_bombed() -> bool:
	return _trick_bombed


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


## Makes these ranks wild from the next refresh, beside any a modifier adds: for one seat
## alone, or for every seat with Seats.NONE. Ranks the player bought (Mass Line, Model
## Worker) are the player's seat's alone (ADR 0039); a test or the tournament's --wild
## makes them every seat's. A uniform table keeps the rules it was built with.
func set_wild_ranks(ranks: Array[int], seat: int = Seats.NONE) -> void:
	if ranks != _wild_ranks or seat != _wild_seat:
		_wild_ranks = ranks.duplicate()
		_wild_seat = seat
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
	_standings.clear()
	for seat: int in Seats.COUNT:
		var params: RuleParams = _base_params.copy()
		var wild_here: bool = _wild_seat == Seats.NONE or _wild_seat == seat
		for rank: int in _wild_ranks:
			if wild_here and not params.wild_ranks.has(rank):
				params.wild_ranks.append(rank)
		_stack.run_build_ruleset(RulesetContext.new(seat, _landlord, params))
		_rules.append(_shared(RuleSet.new(params)))
	for bombed: bool in [_trick_bombed, not _trick_bombed]:
		for seat: int in Seats.COUNT:
			_maps.append(_build_map(seat, bombed, Ranks.identity_map(), 1))
			_standings.append(_build_map(seat, bombed, Standing.identity(), Standing.STEP))
	return true


func _build_map(seat: int, bombed: bool, start: PackedByteArray, step: int) -> PackedByteArray:
	var context: RankMapContext = RankMapContext.new(seat, _landlord, bombed, start)
	context.stamped = _stamped[seat]
	context.step = step
	_stack.run_build_rank_map(context)
	return context.rank_map


## An earlier seat's RuleSet when it holds the same parameters, so seats that play alike
## share one and a bot can tell so at a glance.
func _shared(rules: RuleSet) -> RuleSet:
	for built: RuleSet in _rules:
		if built.same_as(rules):
			return built
	return rules


## Where one side of a bomb starts in the caches: the trick as it stands comes first.
func _side(bombed: bool) -> int:
	return 0 if bombed == _trick_bombed else Seats.COUNT
