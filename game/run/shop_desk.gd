class_name ShopDesk
extends RefCounted
## One counter as a screen sees it: what is on it, what things cost and whether
## they can be bought now. The state store and the black market each have one. It only
## reads the run; buying goes through RunController's commands.

## The held Cadres a debuff or boss holds now, which cannot be sold (ADR 0040).
var bound: Array[String] = []
## The Cadres sold back this visit, which cannot be bought until the next (ADR 0040).
var sold_back: Array[String]:
	get:
		return _shop.withheld.duplicate()

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


## True for a Cadre that seldom reaches the counter, which the screen stamps Scarce.
func is_scarce(slot: int) -> bool:
	return _shop.is_rare(slot)


## What this counter pays now for the held Cadre at index, or the held Campaign with
## campaign set (ADR 0040); 0 when there is none, or it cannot be sold now, as a Cadre a
## debuff or boss holds.
func sale(index: int, campaign: bool = false) -> int:
	if campaign:
		var held: CampaignDef = _held_campaign(index)
		if _shop.campaigns.check_sell(index, held) != RunShop.Reason.OK:
			return 0
		return _shop.campaigns.sale_price(held)
	var definition: ModifierDef = _held_cadre(index)
	if _shop.check_sell(index, definition, bound) != RunShop.Reason.OK:
		return 0
	return _shop.sale_price(definition.cost)


func _held_cadre(index: int) -> ModifierDef:
	var held: Array[String] = _state.inventory.cadres
	if index < 0 or index >= held.size():
		return null
	return RunDefinitions.modifiers.get(held[index])


func _held_campaign(index: int) -> CampaignDef:
	var held: Array[String] = _state.inventory.consumables
	if index < 0 or index >= held.size():
		return null
	return RunDefinitions.campaigns.get(held[index])


func reroll_price() -> int:
	return _shop.reroll_price()


## A reroll is worth pressing: affordable, and the counter has something else to offer
## that could be bought: Cadres while the board has room, or Directives.
func can_reroll() -> bool:
	if not _shop.reroll_changes():
		return false
	return _state.coupons >= _shop.reroll_price()


## Directive IDs per slot, an empty ID for one already issued.
func directive_stock() -> Array[String]:
	return _shop.directive_stock()


func directive_price(slot: int) -> int:
	return _shop.directive_price(slot)


func can_buy_directive(slot: int) -> bool:
	return _shop.check_directive(slot) == RunShop.Reason.OK


## How many cards for the private plot are on offer here.
func plot_card_count() -> int:
	return 0 if _stall == null else _stall.offers.count()


## A stand-in for the plot card in slot, or null once it is sold.
func plot_card(slot: int) -> CardInstance:
	if _stall.offers.rank(slot) == CardOffers.SOLD:
		return null
	# A stand-in to show: the card gets its real plot ID when bought.
	return CardInstance.new(
		-1 - slot, _stall.offers.rank(slot), _stall.offers.suit(slot), CardInstance.Origin.PLOT
	)


## What the plot card in slot costs now.
func plot_card_price(slot: int) -> int:
	return _stall.offers.price(slot)


## True when the plot card in slot can be bought now.
func can_buy_plot_card(slot: int) -> bool:
	return _stall.check_buy(slot) == PlotStall.Reason.OK


## How many cards the private plot holds now.
func plot_size() -> int:
	return _state.inventory.plot.size()


## How many cards the private plot can hold.
func plot_capacity() -> int:
	return PlotSwap.capacity(_state, RunDefaults.PARAMS)


## The upgrades sold here, by kind.
func upgrade_kinds() -> PackedStringArray:
	return PlotUpgrades.KINDS if _upgrades != null else PackedStringArray()


func upgrade_price(kind: String) -> int:
	return PlotUpgrades.price(kind, _upgrades, _state)


func can_upgrade(kind: String) -> bool:
	return _upgrades != null and PlotUpgrades.can_buy(_state, kind, _upgrades)


## How many more steps of an upgrade the run may buy.
func upgrades_left(kind: String) -> int:
	if _upgrades == null:
		return 0
	return PlotUpgrades.limit(kind, _upgrades) - PlotUpgrades.bought(_state, kind)
