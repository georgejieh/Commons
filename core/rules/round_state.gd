class_name RoundState
extends RefCounted
## One round of play. apply() is the only way to change it: it validates an action and
## either applies it, emitting events, or returns a reason code and changes nothing.

enum Reason {
	OK,
	ROUND_OVER,
	OUT_OF_TURN,
	CANNOT_PASS_ON_LEAD,
	UNKNOWN_CARD,
	REPEATED_CARD,
	ILLEGAL_PLAY,
	DOES_NOT_BEAT,
}

const ANNOUNCE_AT: Array[int] = [2, 1]
const PASSES_TO_RESET: int = 2

var _hands: Array[Hand]
var _kitty: Array[CardInstance]
var _landlord: int
var _rules: RuleSet
var _rank_map: PackedByteArray
var _turn: int
## The play to beat, or null when the seat to act leads.
var _current: Pattern = null
var _trick_leader: int = Seats.NONE
var _passes: int = 0
var _plays_by_seat: PackedInt32Array = PackedInt32Array([0, 0, 0])
var _winner: int = Seats.NONE
var _events: Array[RoundEvent] = []
var _history: Array[PublicPlay] = []
var _announced: PackedInt32Array = PackedInt32Array([0, 0, 0])


## The landlord takes the kitty and leads.
func _init(deal: DealResult, landlord: int, rules: RuleSet, rank_map: PackedByteArray) -> void:
	_hands = deal.hands
	_kitty = deal.kitty
	_landlord = landlord
	_rules = rules
	_rank_map = rank_map
	_turn = landlord
	_events.append(RoundEvent.new(RoundEvent.Type.ROUND_STARTED, landlord))
	var kitty_ids: Array[int] = []
	for card: CardInstance in _kitty:
		_hands[landlord].add(card)
		kitty_ids.append(card.id())
	_events.append(RoundEvent.new(RoundEvent.Type.KITTY_TAKEN, landlord, kitty_ids))


func apply(action: RoundAction) -> Reason:
	if is_over():
		return Reason.ROUND_OVER
	if action.seat != _turn:
		return Reason.OUT_OF_TURN
	if action.card_ids.is_empty():
		return _apply_pass()
	return _apply_play(action)


func is_over() -> bool:
	return _winner != Seats.NONE


func winner() -> int:
	return _winner


func landlord() -> int:
	return _landlord


func landlord_won() -> bool:
	return _winner == _landlord


func seat_to_act() -> int:
	return Seats.NONE if is_over() else _turn


func current_play() -> Pattern:
	return _current


func events() -> Array[RoundEvent]:
	return _events.duplicate()


## Lists what the seat to act may play. A follower may also pass.
func legal_moves() -> Array[Pattern]:
	var hand: Hand = _hands[_turn]
	return MoveGenerator.generate(hand.counts(), hand.rank_mask(), _current, _rules, _rank_map)


func hand_for_selection() -> Hand:
	return _hands[_turn]


## Cards in hand for every seat, which is all that is public about them.
func remaining() -> PackedInt32Array:
	var sizes: PackedInt32Array = PackedInt32Array()
	for hand: Hand in _hands:
		sizes.append(hand.size())
	return sizes


func public_view() -> PublicView:
	return PublicView.new(
		_landlord, seat_to_act(), remaining(), _history, _kitty, _current, _announced
	)


## What one seat may know: the public view plus its own hand.
func view_for(seat: int) -> SeatView:
	return SeatView.new(seat, public_view(), _hands[seat].counts(), _hands[seat].cards())


func _apply_pass() -> Reason:
	if _current == null:
		return Reason.CANNOT_PASS_ON_LEAD
	var seat: int = _turn
	_events.append(RoundEvent.new(RoundEvent.Type.PASSED, seat))
	_history.append(PublicPlay.new(seat, Pattern.pass_play(), PackedByteArray()))
	_passes += 1
	_turn = Seats.next(_turn)
	if _passes == PASSES_TO_RESET:
		_events.append(RoundEvent.new(RoundEvent.Type.TRICK_WON, _trick_leader))
		_current = null
		_passes = 0
		_turn = _trick_leader
	return Reason.OK


func _apply_play(action: RoundAction) -> Reason:
	var hand: Hand = _hands[_turn]
	var cards: Array[CardInstance] = []
	var seen: Dictionary[int, bool] = {}
	for card_id: int in action.card_ids:
		if seen.has(card_id):
			return Reason.REPEATED_CARD
		seen[card_id] = true
		var card: CardInstance = hand.find(card_id)
		if card == null:
			return Reason.UNKNOWN_CARD
		cards.append(card)

	var reading: Classification = CardSelection.classify_cards(cards, _rules, _rank_map)
	if not reading.is_valid():
		return Reason.ILLEGAL_PLAY
	if _current != null and not PlayComparator.beats(reading.pattern, _current, _rules):
		return Reason.DOES_NOT_BEAT
	_commit_play(action.card_ids, reading.pattern)
	return Reason.OK


func _commit_play(card_ids: Array[int], pattern: Pattern) -> void:
	var seat: int = _turn
	var hand: Hand = _hands[seat]
	for card_id: int in card_ids:
		hand.remove(card_id)
	_plays_by_seat[seat] += 1
	_events.append(RoundEvent.new(RoundEvent.Type.PLAYED, seat, card_ids.duplicate(), pattern))
	_history.append(PublicPlay.new(seat, pattern, pattern.counts()))
	_current = pattern
	_trick_leader = seat
	_passes = 0
	if ANNOUNCE_AT.has(hand.size()):
		_announced[seat] = hand.size()
		_events.append(RoundEvent.new(RoundEvent.Type.ANNOUNCED, seat, [], null, hand.size()))
	if hand.size() == 0:
		_finish(seat)
	else:
		_turn = Seats.next(_turn)


func _finish(seat: int) -> void:
	_winner = seat
	var finish: RoundEvent.Finish = _finish_kind()
	_events.append(RoundEvent.new(RoundEvent.Type.ROUND_ENDED, seat, [], null, finish))


func _finish_kind() -> RoundEvent.Finish:
	if landlord_won():
		var peasant_plays: int = 0
		for seat: int in Seats.COUNT:
			if seat != _landlord:
				peasant_plays += _plays_by_seat[seat]
		return RoundEvent.Finish.SPRING if peasant_plays == 0 else RoundEvent.Finish.NORMAL
	var one_play: bool = _plays_by_seat[_landlord] == 1
	if one_play and _rules.anti_spring_doubles():
		return RoundEvent.Finish.ANTI_SPRING
	return RoundEvent.Finish.NORMAL
