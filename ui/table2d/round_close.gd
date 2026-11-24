class_name RoundClose
extends Node
## A finished round is played out and put away before the next hand is dealt (P5.2a). The
## run deals the next hand the moment the round is settled, so the table must not read the
## hand from the run while the old round's events are still being shown: the player's last
## play leaves the fan, and the fan stays empty until the deal plays. Before the deal, the
## round's end stays in view for a beat, then its last trick is swept off toward whoever
## won and the audit slip is put away; only then does the next hand rise in.

var _player: EventPlayer
var _pile: TrickPile
var _moments: TableMoments
var _hand: HandModel
var _hand_view: HandView
## Where a seat sits on screen, its middle, for the sweep.
var _seat_center: Callable
var _winner: int = Seats.NONE
var _beat: Tween = null


func setup(
	player: EventPlayer,
	pile: TrickPile,
	moments: TableMoments,
	hand: HandModel,
	hand_view: HandView,
	seat_center: Callable
) -> void:
	_player = player
	_pile = pile
	_moments = moments
	_hand = hand
	_hand_view = hand_view
	_seat_center = seat_center
	player.closing.connect(_on_closing)
	player.played.connect(_on_played)


## The player's own play has left the hand. While a deal still waits in the queue the run
## already holds the next hand, so the played cards are only taken out of the fan.
func own_play(event: RoundEvent) -> void:
	if _player.deal_waiting():
		_hand_view.hide_cards(event.card_ids)
		return
	_hand.refresh()
	_hand_view.show_cards()


## True while the finished round is still on the table, waiting to be put away.
func is_closing() -> bool:
	return _beat != null and _beat.is_valid() and _beat.is_running()


func _on_played(event: RunEvent) -> void:
	if event.type == RunEvent.Type.ROUND and event.round_event.type == RoundEvent.Type.ROUND_ENDED:
		_winner = event.round_event.seat
	elif event.type == RunEvent.Type.DEALT or event.type == RunEvent.Type.SET_STARTED:
		_stop()


## The round's end is read for a beat at the table's pace, then put away; the deal waits
## for both.
func _on_closing() -> void:
	_stop()
	var presets: MotionPresets = TableMotion.PRESETS
	var read: float = presets.round_close_steps * _player.step
	var sweep: float = presets.sweep if not UiMotion.reduced() else 0.0
	_player.hold(read + sweep)
	_beat = create_tween()
	_beat.tween_interval(read)
	_beat.tween_callback(_put_away)


func _put_away() -> void:
	var toward: Vector2 = _pile.global_position + _pile.size / 2.0
	if _winner != Seats.NONE and _seat_center.is_valid():
		toward = _seat_center.call(_winner)
	_pile.sweep(toward)
	Audio.fill(AudioEvents.ROUND_NAMES[RoundEvent.Type.TRICK_WON])
	_moments.slip.clear()
	_moments.tally.clear()


func _stop() -> void:
	if _beat != null and _beat.is_valid():
		_beat.kill()
	_beat = null
