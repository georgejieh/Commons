class_name CampaignCounter
extends RefCounted
## One counter's Campaigns (ADR 0021): drawn evenly from its pool after every other draw
## on the shop stream, redrawn by the counter's reroll, and bought at the counter's
## price. A Campaign is refused while the player holds as many as they can. A held one
## may be sold back for part of its price here (ADR 0040), and is not offered again that
## visit.

const SOLD: String = ""
const PERCENT: int = 100

## Campaigns sold back this visit: not offered again until the next.
var withheld: Array[String] = []

var _state: RunState
var _params: ShopParams
var _pool: Array[CampaignDef]
var _stock: Array[String] = []


func _init(state: RunState, params: ShopParams, pool: Array[CampaignDef]) -> void:
	_state = state
	_params = params
	_pool = pool


## Campaign IDs per slot; SOLD marks one already bought.
func stock() -> Array[String]:
	return _stock.duplicate()


func price(slot: int) -> int:
	var cost: int = (_campaign(_stock[slot]).cost * _params.price_percent + PERCENT - 1) / PERCENT
	return RunBooks.priced(_state, cost)


## True while the player can hold another Campaign.
func has_room() -> bool:
	return _state.inventory.consumables.size() < RunReforms.campaign_slots(_state)


## True when a reroll could offer another Campaign the player has room for.
func reroll_changes() -> bool:
	return has_room() and _pool.size() > _params.campaign_offers


func check(slot: int) -> RunShop.Reason:
	if slot < 0 or slot >= _stock.size():
		return RunShop.Reason.NO_SUCH_SLOT
	if _stock[slot] == SOLD:
		return RunShop.Reason.SOLD_OUT
	if not has_room():
		return RunShop.Reason.CAMPAIGNS_FULL
	if _state.coupons < price(slot):
		return RunShop.Reason.TOO_POOR
	return RunShop.Reason.OK


## Buys a Campaign into the player's held Campaigns.
func buy(slot: int) -> RunShop.Reason:
	var reason: RunShop.Reason = check(slot)
	if reason != RunShop.Reason.OK:
		return reason
	_state.coupons -= price(slot)
	_state.inventory.consumables.append(_stock[slot])
	_stock[slot] = SOLD
	return RunShop.Reason.OK


## Why the held Campaign at index cannot be sold here, or OK.
func check_sell(index: int, definition: CampaignDef) -> RunShop.Reason:
	var held: Array[String] = _state.inventory.consumables
	if index < 0 or index >= held.size() or definition == null or definition.id != held[index]:
		return RunShop.Reason.NOT_HELD
	return RunShop.Reason.OK


## Sells the held Campaign at index for RunShop.sale_of its cost here.
func sell(index: int, definition: CampaignDef) -> RunShop.Reason:
	var reason: RunShop.Reason = check_sell(index, definition)
	if reason != RunShop.Reason.OK:
		return reason
	_state.coupons += sale_price(definition)
	_state.inventory.consumables.remove_at(index)
	return RunShop.Reason.OK


func sale_price(definition: CampaignDef) -> int:
	return RunShop.sale_of(_state, _params, definition.cost)


func clear() -> void:
	_stock.clear()


## Draws the visit's Campaigns evenly from the pool. The run loop calls it last on the
## shop stream, so Campaigns leave every other draw a seed made as it was.
func draw() -> void:
	var open: Array[CampaignDef] = _pool.filter(
		func(campaign: CampaignDef) -> bool: return not withheld.has(campaign.id)
	)
	_stock.clear()
	var stream: RandomStream = _state.streams.stream(RandomStreams.SHOP)
	while _stock.size() < _params.campaign_offers and not open.is_empty():
		var index: int = stream.next_int(0, open.size() - 1)
		_stock.append(open[index].id)
		open.remove_at(index)


func _campaign(campaign_id: String) -> CampaignDef:
	for campaign: CampaignDef in _pool:
		if campaign.id == campaign_id:
			return campaign
	return null
