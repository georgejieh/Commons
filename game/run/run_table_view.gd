class_name RunTableView
extends RefCounted
## The round in play as the player sees it: their seat's view and cards, the rules
## they play under, the moves and readings open to them and what a play would score.
## Every card and list is a copy. RunController builds it over each run it attaches,
## as controller.table.

var _loop: RunLoop


func _init(loop: RunLoop) -> void:
	_loop = loop


## The player's seat view of the current round, or null between rounds.
func seat_view() -> SeatView:
	return _loop.player_view()


## Copies of the player's cards.
func player_cards() -> Array[CardInstance]:
	return _loop.player_cards()


## The deck card in slot as the round in play was dealt it, with its saved marks, for a
## view that shows a card it holds only the ID of, as the kitty.
func deck_card(slot: int) -> CardInstance:
	var card: CardInstance = _loop.state.deck.card(slot)
	var one: Array[CardInstance] = [card]
	_loop.state.card_marks.apply(one)
	return card


## The cards the round's deal set aside face up (ADR 0043), named and joined, or "" when
## it set none aside.
func set_aside_names() -> String:
	var names: PackedStringArray = []
	for card: CardInstance in _loop.set_aside_cards():
		names.append(CardName.of(card))
	return ", ".join(names)


## The rules and rank order the player plays under.
func player_table() -> BotTable:
	return _loop.seat_table(RunLoop.PLAYER)


## True while a bomb may hold five or more cards (Industrialization).
func big_bombs() -> bool:
	return player_table().rules.five_plus_is_bomb()


## True while the villagers see the player's hand (Glass Walls).
func hand_shown() -> bool:
	return _loop.round_state() != null and player_table().rules.hand_shown()


## The ranks wild now (ADR 0029), in the order they were drawn: the player's alone, since
## every item that draws one is the player's (ADR 0039).
func wild_ranks() -> Array[int]:
	return _loop.state.wild_ranks.duplicate()


## The seat that has called or grabbed the landlord seat in the bidding under way, or
## Seats.NONE while nobody has, or outside bidding.
func bid_holder() -> int:
	return _loop.bid_holder()


## The most cards the player may swap this round.
func swap_limit() -> int:
	return _loop.swap_limit()


## The legal moves when the player must play, else none.
func legal_moves() -> Array[Pattern]:
	if _loop.awaiting() != RunLoop.Awaiting.PLAYER_PLAY:
		return []
	return _loop.round_state().legal_moves()


## Every reading the player's chosen cards may be played as now, strongest first (ADR
## 0029). More than one only when a wild card is among them; none when the cards form no
## play that may be made now, or between rounds.
func readings_for(card_ids: Array[int]) -> Array[Pattern]:
	var none: Array[Pattern] = []
	if _loop.round_state() == null:
		return none
	var read: PlayReading = _loop.round_state().read_play(RunLoop.PLAYER, card_ids.duplicate())
	var result: Array[Pattern] = []
	for reading: Pattern in read.readings:
		result.append(reading.copy())
	return result


## The player's card IDs for a pattern, by the fixed selection policy.
func card_ids_for(pattern: Pattern) -> Array[int]:
	return _loop.round_state().action_for(pattern).card_ids.duplicate()


## How the player's chosen cards read and what they would score now, or null between
## rounds, as reading when one is named. A preview changes nothing.
func preview_play(card_ids: Array[int], reading: Pattern = null) -> PlayPreview:
	if _loop.round_state() == null:
		return null
	var wanted: Pattern = null if reading == null else reading.copy()
	return _loop.preview_play(card_ids.duplicate(), wanted)


## Why the player may not pass now, as a string key, or "" when they may (Night Shift).
func pass_refusal() -> String:
	if _loop.awaiting() != RunLoop.Awaiting.PLAYER_PLAY:
		return ""
	var reason: RoundState.Reason = _loop.round_state().pass_reason()
	return "table.must_play" if reason == RoundState.Reason.MUST_PLAY else ""
