class_name RoundClose
extends Node
## A finished round is played out and put away before the next hand is dealt. The
## run deals the next hand the moment the round is settled, so the table must not read the
## hand from the run while the old round's events are still being shown: the player's last
## play leaves the fan, and the fan stays empty until the deal plays. Before the deal, the
## round's end stays in view for a beat, then its last trick is swept off toward whoever
## won and the audit slip is put away; only then does the next hand rise in.

var _player: EventPlayer
var _pile: TrickPile
var _moments: TableMoments
var _hand_view: HandView
## Where each seat sits on screen, for the sweep, and the hand as the run holds it.
var _cards: TableCards
var _winner: int = Seats.NONE
var _beat: Tween = null


## Wires the sweep to the event queue, the trick pile, the table's moments, the hand and the card
## lookup, and listens to the queue.
func setup(
	player: EventPlayer,
	pile: TrickPile,
	moments: TableMoments,
	hand_view: HandView,
	cards: TableCards
) -> void:
	_player = player
	_pile = pile
	_moments = moments
	_hand_view = hand_view
	_cards = cards
	player.closing.connect(_on_closing)
	player.played.connect(_on_played)


## The player's own play has left the hand. While a deal still waits in the queue the run
## already holds the next hand, so the played cards are only taken out of the fan.
func own_play(event: RoundEvent) -> void:
	if _player.deal_waiting():
		_hand_view.hide_cards(event.card_ids)
		return
	_cards.show_hand()


func _on_played(event: RunEvent) -> void:
	if event.type == RunEvent.Type.ROUND and event.round_event.type == RoundEvent.Type.ROUND_ENDED:
		_winner = event.round_event.seat
	elif event.type == RunEvent.Type.DEALT or event.type == RunEvent.Type.SET_STARTED:
		_stop()


## The round's end is read for a beat at the table's pace, then put away; the deal waits
## for both.
func _on_closing() -> void:
	_stop()
	var presets: MotionPresets = UiMotion.PRESETS
	var read: float = presets.round_close_steps * _player.step
	var sweep: float = presets.sweep if not UiMotion.reduced() else 0.0
	_player.hold(read + sweep)
	_beat = create_tween()
	_beat.tween_interval(read)
	_beat.tween_callback(_put_away)


func _put_away() -> void:
	var toward: Vector2 = _pile.global_position + _pile.size / 2.0
	if _winner != Seats.NONE:
		toward = _cards.point(_winner)
	_pile.sweep(toward)
	Audio.fill(AudioEvents.ROUND_NAMES[RoundEvent.Type.TRICK_WON])
	_moments.slip.clear()
	_moments.tally.clear()


func _stop() -> void:
	UiMotion.end(_beat)
	_beat = null
