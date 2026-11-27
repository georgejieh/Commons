class_name HandModel
extends RefCounted
## The player's hand as both table views see it: which cards are selected, how the
## selection reads, what it would score, and which cards a hint lights. Selection is
## local; playing it goes through RunController.

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


func _init(controller: RunController) -> void:
	_controller = controller


## Reads the player's cards again, keeping the selection of cards still held.
func refresh() -> void:
	_cards = _controller.player_cards()
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
	var view: SeatView = _controller.seat_view()
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


## What the selection would score if played now, or 0 when it forms no pattern.
func projected_score() -> float:
	return 0.0 if _preview == null else _preview.score


## The rank this card counts as when a debuff folds its rank into another, such as a
## 2 that ranks as a 3, or -1 when it ranks as itself. A reordering alone, with no two
## ranks equal, folds nothing.
func folded_rank(card: CardInstance) -> int:
	return HandModel.fold(card.base_rank(), _controller.player_table().rank_map)


## Where the card ranks now, after any Cadre or debuff has re-ranked it.
func rank_value(card: CardInstance) -> int:
	return _controller.player_table().rank_map[card.base_rank()]


static func fold(rank: int, rank_map: PackedByteArray) -> int:
	if rank >= rank_map.size() or rank_map[rank] == rank:
		return -1
	for other: int in rank_map.size():
		if other != rank and rank_map[other] == rank_map[rank]:
			return other
	return -1


## Cards whose rank appears in any legal move. Moves are over ranks, not instances.
func hint_ids() -> Array[int]:
	var ranks: Dictionary[int, bool] = {}
	for move: Pattern in _controller.legal_moves():
		var counts: PackedByteArray = move.counts()
		for rank: int in counts.size():
			if counts[rank] > 0:
				ranks[rank] = true
	var ids: Array[int] = []
	for card: CardInstance in _cards:
		if ranks.has(card.base_rank()):
			ids.append(card.id())
	return ids


## The cards a Medium bot would play now, or none when passing is best or it isn't the
## player's turn.
func suggested_ids() -> Array[int]:
	var none: Array[int] = []
	var view: SeatView = _controller.seat_view()
	var legal: Array[Pattern] = _controller.legal_moves()
	if view == null or legal.is_empty():
		return none
	var config: BotConfig = BotConfig.new(BotConfig.DEFAULT_WEIGHTS, BotConfig.Tier.MEDIUM)
	var play: BotPlay = Bot.decide_play(
		view, legal, _controller.player_table(), config, BotBudget.unlimited()
	)
	if play.is_pass():
		return none
	return _controller.card_ids_for(play.pattern)


## Selects exactly these cards.
func select_only(ids: Array[int]) -> void:
	_selected.clear()
	for card_id: int in ids:
		if _holds(card_id):
			_selected[card_id] = true
	_update()


## The cards in suggested play order: the hand split into its fewest plays (P2.2), each
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
	var config: BotConfig = BotConfig.new(BotConfig.DEFAULT_WEIGHTS, BotConfig.Tier.MEDIUM)
	for group: Pattern in Bot.suggest_groups(counts, _controller.player_table(), config):
		var needed: PackedByteArray = group.counts()
		for card: CardInstance in left.duplicate():
			if needed[card.base_rank()] > 0:
				needed[card.base_rank()] -= 1
				ordered.append(card)
				left.erase(card)
	ordered.append_array(left)
	return ordered


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
	for card: CardInstance in _cards:
		if _selected.has(card.id()) and folded_rank(card) >= 0:
			return true
	return false


func _holds(card_id: int) -> bool:
	return _cards.any(func(card: CardInstance) -> bool: return card.id() == card_id)


func _update() -> void:
	_preview = null
	if not _selected.is_empty() and _controller.seat_view() != null:
		_preview = _controller.preview_play(selected_ids())
	changed.emit()
