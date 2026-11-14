class_name ShopDesk
extends RefCounted
## One counter as a screen sees it (P4.10): what is on it, what things cost and whether
## they can be bought now. The state store and the black market each have one. It only
## reads the run; buying goes through RunController's commands.

var _shop: RunShop
var _state: RunState
## The private-plot upgrades this counter sells, or null when it sells none.
var _upgrades: PlotUpgradeParams


func _init(shop: RunShop, state: RunState, upgrades: PlotUpgradeParams = null) -> void:
	_shop = shop
	_state = state
	_upgrades = upgrades


## IDs per slot, an empty ID for a slot already sold.
func stock() -> Array[String]:
	return _shop.stock()


func price(slot: int) -> int:
	return _shop.price(slot)


func can_buy(slot: int) -> bool:
	return _shop.check_buy(slot) == RunShop.Reason.OK


func reroll_price() -> int:
	return _shop.reroll_price()


## A reroll is worth pressing: affordable, and the board has room for what it draws.
func can_reroll() -> bool:
	return _state.coupons >= _shop.reroll_price() and _shop.has_room()


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
