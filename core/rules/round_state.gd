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
	## A pass refused on the seat's first chance to pass while it holds a play that beats
	## the table (Night Shift, ADR 0023).
	MUST_PLAY,
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
## Where the play on the table sits in the history.
var _leader_entry: int = 0
var _passes: int = 0
var _plays_by_seat: PackedInt32Array = PackedInt32Array()
var _winner: int = Seats.NONE
var _events: Array[RoundEvent] = []
var _history: Array[PublicPlay] = []
var _announced: PackedInt32Array = PackedInt32Array()
## 1 once a seat has answered a play on the table this round, played or passed.
var _answered: PackedByteArray = PackedByteArray()
## What each seat knows the round's cards to be, rank by rank: the deck as dealt, and for
## a seat that swapped with its plot, less the cards it set aside and with those it brought
## in (ADR 0042). Every seat shares the dealt counts until it swaps.
var _known_counts: Array[PackedByteArray] = []


## The landlord takes the kitty and leads.
func _init(deal: DealResult, landlord: int, table: SeatRules) -> void:
	for dealt: Hand in deal.hands:
		var hand: Hand = Hand.new()
		for card: CardInstance in dealt.cards():
			hand.add(card)
		_hands.append(hand)
	_kitty = deal.kitty.duplicate()
	for _seat: int in Seats.COUNT:
		_known_counts.append(deal.deck_counts)
	_plays_by_seat.resize(Seats.COUNT)
	_announced.resize(Seats.COUNT)
	_answered.resize(Seats.COUNT)
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
	_sync_rules()
	if action.seat != _turn:
		return Reason.OUT_OF_TURN
	var answering: bool = _current != null
	var reason: Reason = _apply_pass() if action.card_ids.is_empty() else _apply_play(action)
	if reason == Reason.OK and answering:
		_answered[action.seat] = 1
	return reason


## Whether the seat to act may pass now: OK, or why not. A seat whose rules make it
## answer once must play on its first chance to pass when anything beats the table; with
## nothing that does, it passes as usual and the rule is spent for the round.
func pass_reason() -> Reason:
	if is_over():
		return Reason.ROUND_OVER
	if _current == null:
		return Reason.CANNOT_PASS_ON_LEAD
	_sync_rules()
	if _table.rules_for(_turn).must_answer_once() and _answered[_turn] == 0:
		if not legal_moves().is_empty():
			return Reason.MUST_PLAY
	return Reason.OK


## Before anyone plays, trades cards in a seat's hand for others one for one: the
## plot swap (ADR 0038). A kitty card taken out leaves the public kitty, as in trade().
## The cards taken out are out of the round, and only the seat knows which they were and
## which came in, so only its own count of the round's cards changes. Returns the cards
## taken out, in the order of out_ids.
func exchange(seat: int, out_ids: Array[int], cards_in: Array[CardInstance]) -> Array[CardInstance]:
	assert(_history.is_empty(), "Cards change hands only before the first play")
	var taken: Array[CardInstance] = _take(seat, out_ids)
	var known: PackedByteArray = _known_counts[seat].duplicate()
	for card: CardInstance in taken:
		known[card.base_rank()] -= 1
	for card: CardInstance in cards_in:
		_hands[seat].add(card)
		known[card.base_rank()] += 1
	_known_counts[seat] = known
	return taken


## Moves cards between two seats one for one at any point of the round (a Campaign's
## trade or seizure), so no hand changes size and the public counts stay true. A kitty
## card that leaves the landlord's hand is no longer known to be there, so it leaves the
## public kitty too. Returns UNKNOWN_CARD or REPEATED_CARD and changes nothing when a
## card is not in its seat's hand.
func trade(seat_a: int, ids_a: Array[int], seat_b: int, ids_b: Array[int]) -> Reason:
	if is_over():
		return Reason.ROUND_OVER
	if ids_a.size() != ids_b.size() or seat_a == seat_b:
		return Reason.ILLEGAL_PLAY
	for side: Array in [[seat_a, ids_a], [seat_b, ids_b]]:
		var seen: Dictionary[int, bool] = {}
		for card_id: int in side[1]:
			if seen.has(card_id):
				return Reason.REPEATED_CARD
			if _hands[side[0]].find(card_id) == null:
				return Reason.UNKNOWN_CARD
			seen[card_id] = true
	var from_a: Array[CardInstance] = _take(seat_a, ids_a)
	var from_b: Array[CardInstance] = _take(seat_b, ids_b)
	for card: CardInstance in from_a:
		_hands[seat_b].add(card)
	for card: CardInstance in from_b:
		_hands[seat_a].add(card)
	return Reason.OK


## Hands the live card in a seat's hand to edit, which marks it through CardModifiers.
## False when the seat does not hold the card.
func mark(seat: int, card_id: int, edit: Callable) -> bool:
	var card: CardInstance = _hands[seat].find(card_id)
	if card == null:
		return false
	edit.call(card)
	return true


func _take(seat: int, card_ids: Array[int]) -> Array[CardInstance]:
	var taken: Array[CardInstance] = []
	for card_id: int in card_ids:
		taken.append(_hands[seat].remove(card_id))
		if seat == _landlord:
			for index: int in range(_kitty.size() - 1, -1, -1):
				if _kitty[index].id() == card_id:
					_kitty.remove_at(index)
	return taken


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


## The seat whose play is on the table, or Seats.NONE when the seat to act leads.
func trick_owner() -> int:
	return _trick_leader if _current != null else Seats.NONE


func events() -> Array[RoundEvent]:
	return _events.duplicate()


## Lists what the seat to act may play. A follower may also pass.
func legal_moves() -> Array[Pattern]:
	_sync_rules()
	var hand: Hand = _hands[_turn]
	var rules: RuleSet = _table.rules_for(_turn)
	var standing: PackedByteArray = _table.standing_for(_turn)
	return MoveGenerator.generate(hand.counts(), hand.rank_mask(), _current, rules, standing)


## Turns a pattern into an action for the seat to act, using its least valuable cards of
## the ranks it spends, and naming its reading.
func action_for(pattern: Pattern) -> RoundAction:
	var action: RoundAction = RoundAction.from_cards(
		_turn, CardSelection.pick(_hands[_turn], pattern)
	)
	action.reading = pattern
	return action


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


## What one seat may know: the public view plus its own hand, and any other hand whose
## rules show it to the table.
func view_for(seat: int) -> SeatView:
	var cards: Array[CardInstance] = []
	for card: CardInstance in _hands[seat].cards():
		cards.append(card.snapshot())
	var view: SeatView = SeatView.new(
		seat, public_view(), _hands[seat].counts(), cards, _known_counts[seat]
	)
	for other: int in Seats.COUNT:
		if other != seat and _table.rules_for(other).hand_shown():
			view.exposed[other] = _hands[other].counts()
	return view


## How the seat's cards read against the table, without playing them. A seat other than
## the one to act gets OUT_OF_TURN with its pattern, so a view can still name it. Cards
## with a wild card among them may read more than one way (ADR 0029): wanted names the
## reading, and with none the strongest that may be played now stands.
func read_play(seat: int, card_ids: Array[int], wanted: Pattern = null) -> PlayReading:
	if is_over():
		return PlayReading.new(Reason.ROUND_OVER)
	_sync_rules()
	var reading: PlayReading = PlayReading.new(Reason.OK)
	var seen: Dictionary[int, bool] = {}
	for card_id: int in card_ids:
		var card: CardInstance = _hands[seat].find(card_id)
		if seen.has(card_id) or card == null:
			reading.reason = Reason.REPEATED_CARD if seen.has(card_id) else Reason.UNKNOWN_CARD
			return reading
		seen[card_id] = true
		reading.cards.append(card)
	var rules: RuleSet = _table.rules_for(seat)
	var counts: PackedByteArray = CardSelection.printed_counts(reading.cards)
	# Keys read standings, so plays of seats with different orders compare (ADR 0039).
	var standing: PackedByteArray = _table.standing_for(seat)
	var classified: Classification = Classifier.classify(counts, rules, standing)
	reading.invalid_reason = classified.reason
	var options: Array[Pattern] = []
	if WildSupply.of(counts, rules) != null:
		options = Readings.of(counts, rules, standing)
	elif classified.is_valid():
		options.append(classified.pattern)
	if options.is_empty():
		reading.reason = Reason.ILLEGAL_PLAY
		return reading
	reading.invalid_reason = Classification.Reason.OK
	for option: Pattern in options:
		if _current == null or PlayComparator.beats(option, _current, rules):
			reading.readings.append(option)
	reading.pattern = options[0] if reading.readings.is_empty() else reading.readings[0]
	if wanted != null:
		reading.pattern = Readings.checked(wanted, counts, rules, standing)
		if reading.pattern == null:
			reading.reason = Reason.ILLEGAL_PLAY
			return reading
	if seat != _turn:
		reading.reason = Reason.OUT_OF_TURN
	elif _current != null and not PlayComparator.beats(reading.pattern, _current, rules):
		reading.reason = Reason.DOES_NOT_BEAT
	return reading


func _apply_pass() -> Reason:
	var allowed: Reason = pass_reason()
	if allowed != Reason.OK:
		return allowed
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
	var reading: PlayReading = read_play(_turn, action.card_ids, action.reading)
	if reading.reason == Reason.OK:
		_commit_play(reading.cards, action.card_ids, reading.pattern)
	return reading.reason


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
	_history.append(PublicPlay.new(seat, pattern.copy(), pattern.spent_counts()))
	_leader_entry = _history.size() - 1
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
	if _current != null:
		_current = _current.rekeyed(_table.standing_for(_trick_leader)[_current.main_rank])
		_history[_leader_entry].pattern = _current.copy()


func _sync_rules() -> void:
	_sync_stamps()
	if _table.refresh():
		_rekey_current()


## Tells the rules which ranks each seat holds only its own stamped cards of, for Class
## Label (ADR 0021). The seat whose play is on the table keeps the mask it played
## under, so emptying a rank by playing it never re-ranks the play it just made.
func _sync_stamps() -> void:
	for seat: int in Seats.COUNT:
		if _current != null and seat == _trick_leader:
			continue
		_table.set_stamped(seat, _stamp_mask(seat))


func _stamp_mask(seat: int) -> int:
	var stamped: int = 0
	var plain: int = 0
	for card: CardInstance in _hands[seat].cards():
		if card.owner_stamp() == seat:
			stamped |= 1 << card.base_rank()
		else:
			plain |= 1 << card.base_rank()
	return stamped & ~plain


func _finish(seat: int) -> void:
	_winner = seat
	_table.set_trick_bombed(false)
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
