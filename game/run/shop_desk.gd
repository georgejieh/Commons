class_name ShopDesk
extends RefCounted
## One counter as a screen sees it (P4.10): what is on it, what things cost and whether
## they can be bought now. The state store and the black market each have one. It only
## reads the run; buying goes through RunController's commands.

var _shop: RunShop
var _state: RunState
## The private-plot upgrades this counter sells, or null when it sells none.
var _upgrades: PlotUpgradeParams
## The cards for the private plot this counter sells, or null when it sells none.
var _stall: PlotStall


func _init(
	shop: RunShop, state: RunState, upgrades: PlotUpgradeParams = null, stall: PlotStall = null
) -> void:
	_shop = shop
	_state = state
	_upgrades = upgrades
	_stall = stall


## IDs per slot, an empty ID for a slot already sold.
func stock() -> Array[String]:
	return _shop.stock()


func price(slot: int) -> int:
	return _shop.price(slot)


func can_buy(slot: int) -> bool:
	return _shop.check_buy(slot) == RunShop.Reason.OK


func reroll_price() -> int:
	return _shop.reroll_price()


## A reroll is worth pressing: affordable, the board has room for what it draws, and
## the counter has something else to offer.
func can_reroll() -> bool:
	if not _shop.has_room() or not _shop.reroll_changes():
		return false
	return _state.coupons >= _shop.reroll_price()


## Cards for the private plot on offer here: how many slots, then each slot's card (null
## once sold), price and whether it can be bought now.
func plot_card_count() -> int:
	return 0 if _stall == null else _stall.count()


func plot_card(slot: int) -> CardInstance:
	if _stall.rank(slot) == PlotStall.SOLD:
		return null
	# A stand-in to show: the card gets its real plot ID when bought.
	return CardInstance.new(
		-1 - slot, _stall.rank(slot), _stall.suit(slot), CardInstance.Origin.PLOT
	)


func plot_card_price(slot: int) -> int:
	return _stall.price(slot)


func can_buy_plot_card(slot: int) -> bool:
	return _stall.check_buy(slot) == PlotStall.Reason.OK


## Cards in the private plot now, and how many it holds.
func plot_size() -> int:
	return _state.inventory.plot.size()


func plot_capacity() -> int:
	return PlotSwap.capacity(_state, RunLoop.DEFAULT_PARAMS)


## The upgrades sold here, by kind.
func upgrade_kinds() -> PackedStringArray:
	return PlotUpgrades.KINDS if _upgrades != null else PackedStringArray()


func upgrade_price(kind: String) -> int:
	return PlotUpgrades.price(kind, _upgrades)


func can_upgrade(kind: String) -> bool:
	return _upgrades != null and PlotUpgrades.can_buy(_state, kind, _upgrades)


## How many more steps of an upgrade the run may buy.
func upgrades_left(kind: String) -> int:
	if _upgrades == null:
		return 0
	return PlotUpgrades.limit(kind, _upgrades) - PlotUpgrades.bought(_state, kind)
