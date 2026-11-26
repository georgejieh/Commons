class_name KeptSeat
extends RefCounted
## Reads the run's events as they come and says why the round in progress began with no
## bidding, when it did: the landlord won the last round and keeps the seat, or the risen
## villager starts the boss Quota as landlord (the only way a Quota's first round is not
## bid for). The table calls it out and the plot swap sheet prints it, so a player who
## never read the bidding tip knows who holds the seat and why.

## The round last called out, by Quota and round, so a rebuilt table never says it twice.
## A run starting or being left forgets it (forget), so the next run calls its own.
static var said: String = ""

## The landlord of the round in progress, or Seats.NONE between rounds.
var landlord: int = Seats.NONE
var _quota: int = 0
var _round: int = 0
var _bid: bool = false
var _started: bool = false
var _player_acted: bool = false


## Reads one event of the Set, in order.
func read(event: RunEvent) -> void:
	match event.type:
		RunEvent.Type.SET_STARTED:
			_quota = event.value
		RunEvent.Type.DEALT:
			_round = event.value
			_bid = false
			_started = false
			landlord = Seats.NONE
		RunEvent.Type.BID:
			_bid = true
		RunEvent.Type.ROUND:
			_read_round(event.round_event)


func _read_round(event: RoundEvent) -> void:
	if event.type == RoundEvent.Type.ROUND_STARTED:
		_started = true
		_player_acted = false
		landlord = event.seat
	elif event.type == RoundEvent.Type.PLAYED or event.type == RoundEvent.Type.PASSED:
		_player_acted = _player_acted or event.seat == Seats.PLAYER


## True when the round in progress began with no bidding.
func kept() -> bool:
	return _started and not _bid


## True when the round began with no bidding and the player has not yet played in it.
func fresh() -> bool:
	return kept() and not _player_acted


## The round in progress, as said remembers it.
func key() -> String:
	return "%d:%d" % [_quota, _round]


## The callout's big word.
func word() -> String:
	return tr("seat.kept.word")


## Who holds the seat and why, with the villagers' names by seat.
func line(names: Dictionary[int, String]) -> String:
	var name: String = names.get(landlord, "")
	if _round == 0:
		return tr("seat.risen.sub").format({"name": name})
	if landlord == Seats.PLAYER:
		return tr("seat.kept.you")
	return tr("seat.kept.sub").format({"name": name})


## Forgets the round last called out, as a run starts or is left.
static func forget() -> void:
	said = ""


## A reader that has read every event given.
static func of(events: Array[RunEvent]) -> KeptSeat:
	var reader: KeptSeat = KeptSeat.new()
	for event: RunEvent in events:
		reader.read(event)
	return reader
