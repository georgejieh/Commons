class_name BalanceMixed
extends BalanceStrategy
## The player who takes what is cheap and stops before it costs (ADR 0027): calls but
## never grabs, over-claims only while the audit is light, issues a Directive from all
## it holds, then buys as collective while keeping coupons back, then one thing a visit
## at the black market while Resentment is low, and swaps its plot in.


func name() -> String:
	return "mixed"


func bid(is_grab: bool, bot_calls: bool) -> bool:
	return bot_calls and not is_grab


func need(true_need: int, _cap: int, audit_faces: int) -> int:
	if audit_faces > params.over_claim_faces:
		return true_need
	return true_need + roundi(true_need * params.over_claim_percent / 100.0)


## A Directive first, from everything it holds; then the state store, spending only
## what is above the coupons kept back; then the dearest thing the black market has
## that the rest affords, once a visit.
func purchase(visit: BalanceVisit) -> BalanceOffer:
	var directive: BalanceOffer = directive_purchase(visit, visit.coupons)
	if directive != null:
		return directive
	var offer: BalanceOffer = store_purchase(visit, visit.coupons - params.kept_back)
	if offer != null:
		return offer
	if visit.market_bought > 0 or visit.resentment >= params.resentment_limit:
		return null
	return BalanceOffer.dearest_of_any(visit.market, visit.coupons)


func swaps() -> bool:
	return true
