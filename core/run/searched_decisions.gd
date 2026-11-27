class_name SearchedDecisions
extends RefCounted
## How a run's searching villagers decide their plays (ADR 0030). Live, a searching seat
## asks the searcher the game hands in, or with none searches with no limit, as every
## tool does. Every play a searching seat makes is written to the run record. A replay
## takes them back from the record in order, and one that no longer fits fails the replay
## on its own path, never through the round's fallback for an illegal bot action. A list
## that ends inside the record's last command is a save written at a boundary before
## those villagers played, and they decide then as they would have. When the game answers
## searches from outside (ADR 0030), the loop stands still for each live one instead of
## asking the searcher.

## How a searching seat's play is decided: live, from written decisions, or from an older record.
enum Mode {
	## Decides by the searcher, or with no limit when there is none.
	LIVE,
	## Replays the record's written decisions.
	WRITTEN,
	## Replays a record from before decisions were written, with no limit, as it was made.
	UNWRITTEN,
}

## The fields of one written decision: the villager's seat and the card IDs it played,
## none for a pass.
const DECISION_FIELDS: Array[String] = ["seat", "cards"]

## Takes a SeatView, the legal moves, a BotTable and a BotConfig, as Bot.decide_play does
## but for the budget, and returns a BotPlay. Unset, a searching seat searches with no
## limit.
var searcher: Callable = Callable()
## Weights a searching seat decides with in place of its own, so a tool can sample fewer
## deals; null for its own. The seat's config gets its own back after each decision.
var weights: BotWeights = null
## True when the game answers a searching seat's live plays from outside the loop (ADR 0030):
## the loop then stands still for each, as it does for the player, and is handed the play.
## Off, as for every tool and test, the loop asks the searcher itself.
var answered_outside: bool = false

var _record: RunRecord
var _mode: Mode = Mode.LIVE
var _written: Array[Dictionary] = []
var _next: int = 0
## Saved commands the replay has yet to start. At none, the last one is being replayed.
var _commands_left: int = 0
var _failed: bool = false


func _init(record: RunRecord) -> void:
	_record = record


## True for a seat whose plays are searched: a searching tier, never a scripted villager.
static func searches(config: BotConfig) -> bool:
	return config.scripted == null and config.searches()


## True when a saved list of decisions and its marker have the shape a record writes:
## a marker that is true or false, and with it true, each entry a villager's seat and the
## whole card IDs it played. A record marked unwritten holds none.
static func is_valid(decisions: Variant, written: Variant) -> bool:
	if not decisions is Array or not written is bool:
		return false
	var entries: Array = decisions
	if not written and not entries.is_empty():
		return false
	for entry: Variant in entries:
		if not entry is Dictionary or not _is_decision(entry):
			return false
	return true


static func _is_decision(entry: Dictionary) -> bool:
	var reading: bool = entry.has(ReadingCodec.KEY)
	if entry.size() != DECISION_FIELDS.size() + (1 if reading else 0):
		return false
	if reading and not ReadingCodec.is_valid(entry[ReadingCodec.KEY]):
		return false
	var seat: Variant = entry.get("seat")
	if not RunState.is_whole(seat) or seat < 1 or seat >= Seats.COUNT:
		return false
	if not entry.get("cards") is Array:
		return false
	for card: Variant in entry["cards"]:
		if not RunState.is_whole(card) or card < 0:
			return false
	return true


## True once a replayed decision did not fit; the loop then stands still.
func failed() -> bool:
	return _failed


## Replays written in place of searching until end_replay(), over a record of this many
## commands. A record from before decisions were written replays with no limit, as it
## was made.
func begin_replay(written: Array[Dictionary], is_written: bool, commands: int) -> void:
	_mode = Mode.WRITTEN if is_written else Mode.UNWRITTEN
	_written = written
	_next = 0
	_commands_left = commands


## Called as each saved command's replay starts.
func next_command() -> void:
	_commands_left -= 1


## Ends the replay and goes live. False when it failed or left written decisions unused.
func end_replay() -> bool:
	if _mode == Mode.WRITTEN and _next != _written.size():
		_failed = true
	_mode = Mode.LIVE
	return not _failed


## True when this seat's next play comes from the record.
func replays(config: BotConfig) -> bool:
	return _mode == Mode.WRITTEN and not _past_the_record() and searches(config)


## True once the list has ended inside the record's last command. The game saves at
## every state move, and one inside a command comes before the villagers that command
## sets playing: their plays were never written or shown, so they are decided now.
func _past_the_record() -> bool:
	return _commands_left <= 0 and _next >= _written.size()


## Plays seat's next written decision in round and writes it to the new record. False,
## and failed() from then on, when there is none left, it is for another seat, or it is
## not a legal play there.
func replay(round_state: RoundState, seat: int) -> bool:
	if _next >= _written.size() or int(_written[_next]["seat"]) != seat:
		_failed = true
		return false
	var cards: Array[int] = []
	for card: Variant in _written[_next]["cards"]:
		cards.append(int(card))
	var action: RoundAction = RoundAction.new(seat, cards)
	action.reading = ReadingCodec.decode(_written[_next].get(ReadingCodec.KEY))
	if round_state.apply(action) != RoundState.Reason.OK:
		_failed = true
		return false
	_next += 1
	_record.decide(seat, cards, action.reading)
	return true


## The seat's play: a searching seat's live from the searcher, every other one with no
## limit.
func decide(view: SeatView, legal: Array[Pattern], table: BotTable, config: BotConfig) -> BotPlay:
	if not searches(config):
		return Bot.decide_play(view, legal, table, config, BotBudget.unlimited())
	var own: BotWeights = config.weights
	if weights != null:
		config.weights = weights
	var play: BotPlay
	if _live() and searcher.is_valid() and not legal.is_empty():
		play = searcher.call(view, legal, table, config)
	else:
		play = Bot.decide_play(view, legal, table, config, BotBudget.unlimited())
	config.weights = own
	return play


## True when the loop stands still for this seat's play to be answered from outside: a
## searching seat deciding live with moves to choose from, while searches are answered
## outside. A seat with no move passes, and a replay reads the record.
func stands_for(config: BotConfig, legal: Array[Pattern]) -> bool:
	return answered_outside and searches(config) and _live() and not legal.is_empty()


## What the search for a seat the loop stands still for reads, with the weights handed
## in, if any, in place of the seat's own.
func request(
	seat: int, view: SeatView, legal: Array[Pattern], table: BotTable, config: BotConfig
) -> SearchRequest:
	var made: SearchRequest = SearchRequest.new(seat, view, legal, table, config)
	if weights != null:
		made.config.weights = weights
	return made


## True while a searching seat's play is decided now, not read from the record.
func _live() -> bool:
	return _mode == Mode.LIVE or (_mode == Mode.WRITTEN and _past_the_record())


## Writes the cards a searching seat played, none for a pass, to the record, with the
## reading when those cards read more than one way.
func write(seat: int, config: BotConfig, card_ids: Array[int], reading: Pattern = null) -> void:
	if searches(config):
		_record.decide(seat, card_ids, reading)
