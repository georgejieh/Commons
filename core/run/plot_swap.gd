class_name PlotSwap
extends RefCounted
## Exchanges cards between the player's hand and the private plot, one for one, after
## the landlord has taken the kitty, so kitty cards can be swapped too (ADR 0014). A
## deck card that goes into the plot becomes a plot card with a new ID from the run's
## counter, keeping its rank, suit and marks, so the next round's fresh deck never meets
## a card with its ID. No card is created or lost.


static func is_valid(
	hand: Array[CardInstance],
	inventory: RunInventory,
	hand_ids: Array[int],
	plot_ids: Array[int],
	limit: int
) -> bool:
	if hand_ids.size() != plot_ids.size() or hand_ids.size() > limit:
		return false
	if _has_repeat(hand_ids) or _has_repeat(plot_ids):
		return false
	var held: Dictionary[int, bool] = {}
	for card: CardInstance in hand:
		held[card.id()] = true
	for card_id: int in hand_ids:
		if not held.has(card_id):
			return false
	for card_id: int in plot_ids:
		if _plot_index(inventory, card_id) < 0 or held.has(card_id):
			return false
	return true


static func apply(
	round_state: RoundState, seat: int, state: RunState, hand_ids: Array[int], plot_ids: Array[int]
) -> void:
	var incoming: Array[CardInstance] = []
	for card_id: int in plot_ids:
		incoming.append(state.inventory.plot[_plot_index(state.inventory, card_id)])
	var outgoing: Array[CardInstance] = round_state.exchange(seat, hand_ids, incoming)
	for index: int in plot_ids.size():
		var at: int = _plot_index(state.inventory, plot_ids[index])
		state.inventory.plot[at] = _for_plot(outgoing[index], state)


## The most cards the plot can hold, and the most swaps a round allows, with upgrades.
static func capacity(state: RunState, params: RunParams) -> int:
	return params.plot_capacity + state.plot_capacity_bonus


static func swaps(state: RunState, params: RunParams) -> int:
	return params.swaps_per_round + state.swap_bonus


## Puts a card into the plot when there is room. Returns false when the plot is full.
static func store(state: RunState, card: CardInstance, params: RunParams) -> bool:
	if state.inventory.plot.size() >= capacity(state, params):
		return false
	state.inventory.plot.append(_for_plot(card, state))
	return true


## A plot card stays as it is; a deck card is reissued under the next plot ID.
static func _for_plot(card: CardInstance, state: RunState) -> CardInstance:
	if card.origin() == CardInstance.Origin.PLOT:
		return card
	return card.reissued(state.take_plot_id())


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
