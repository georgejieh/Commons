class_name KeptSeatCall
extends Node
## Calls out a round that begins with no bidding, the moment it begins: "No bidding",
## with who keeps the landlord seat and why under it, from that seat's side. The event
## queue waits for the banner. When the table opens on such a round already under way,
## the banner comes once the replay is over, unless the plot swap sheet opens over it,
## which prints the same line. Each round is called out once.

var _reader: KeptSeat = KeptSeat.new()
var _player: EventPlayer
var _callout: Callout
var _names: Dictionary[int, String] = {}
var _faces: Dictionary[int, Texture2D] = {}


func setup(
	player: EventPlayer,
	callout: Callout,
	names: Dictionary[int, String],
	faces: Dictionary[int, Texture2D]
) -> void:
	_player = player
	_callout = callout
	_names = names
	_faces = faces
	player.played.connect(_on_event)


## The table has replayed the Set so far. swap_waits says the swap sheet opens now.
func after_replay(swap_waits: bool) -> void:
	if not _reader.fresh() or KeptSeat.said == _reader.key():
		return
	if swap_waits:
		KeptSeat.said = _reader.key()
		return
	_say()


func _on_event(event: RunEvent) -> void:
	_reader.read(event)
	var round_event: RoundEvent = event.round_event
	if round_event == null or round_event.type != RoundEvent.Type.ROUND_STARTED:
		return
	if _player.flushing or not _reader.kept() or KeptSeat.said == _reader.key():
		return
	_say()


func _say() -> void:
	KeptSeat.said = _reader.key()
	var seat: int = _reader.landlord
	var line: String = _reader.line(_names)
	var seconds: float = _callout.shout(
		_reader.word(), Callout.Tier.CUT_IN, ScreenKit.RED, line, _faces.get(seat), seat != 1
	)
	_player.hold(seconds)
