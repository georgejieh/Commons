class_name PlotTrade
extends RefCounted
## What the plot swap sheet holds before it is confirmed (ADR 0038): the pairs traded so
## far, each a hand card for a plot card, up to the round's swaps, and the card picked to
## start the next pair. It changes nothing in the run; the sheet sends the pairs as one
## swap when the player confirms.

enum Reason { OK, NO_SWAPS_LEFT }

const NONE: int = -1
## The two sides a card is picked from.
const HAND: int = 0
const PLOT: int = 1

## The most pairs the round allows.
var limit: int = 0
## The pairs in the order they were made: hand_ids[i] sits out for plot_ids[i].
var hand_ids: Array[int] = []
var plot_ids: Array[int] = []
## The card picked to start a pair, and its side, or NONE.
var picked: int = NONE
var picked_side: int = HAND


func _init(swap_limit: int) -> void:
	limit = swap_limit


func pairs() -> int:
	return hand_ids.size()


func left() -> int:
	return limit - pairs()


## The pair a card is in, or NONE.
func pair_of(card_id: int) -> int:
	var at: int = hand_ids.find(card_id)
	return at if at >= 0 else plot_ids.find(card_id)


func is_traded(card_id: int) -> bool:
	return pair_of(card_id) != NONE


## A press on a card, by click or key: undoes the pair it is in; otherwise picks it, or
## takes the pick back, or moves it, or makes a pair with the card picked on the other
## side. A new pick when no swap is left is refused and changes nothing.
func press(side: int, card_id: int) -> Reason:
	if is_traded(card_id):
		undo(pair_of(card_id))
		return Reason.OK
	if picked == card_id:
		picked = NONE
		return Reason.OK
	if picked != NONE and picked_side != side:
		var hand_id: int = card_id if side == HAND else picked
		var plot_id: int = picked if side == HAND else card_id
		return pair(hand_id, plot_id)
	if left() <= 0:
		return Reason.NO_SWAPS_LEFT
	picked = card_id
	picked_side = side
	return Reason.OK


## Trades a hand card for a plot card at once, as a drag does. A card already in a pair
## leaves that pair first.
func pair(hand_id: int, plot_id: int) -> Reason:
	for card_id: int in [hand_id, plot_id]:
		if is_traded(card_id):
			undo(pair_of(card_id))
	if left() <= 0:
		return Reason.NO_SWAPS_LEFT
	hand_ids.append(hand_id)
	plot_ids.append(plot_id)
	picked = NONE
	return Reason.OK


func undo(index: int) -> void:
	if index < 0 or index >= pairs():
		return
	hand_ids.remove_at(index)
	plot_ids.remove_at(index)
