class_name PlotSwap
extends RefCounted
## Brings plot cards into the player's hand for one round, one for one with hand cards,
## after the landlord has taken the kitty, so kitty cards can be swapped too (ADR 0038,
## which keeps ADR 0014's kitty rule). The plot is never changed by a swap: each plot
## card goes into the hand as a copy under its own plot ID, with its marks, and the plot
## still holds it when the round is over, played or not. The hand card it replaced sits
## the round out and is dealt again with the next round's fresh deck, its saved marks
## still on it. No card is created, lost or reissued.


## True when the swap is allowed: equal counts within limit, no repeats, hand IDs in the hand, plot
## IDs in the plot.
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


## The plot cards join the hand as copies, so nothing the round does to its own cards
## reaches the plot; a mark made through CardMarks finds the plot's card by its ID. The
## hand cards taken out are dropped from the round.
static func apply(
	round_state: RoundState, seat: int, state: RunState, hand_ids: Array[int], plot_ids: Array[int]
) -> void:
	var incoming: Array[CardInstance] = []
	for card_id: int in plot_ids:
		incoming.append(state.inventory.plot[_plot_index(state.inventory, card_id)].snapshot())
	round_state.exchange(seat, hand_ids, incoming)


## The most cards the plot can hold, with the run's upgrades.
static func capacity(state: RunState, params: RunParams) -> int:
	return params.plot_capacity + state.plot_capacity_bonus


## The most swaps a round allows, with the run's upgrades.
static func swaps(state: RunState, params: RunParams) -> int:
	return params.swaps_per_round + state.swap_bonus


## Puts a plot card into the plot when there is room. Returns false when the plot is full.
## Every card made for the plot is made a plot card, under RunState.take_plot_id().
static func store(state: RunState, card: CardInstance, params: RunParams) -> bool:
	assert(card.origin() == CardInstance.Origin.PLOT, "Only a plot card goes into the plot")
	if state.inventory.plot.size() >= capacity(state, params):
		return false
	state.inventory.plot.append(card)
	return true


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
