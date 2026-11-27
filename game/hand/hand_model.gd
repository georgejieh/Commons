class_name HandModel
extends RefCounted
## The player's hand as both table views see it: which cards are selected, how the
## selection reads, what it would score, and the play a hint offers. Selection is local;
## playing it goes through RunController.

signal changed

const KEY_SELECT: String = "hand.reason.select"
const KEY_WAIT: String = "hand.reason.wait"
const KEY_DOES_NOT_BEAT: String = "hand.reason.does_not_beat"
const KEY_DOES_NOT_BEAT_FOLDED: String = "hand.reason.does_not_beat_folded"
const KEY_INVALID_PREFIX: String = "hand.reason."
const KEY_PATTERN_PREFIX: String = "pattern."

var _controller: RunController
var _cards: Array[CardInstance] = []
var _selected: Dictionary[int, bool] = {}
var _preview: PlayPreview = null
## The play the last hint offered, its reading and its cards, so Play plays the reading the
## hint meant while the selection is still the hint's (ADR 0029).
var _hint: Pattern = null
var _hint_ids: Array[int] = []
var _hint_turn: int = -1
## The bot whose play the hint offers and whose grouping orders the hand.
var _hinter: BotConfig = BotConfig.new(BotConfig.DEFAULT_WEIGHTS, BotConfig.Tier.MEDIUM)


## The rank a rank folds into when a debuff ranks it as another, such as a 2 that ranks as
## a 3, or -1 when it ranks as itself. A reordering alone, with no two ranks equal, folds
## nothing.
static func fold(rank: int, mapping: PackedByteArray) -> int:
	if rank >= mapping.size() or mapping[rank] == rank:
		return -1
	for other: int in mapping.size():
		if other != rank and mapping[other] == mapping[rank]:
			return other
	return -1


func _init(controller: RunController) -> void:
	_controller = controller


## Reads the player's cards again, keeping the selection of cards still held.
func refresh() -> void:
	_cards = _controller.table.player_cards()
	var held: Dictionary[int, bool] = {}
	for card: CardInstance in _cards:
		if _selected.has(card.id()):
			held[card.id()] = true
	_selected = held
	_update()


func cards() -> Array[CardInstance]:
	return _cards


func is_selected(card_id: int) -> bool:
	return _selected.has(card_id)


func toggle(card_id: int) -> void:
	set_selected(card_id, not _selected.has(card_id))


func set_selected(card_id: int, on: bool) -> void:
	if not _holds(card_id) or _selected.has(card_id) == on:
		return
	if on:
		_selected[card_id] = true
	else:
		_selected.erase(card_id)
	_update()


func clear() -> void:
	if _selected.is_empty():
		return
	_selected.clear()
	_update()


## Selected card IDs in hand order.
func selected_ids() -> Array[int]:
	var ids: Array[int] = []
	for card: CardInstance in _cards:
		if _selected.has(card.id()):
			ids.append(card.id())
	return ids


func can_play() -> bool:
	return _preview != null and _preview.can_play()


func can_pass() -> bool:
	var view: SeatView = _controller.table.seat_view()
	return (
		_controller.awaiting() == RunLoop.Awaiting.PLAYER_PLAY
		and view != null
		and view.public.current_play != null
	)


## The pattern name when the selection forms one, else the reason Play is off.
func label_key() -> String:
	if _selected.is_empty():
		return KEY_SELECT
	if _preview == null:
		return KEY_WAIT
	var reading: PlayReading = _preview.reading
	if reading.pattern == null or reading.reason != RoundState.Reason.OK:
		return _refusal_key(reading)
	var type_name: String = Pattern.Type.keys()[reading.pattern.type]
	return KEY_PATTERN_PREFIX + type_name.to_lower()


## How the selection reads and scores now, or null with nothing chosen.
func preview() -> PlayPreview:
	return _preview


## Where each rank counts now, after any Cadre or debuff has re-ranked it, indexed by rank.
## Read it once for a sort, not once per card.
func rank_map() -> PackedByteArray:
	return _controller.table.player_table().rank_map


## Selects the hint's play and keeps the reading it meant. Returns its cards, or none
## when the hint is to pass.
func take_hint() -> Array[int]:
	var play: Pattern = _suggested_play()
	_hint = play
	_hint_ids.clear()
	if play != null:
		_hint_ids = _controller.table.card_ids_for(play)
		_hint_ids.sort()
		_hint_turn = _plays_so_far()
	select_only(_hint_ids)
	return _hint_ids.duplicate()


## The reading the last hint meant while the selection is still its cards on the same
## turn, else null.
func hint_reading() -> Pattern:
	if _hint == null or _hint_turn != _plays_so_far():
		return null
	var ids: Array[int] = selected_ids()
	ids.sort()
	return _hint if ids == _hint_ids else null


## Selects exactly these cards.
func select_only(ids: Array[int]) -> void:
	_selected.clear()
	for card_id: int in ids:
		if _holds(card_id):
			_selected[card_id] = true
	_update()


## The cards in suggested play order: the hand split into its fewest plays, each
## group's cards together, lowest rank first within the leftovers.
func grouped_cards() -> Array[CardInstance]:
	var counts: PackedByteArray = PackedByteArray()
	counts.resize(Ranks.COUNT)
	var left: Array[CardInstance] = _cards.duplicate()
	left.sort_custom(
		func(a: CardInstance, b: CardInstance) -> bool: return a.base_rank() < b.base_rank()
	)
	for card: CardInstance in left:
		counts[card.base_rank()] += 1
	var ordered: Array[CardInstance] = []
	for group: Pattern in Bot.suggest_groups(counts, _controller.table.player_table(), _hinter):
		var needed: PackedByteArray = group.spent_counts()
		for card: CardInstance in left.duplicate():
			if needed[card.base_rank()] > 0:
				needed[card.base_rank()] -= 1
				ordered.append(card)
				left.erase(card)
	ordered.append_array(left)
	return ordered


## The play a Medium bot would make now, or null for a pass or when it isn't the player's
## turn.
func _suggested_play() -> Pattern:
	var view: SeatView = _controller.table.seat_view()
	var legal: Array[Pattern] = _controller.table.legal_moves()
	if view == null or legal.is_empty():
		return null
	var play: BotPlay = Bot.decide_play(
		view, legal, _controller.table.player_table(), _hinter, BotBudget.unlimited()
	)
	return null if play.is_pass() else play.pattern


## Plays and passes made so far this round, which tells one turn from the next.
func _plays_so_far() -> int:
	var view: SeatView = _controller.table.seat_view()
	return -1 if view == null else view.public.history.size()


## Why a selection can't be played now. Cards that no longer read, such as cards
## just played, wait rather than name a key the table lacks.
func _refusal_key(reading: PlayReading) -> String:
	if reading.pattern != null:
		if reading.reason != RoundState.Reason.DOES_NOT_BEAT:
			return KEY_WAIT
		return KEY_DOES_NOT_BEAT_FOLDED if _any_folded() else KEY_DOES_NOT_BEAT
	if reading.invalid_reason == Classification.Reason.OK:
		return KEY_WAIT
	var reason: String = Classification.Reason.keys()[reading.invalid_reason]
	return KEY_INVALID_PREFIX + reason.to_lower()


func _any_folded() -> bool:
	var map: PackedByteArray = rank_map()
	for card: CardInstance in _cards:
		if _selected.has(card.id()) and HandModel.fold(card.base_rank(), map) >= 0:
			return true
	return false


func _holds(card_id: int) -> bool:
	return _cards.any(func(card: CardInstance) -> bool: return card.id() == card_id)


func _update() -> void:
	_preview = null
	if not _selected.is_empty() and _controller.table.seat_view() != null:
		_preview = _controller.table.preview_play(selected_ids(), hint_reading())
	changed.emit()
