class_name PlotUpgrades
extends RefCounted
## Private-plot upgrades sold at the black market (P4.10): room for one more card, or
## one more swap each round. Each is bought with coupons up to a limit, and raises the
## bonus the plot already reads from the run state (P4.8).

const CAPACITY: String = "capacity"
const SWAPS: String = "swaps"
const KINDS: PackedStringArray = [CAPACITY, SWAPS]


static func price(kind: String, params: PlotUpgradeParams) -> int:
	return params.capacity_cost if kind == CAPACITY else params.swap_cost


## How many of this upgrade the run already has.
static func bought(state: RunState, kind: String) -> int:
	return state.plot_capacity_bonus if kind == CAPACITY else state.swap_bonus


static func limit(kind: String, params: PlotUpgradeParams) -> int:
	return params.capacity_max if kind == CAPACITY else params.swap_max


static func can_buy(state: RunState, kind: String, params: PlotUpgradeParams) -> bool:
	if not KINDS.has(kind):
		return false
	return bought(state, kind) < limit(kind, params) and state.coupons >= price(kind, params)


## Buys one step of an upgrade. Returns false, changing nothing, when it can't be bought.
static func buy(state: RunState, kind: String, params: PlotUpgradeParams) -> bool:
	if not can_buy(state, kind, params):
		return false
	state.coupons -= price(kind, params)
	if kind == CAPACITY:
		state.plot_capacity_bonus += 1
	else:
		state.swap_bonus += 1
	return true
