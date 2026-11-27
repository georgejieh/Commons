class_name PlotTrade
extends RefCounted
## What the plot swap sheet holds before it is confirmed (ADR 0038): the pairs traded so
## far, each a hand card for a plot card, up to the round's swaps, and the card picked to
## start the next pair. It changes nothing in the run; the sheet sends the pairs as one
## swap when the player confirms.

## What a press or a pair came to: OK, or NO_SWAPS_LEFT when the round's swaps are used up.
enum Reason { OK, NO_SWAPS_LEFT }
## The two sides a card is picked from.
enum Source { HAND, PLOT }

## The card id and the pair index of nothing, as when no card is picked or a card is in no pair.
const NONE: int = -1

## The most pairs the round allows.
var limit: int = 0
## The hand cards traded, in the order the pairs were made: hand_ids[i] sits out for plot_ids[i].
var hand_ids: Array[int] = []
## The plot cards brought in, in the same order: plot_ids[i] takes the place of hand_ids[i].
var plot_ids: Array[int] = []
## The card picked to start a pair, or NONE.
var picked: int = NONE
## The side picked came from; it means something only while picked is not NONE.
var picked_side: Source = Source.HAND


func _init(swap_limit: int) -> void:
	limit = swap_limit


## How many pairs are traded so far.
func pairs() -> int:
	return hand_ids.size()


## How many more pairs the round allows.
func left() -> int:
	return limit - pairs()


## The pair a card is in, or NONE.
func pair_of(card_id: int) -> int:
	var at: int = hand_ids.find(card_id)
	return at if at >= 0 else plot_ids.find(card_id)


## True when the card is in a pair, on either side.
func is_traded(card_id: int) -> bool:
	return pair_of(card_id) != NONE


## A press on a card, by click or key: undoes the pair it is in; otherwise picks it, or
## takes the pick back, or moves it, or makes a pair with the card picked on the other
## side. A new pick when no swap is left is refused and changes nothing.
func press(side: Source, card_id: int) -> Reason:
	if is_traded(card_id):
		undo(pair_of(card_id))
		return Reason.OK
	if picked == card_id:
		picked = NONE
		return Reason.OK
	if picked != NONE and picked_side != side:
		var hand_id: int = card_id if side == Source.HAND else picked
		var plot_id: int = picked if side == Source.HAND else card_id
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


## Takes the pair at an index back and closes the gap; an index out of range does nothing.
func undo(index: int) -> void:
	if index < 0 or index >= pairs():
		return
	hand_ids.remove_at(index)
	plot_ids.remove_at(index)
