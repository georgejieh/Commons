class_name TableCards
extends RefCounted
## The cards at the table as its moments move them: which card an ID names, where a seat's
## cards leave from or land, and the hand put back as the run holds it. The table makes one
## and hands it to every piece that moves cards between the hand and the seats.

var _controller: RunController
var _hand: HandModel
var _hand_view: HandView
var _seats: Dictionary[int, SeatPanel]


func _init(
	controller: RunController,
	hand: HandModel,
	hand_view: HandView,
	seats: Dictionary[int, SeatPanel]
) -> void:
	_controller = controller
	_hand = hand
	_hand_view = hand_view
	_seats = seats


## A card's face: in the hand as shown, in the hand as the run holds it, or from the deck.
func card(card_id: int) -> CardInstance:
	for held: CardInstance in _hand.cards() + _controller.table.player_cards():
		if held.id() == card_id:
			return held
	return _controller.table.deck_card(card_id) if card_id < Deck.SIZE else null


## Where a seat's cards leave from or land, on screen: for the player, the card card_id in
## the hand, or the hand's middle when card_id is negative; for a villager, their seat's
## middle.
func point(seat: int, card_id: int = -1) -> Vector2:
	if seat == Seats.PLAYER and card_id >= 0:
		return _hand_view.card_center(card_id)
	var at: Control = _hand_view
	if seat != Seats.PLAYER:
		at = _seats[seat]
	return at.global_position + at.size / 2.0


## Puts the hand back as the run holds it, once a moment is done with it.
func show_hand() -> void:
	_hand.refresh()
	_hand_view.show_cards()
