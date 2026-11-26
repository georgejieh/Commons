class_name BalanceLedger
extends RefCounted
## A harness run Quota by Quota (ADR 0027): one row for each Quota it played to its end,
## and where its coupons came from and went. Coupons a Set paid that were neither its
## reward nor its overfulfilment bonus are the Cadres' and Campaigns' (Grain Loan), as is
## any rise at the shops.

const EARNED: Array[String] = ["rewards", "overfulfilment", "cadres_and_campaigns"]
const SPENT: Array[String] = [
	"directives", "cadres", "reforms", "envelopes", "campaigns", "market", "rerolls"
]
const OTHER: String = "cadres_and_campaigns"

var quotas: Array[BalanceQuota] = []
var earned: Dictionary[String, int] = {}
var spent: Dictionary[String, int] = {}
## The run's own SET_STARTED and SET_ENDED events, in order, for the tests.
var events: Array[RunEvent] = []

## Coupons as the Set under way started.
var _set_start: int = 0


func _init() -> void:
	for source: String in EARNED:
		earned[source] = 0
	for use: String in SPENT:
		spent[use] = 0


## Where an offer's coupons go.
static func category(offer: BalanceOffer) -> String:
	if offer.market:
		return "market"
	match offer.kind:
		BalanceOffer.Kind.DIRECTIVE:
			return "directives"
		BalanceOffer.Kind.CADRE:
			return "cadres"
		BalanceOffer.Kind.REFORM:
			return "reforms"
		BalanceOffer.Kind.ENVELOPE:
			return "envelopes"
	return "campaigns"


## Takes a Set's start and end as the run announces them; the controller still stands
## where the event was added.
func heard(event: RunEvent, controller: RunController) -> void:
	if event.type == RunEvent.Type.SET_STARTED:
		events.append(event)
		_set_start = controller.state_copy().coupons
	elif event.type == RunEvent.Type.SET_ENDED:
		events.append(event)
		var state: RunState = controller.state_copy()
		var row: BalanceQuota = BalanceQuota.of(state, controller.figures.target())
		quotas.append(row)
		var reward: int = controller.figures.quota_reward() if event.value == 1 else 0
		var bonus: int = controller.figures.over_bonus()
		earned["rewards"] += reward
		earned["overfulfilment"] += bonus
		earned[OTHER] += state.coupons - _set_start - reward - bonus


## One step at the shops, by what it was for and the coupons before and after it.
func shop_step(use: String, before: int, after: int) -> void:
	if after > before:
		earned[OTHER] += after - before
	else:
		spent[use] += before - after


## The player leaves the shops with these coupons.
func left_store(coupons: int) -> void:
	if not quotas.is_empty():
		quotas[-1].coupons_after_shop = coupons


## Every Quota row of the run, as CSV lines.
func csv(seed_value: int, strategy: String) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for row: BalanceQuota in quotas:
		lines.append(row.csv(seed_value, strategy))
	return lines
