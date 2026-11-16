class_name BalanceStrategy
extends RefCounted
## One of ADR 0027's three players: every choice in a run besides card play, which the
## Hard bot makes for all three. Each strategy answers from plain values, so a test can
## ask it without a run. This base answers as the table's shared rows do; each strategy
## overrides the rows where it differs.

var params: BalanceParams


func _init(numbers: BalanceParams) -> void:
	params = numbers


## The name in reports and on the command line.
func name() -> String:
	return ""


## Whether to claim the landlord seat. is_grab is true when another seat holds it;
## bot_calls is the Hard bot's own call decision for this hand.
func bid(_is_grab: bool, _bot_calls: bool) -> bool:
	return false


## The need to claim on the Commons, from the true need, the most the panel allows and
## the faces of the audit die that audit now.
func need(true_need: int, _cap: int, _audit_faces: int) -> int:
	return true_need


## The next purchase this visit, or null when the strategy is done buying.
func purchase(_visit: BalanceVisit) -> BalanceOffer:
	return null


## True when the strategy rerolls the black market now.
func rerolls(_visit: BalanceVisit) -> bool:
	return false


## True when the strategy uses this Campaign as soon as its rule allows.
func uses_campaign(campaign_id: String) -> bool:
	return not params.shunned_campaigns.has(campaign_id)


## True when the strategy swaps hand cards for plot cards.
func swaps() -> bool:
	return false


## The state store as collective buys there: the dearest Cadre it can afford, then a
## Reform, then an envelope, then a Campaign, with budget coupons to spend.
static func store_purchase(visit: BalanceVisit, budget: int) -> BalanceOffer:
	for kind: int in [
		BalanceOffer.Kind.CADRE,
		BalanceOffer.Kind.REFORM,
		BalanceOffer.Kind.ENVELOPE,
		BalanceOffer.Kind.CAMPAIGN,
	]:
		var offer: BalanceOffer = BalanceOffer.dearest(visit.store, kind, budget)
		if offer != null:
			return offer
	return null


## The swap private and mixed make: their lowest hand cards for their highest plot
## cards, one for one, up to limit, while the plot card ranks higher. Returns the hand
## IDs and the plot IDs.
static func best_swap(
	hand: Array[CardInstance], plot: Array[CardInstance], limit: int, rank_map: PackedByteArray
) -> Array[Array]:
	var low: Array[CardInstance] = BalanceCards.sorted(hand, rank_map, true)
	var high: Array[CardInstance] = BalanceCards.sorted(plot, rank_map, false)
	var hand_ids: Array[int] = []
	var plot_ids: Array[int] = []
	for index: int in mini(limit, mini(low.size(), high.size())):
		if (
			BalanceCards.strength(high[index], rank_map)
			<= BalanceCards.strength(low[index], rank_map)
		):
			break
		hand_ids.append(low[index].id())
		plot_ids.append(high[index].id())
	return [hand_ids, plot_ids]
