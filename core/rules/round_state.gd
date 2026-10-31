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

const PASSES_TO_RESET: int = 2

var _hands: Array[Hand] = []
var _kitty: Array[CardInstance]
var _landlord: int
var _table: SeatRules
var _turn: int
## The play to beat, or null when the seat to act leads.
var _current: Pattern = null
var _trick_leader: int = Seats.NONE
var _passes: int = 0
var _plays_by_seat: PackedInt32Array = PackedInt32Array()
var _winner: int = Seats.NONE
var _events: Array[RoundEvent] = []
var _history: Array[PublicPlay] = []
var _announced: PackedInt32Array = PackedInt32Array()


## The landlord takes the kitty and leads.
func _init(deal: DealResult, landlord: int, table: SeatRules) -> void:
	for dealt: Hand in deal.hands:
		var hand: Hand = Hand.new()
		for card: CardInstance in dealt.cards():
			hand.add(card)
		_hands.append(hand)
	_kitty = deal.kitty.duplicate()
	_plays_by_seat.resize(Seats.COUNT)
	_announced.resize(Seats.COUNT)
	_landlord = landlord
	_table = table
	_table.start_round(landlord)
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
	return null if _current == null else _current.copy()


func events() -> Array[RoundEvent]:
	return _events.duplicate()


## Lists what the seat to act may play. A follower may also pass.
func legal_moves() -> Array[Pattern]:
	var hand: Hand = _hands[_turn]
	return MoveGenerator.generate(
		hand.counts(), hand.rank_mask(), _current, _table.rules_for(_turn), _table.map_for(_turn)
	)


## Turns a pattern into an action for the seat to act, using its least valuable cards.
func action_for(pattern: Pattern) -> RoundAction:
	return RoundAction.from_cards(_turn, CardSelection.pick(_hands[_turn], pattern))


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
	var cards: Array[CardInstance] = []
	for card: CardInstance in _hands[seat].cards():
		cards.append(card.snapshot())
	return SeatView.new(seat, public_view(), _hands[seat].counts(), cards)


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
		_table.set_trick_bombed(false)
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

	var rules: RuleSet = _table.rules_for(_turn)
	var reading: Classification = CardSelection.classify_cards(cards, rules, _table.map_for(_turn))
	if not reading.is_valid():
		return Reason.ILLEGAL_PLAY
	if _current != null and not PlayComparator.beats(reading.pattern, _current, rules):
		return Reason.DOES_NOT_BEAT
	_commit_play(cards, action.card_ids, reading.pattern)
	return Reason.OK


func _commit_play(cards: Array[CardInstance], card_ids: Array[int], pattern: Pattern) -> void:
	var seat: int = _turn
	var hand: Hand = _hands[seat]
	for card_id: int in card_ids:
		hand.remove(card_id)
	_plays_by_seat[seat] += 1
	var logged: Pattern = pattern.copy()
	var event: RoundEvent = RoundEvent.new(
		RoundEvent.Type.PLAYED, seat, card_ids.duplicate(), logged
	)
	for card: CardInstance in cards:
		event.cards.append(card.snapshot())
	_events.append(event)
	_history.append(PublicPlay.new(seat, pattern.copy(), pattern.counts()))
	_current = pattern
	_trick_leader = seat
	_passes = 0
	if pattern.type == Pattern.Type.BOMB:
		_table.set_trick_bombed(true)
		_rekey_current()
	if _table.rules_for(seat).announces_at(hand.size()):
		_announced[seat] = hand.size()
		_events.append(RoundEvent.new(RoundEvent.Type.ANNOUNCED, seat, [], null, hand.size()))
	if hand.size() == 0:
		_finish(seat)
	else:
		_turn = Seats.next(_turn)


## A changed rank map applies to the play on the table too, read in its player's map.
func _rekey_current() -> void:
	_current = _current.rekeyed(_table.map_for(_trick_leader)[_current.main_rank])


func _finish(seat: int) -> void:
	_winner = seat
	_events.append(RoundEvent.new(RoundEvent.Type.TRICK_WON, seat))
	var finish: RoundEvent.Finish = _finish_kind()
	_events.append(RoundEvent.new(RoundEvent.Type.ROUND_ENDED, seat, [], null, finish))


func _finish_kind() -> RoundEvent.Finish:
	if landlord_won():
		var peasant_plays: int = 0
		for seat: int in Seats.COUNT:
			if seat != _landlord:
				peasant_plays += _plays_by_seat[seat]
		return RoundEvent.Finish.SPRING if peasant_plays == 0 else RoundEvent.Finish.NORMAL
	if _plays_by_seat[_landlord] == 1:
		return RoundEvent.Finish.ANTI_SPRING
	return RoundEvent.Finish.NORMAL
