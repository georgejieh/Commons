class_name SeatView
extends RefCounted
## All a bot ever receives: the public view plus copies of its own hand.

var seat: int
var public: PublicView
var own_counts: PackedByteArray
var own_cards: Array[CardInstance]
## How many cards of each rank the seat knows the round holds: the deck as it was dealt,
## and after the seat's own plot swap, less what it set aside and with what it brought
## in. Packed arrays copy on write, so the round's own counts never change through it.
var deck_counts: PackedByteArray
## Information upgrades for the player only (P4.9). Bots' views never have one.
var info: InfoView = null
## The rank counts of each other seat whose hand is shown to the table (Glass Walls),
## by seat. Empty while no hand is shown.
var exposed: Dictionary[int, PackedByteArray] = {}


func _init(
	viewing_seat: int,
	public_view: PublicView,
	counts: PackedByteArray,
	cards: Array[CardInstance],
	known_deck: PackedByteArray
) -> void:
	seat = viewing_seat
	public = public_view
	own_counts = counts
	own_cards = cards
	deck_counts = known_deck
