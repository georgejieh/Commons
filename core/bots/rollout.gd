class_name Rollout
extends RefCounted
## Plays one sampled deal to the end on count vectors, with the same bot policy at each
## seat. It is a sketch of the round for search, never the round itself.

var _hands: Array[PackedByteArray]
var _landlord: int
var _turn: int
var _current: Pattern
var _owner: int
var _passes: int
var _table: BotTable
var _config: BotConfig


func _init(
	hands: Array[PackedByteArray],
	landlord: int,
	turn: int,
	current: Pattern,
	owner: int,
	passes: int,
	table: BotTable,
	config: BotConfig
) -> void:
	_hands = hands
	_landlord = landlord
	_turn = turn
	_current = current
	_owner = owner
	_passes = passes
	_table = table
	_config = config


## Applies a move for the seat to act. A pass pattern passes.
func step(move: Pattern) -> void:
	if move.type == Pattern.Type.PASS:
		_passes += 1
		if _passes == RoundState.PASSES_TO_RESET:
			_current = null
			_passes = 0
	else:
		var used: PackedByteArray = move.counts()
		for rank: int in Ranks.COUNT:
			_hands[_turn][rank] -= used[rank]
		_current = move
		_owner = _turn
		_passes = 0
	_turn = Seats.next(_turn)


## Returns the seat that went out, or Seats.NONE if the limit ran out.
func play_out(step_limit: int) -> int:
	for _step: int in step_limit:
		var winner: int = _finished()
		if winner != Seats.NONE:
			return winner
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
	var legal: Array[Pattern] = MoveGenerator.generate(
		counts, mask, _current, _table.rules, _table.rank_map
	)
	return Bot.decide_play(_view(), legal, _table, _config, BotBudget.unlimited()).pattern


func _view() -> SeatView:
	var sizes: PackedInt32Array = PackedInt32Array()
	for hand: PackedByteArray in _hands:
		var size: int = 0
		for rank: int in Ranks.COUNT:
			size += hand[rank]
		sizes.append(size)
	var history: Array[PublicPlay] = []
	if _current != null:
		history.append(PublicPlay.new(_owner, _current, _current.counts()))
	var no_cards: Array[CardInstance] = []
	var public: PublicView = PublicView.new(
		_landlord, _turn, sizes, history, no_cards, _current, PackedInt32Array([0, 0, 0])
	)
	return SeatView.new(_turn, public, _hands[_turn].duplicate(), no_cards)
