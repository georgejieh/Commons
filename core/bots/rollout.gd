class_name Rollout
extends RefCounted
## Plays one sampled deal to the end on count vectors, with the same bot policy at each
## seat, each under its own rules and order (ADR 0039), and with a bomb turning the trick's
## orders as the round would. It is a sketch of the round for search, never the round
## itself.

var _hands: Array[PackedByteArray]
var _landlord: int
var _turn: int
var _current: Pattern
var _owner: int
var _passes: int
var _table: BotTable
var _config: BotConfig
## The round's cards by rank as the searching seat knows them, which every seat's sketch
## counts unseen cards against.
var _deck_counts: PackedByteArray
var _bombed: bool
## Each seat's table, before a bomb at index seat and after one at COUNT + seat, made the
## first time the seat decides.
var _tables: Array[BotTable] = []


func _init(
	hands: Array[PackedByteArray],
	landlord: int,
	turn: int,
	current: Pattern,
	owner: int,
	passes: int,
	table: BotTable,
	config: BotConfig,
	deck_counts: PackedByteArray
) -> void:
	_hands = hands
	_landlord = landlord
	_turn = turn
	_current = current
	_owner = owner
	_passes = passes
	_table = table
	_config = config
	_deck_counts = deck_counts
	_bombed = table.bombed
	_tables.resize(Seats.COUNT * 2)


## Applies a move for the seat to act. A pass pattern passes.
func step(move: Pattern) -> void:
	if move.type == Pattern.Type.PASS:
		_passes += 1
		if _passes == RoundState.PASSES_TO_RESET:
			_current = null
			_passes = 0
			_bombed = false
	else:
		var used: PackedByteArray = move.spent_counts()
		for rank: int in Ranks.COUNT:
			_hands[_turn][rank] -= used[rank]
		_current = move
		_owner = _turn
		_passes = 0
		if move.type == Pattern.Type.BOMB and not _bombed:
			# As the round rekeys the play on the table once its trick has a bomb.
			_bombed = true
			_current = move.rekeyed(_seat_table(_turn).standing[move.main_rank])
	_turn = Seats.next(_turn)


## Returns the seat that went out, or Seats.NONE if the limit ran out or the
## budget did. A caller that gives a budget throws the result away once it expires.
func play_out(step_limit: int, stop: BotBudget = null) -> int:
	for _step: int in step_limit:
		var winner: int = _finished()
		if winner != Seats.NONE:
			return winner
		if stop != null and stop.is_expired():
			return Seats.NONE
		step(_decide())
	return _finished()


func _finished() -> int:
	for seat: int in Seats.COUNT:
		if UnseenCards.mask_of(_hands[seat]) == 0:
			return seat
	return Seats.NONE


func _decide() -> Pattern:
	var counts: PackedByteArray = _hands[_turn]
	var mask: int = UnseenCards.mask_of(counts)
	var table: BotTable = _seat_table(_turn)
	# Lean, as Bot.considered would leave them, without building the rest (ADR 0029).
	var legal: Array[Pattern] = MoveGenerator.generate(
		counts, mask, _current, table.rules, table.standing, true
	)
	return Bot.decide_play(_view(), legal, table, _config, BotBudget.unlimited()).pattern


func _seat_table(at: int) -> BotTable:
	var index: int = (Seats.COUNT if _bombed else 0) + at
	if _tables[index] == null:
		_tables[index] = _table.as_seat(at, _bombed)
	return _tables[index]


func _view() -> SeatView:
	var sizes: PackedInt32Array = PackedInt32Array()
	for hand: PackedByteArray in _hands:
		var size: int = 0
		for rank: int in Ranks.COUNT:
			size += hand[rank]
		sizes.append(size)
	var history: Array[PublicPlay] = []
	if _current != null:
		history.append(PublicPlay.new(_owner, _current, _current.spent_counts()))
	var no_cards: Array[CardInstance] = []
	var public: PublicView = PublicView.new(
		_landlord, _turn, sizes, history, no_cards, _current, PackedInt32Array([0, 0, 0])
	)
	return SeatView.new(_turn, public, _hands[_turn].duplicate(), no_cards, _deck_counts)
