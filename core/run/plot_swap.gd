class_name PlotSwap
extends RefCounted
## Exchanges cards between the player's dealt hand and the private plot, one for one,
## so no card is created or lost.


static func is_valid(
	hand: Hand, inventory: RunInventory, hand_ids: Array[int], plot_ids: Array[int], limit: int
) -> bool:
	if hand_ids.size() != plot_ids.size() or hand_ids.size() > limit:
		return false
	if _has_repeat(hand_ids) or _has_repeat(plot_ids):
		return false
	for card_id: int in hand_ids:
		if hand.find(card_id) == null:
			return false
	# Until ADR 0014 settles plot identity, an ID already in hand would be refused by
	# Hand.add() and the card lost.
	for card_id: int in plot_ids:
		if _plot_index(inventory, card_id) < 0 or hand.find(card_id) != null:
			return false
	return true


static func apply(
	hand: Hand, inventory: RunInventory, hand_ids: Array[int], plot_ids: Array[int]
) -> void:
	for index: int in hand_ids.size():
		var from_hand: CardInstance = hand.remove(hand_ids[index])
		var at: int = _plot_index(inventory, plot_ids[index])
		hand.add(inventory.plot[at])
		inventory.plot[at] = from_hand


static func _plot_index(inventory: RunInventory, card_id: int) -> int:
	for index: int in inventory.plot.size():
		if inventory.plot[index].id() == card_id:
			return index
	return -1


static func _has_repeat(ids: Array[int]) -> bool:
	var seen: Dictionary[int, bool] = {}
	for card_id: int in ids:
		if seen.has(card_id):
			return true
		seen[card_id] = true
	return false
