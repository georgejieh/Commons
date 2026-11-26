class_name BalancePrivate
extends BalanceStrategy
## The player who takes everything (ADR 0027): calls and grabs whenever the Hard bot
## would call, claims the most the panel allows, issues a Directive a visit and buys
## nothing else from the state store, buys everything it can at the black market (its
## desk's stamp after a Cadre), uses every Campaign and swaps its plot in.

const MARKET_ORDER: Array[BalanceOffer.Kind] = [
	BalanceOffer.Kind.CADRE,
	BalanceOffer.Kind.MARK,
	BalanceOffer.Kind.PARCEL,
	BalanceOffer.Kind.PLOT_CARD,
	BalanceOffer.Kind.UPGRADE,
]


func name() -> String:
	return "private"


func bid(_is_grab: bool, bot_calls: bool) -> bool:
	return bot_calls


func need(_true_need: int, cap: int, _audit_faces: int) -> int:
	return cap


func purchase(visit: BalanceVisit) -> BalanceOffer:
	var directive: BalanceOffer = directive_purchase(visit, visit.coupons)
	if directive != null:
		return directive
	for kind: BalanceOffer.Kind in MARKET_ORDER:
		var offer: BalanceOffer = BalanceOffer.dearest(visit.market, kind, visit.coupons)
		if offer != null:
			return offer
	return null


## Once a visit, when nothing at the black market was affordable.
func rerolls(visit: BalanceVisit) -> bool:
	return (
		not visit.rerolled
		and visit.market_bought == 0
		and visit.market.is_empty()
		and visit.can_reroll
	)


func uses_campaign(_campaign_id: String) -> bool:
	return true


func swaps() -> bool:
	return true
