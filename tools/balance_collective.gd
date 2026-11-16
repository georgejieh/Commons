class_name BalanceCollective
extends BalanceStrategy
## The player who trusts the village (ADR 0027): never takes the seat, claims the true
## need, buys only at the state store and never enters the black market.


func name() -> String:
	return "collective"


func purchase(visit: BalanceVisit) -> BalanceOffer:
	return store_purchase(visit, visit.coupons)
