class_name ScriptedVillager
extends RefCounted
## A villager whose every decision is authored (ADR 0026): the arrival's Wang and Zhao.
## Bot asks it for a bid, a play and a need, as it asks a thinking bot, and it answers
## the next one its round's script holds. A scripted play that is not legal when its turn
## comes, or a script that runs out, is a fault: it is counted for the run's refused bot
## actions, so a test fails on it, and the seat plays a legal pass, or its lowest legal
## play when it leads.

## Called once per fault.
var on_fault: Callable = Callable()

var _seat: int
var _script: TutorialSeat = null
var _bid: int = 0
var _play: int = 0
var _need: int = 0


func _init(seat: int) -> void:
	_seat = seat


## Starts a round from its script. A script left unfinished by the last round is a fault.
func start(script: TutorialSeat) -> void:
	if _script != null and not finished():
		_fault("moves left over from the last round")
	_script = script
	_bid = 0
	_play = 0
	_need = 0


## True when every authored decision of the round has been asked for.
func finished() -> bool:
	if _script == null:
		return true
	var all_bids: bool = _bid >= _script.bids.size()
	return all_bids and _play >= _script.plays.size() and _need >= _script.needs.size()


func bid() -> bool:
	if _script == null or _bid >= _script.bids.size():
		_fault("no bid left")
		return false
	_bid += 1
	return _script.bids[_bid - 1] != 0


## The authored play, matched to the legal move with the same ranks.
func play(view: SeatView, legal: Array[Pattern]) -> BotPlay:
	if _script == null or _play >= _script.plays.size():
		_fault("no play left")
		return _fallback(view, legal)
	var cards: PackedInt32Array = _script.plays[_play]
	_play += 1
	if cards.is_empty():
		if view.public.current_play == null:
			_fault("a pass on the lead")
			return _fallback(view, legal)
		return BotPlay.new(Pattern.pass_play(), BotRationale.Code.NONE)
	var counts: PackedByteArray = PackedByteArray()
	counts.resize(Ranks.COUNT)
	for card_id: int in cards:
		var held: CardInstance = _held(view, card_id)
		if held == null:
			_fault("a card it does not hold, %d" % card_id)
			return _fallback(view, legal)
		counts[held.base_rank()] += 1
	for move: Pattern in legal:
		if move.spent_counts() == counts:
			return BotPlay.new(move, BotRationale.Code.NONE)
	_fault("an illegal play %s" % str(cards))
	return _fallback(view, legal)


func need(true_need: int) -> int:
	if _script == null or _need >= _script.needs.size():
		_fault("no need left")
		return true_need
	_need += 1
	return _script.needs[_need - 1]


## A legal pass when following, or the lowest legal play when leading.
func _fallback(view: SeatView, legal: Array[Pattern]) -> BotPlay:
	if view.public.current_play != null or legal.is_empty():
		return BotPlay.new(Pattern.pass_play(), BotRationale.Code.NONE)
	return BotPlay.new(legal[0], BotRationale.Code.NONE)


func _fault(what: String) -> void:
	push_error("Scripted villager in seat %d: %s" % [_seat, what])
	if on_fault.is_valid():
		on_fault.call()


## The seat's own card with the ID, or null when it holds none.
static func _held(view: SeatView, card_id: int) -> CardInstance:
	for card: CardInstance in view.own_cards:
		if card.id() == card_id:
			return card
	return null
