class_name BalanceLedger
extends RefCounted
## A harness run Quota by Quota (ADR 0027): one row for each Quota it played to its end,
## and where its coupons came from and went. Coupons a Set paid that were neither its
## reward nor its overfulfilment bonus are the Cadres' and Campaigns' (Grain Loan), as is
## any rise at the shops.

const EARNED: Array[String] = ["rewards", "overfulfilment", "cadres_and_campaigns"]
const SPENT: Array[String] = [
	"directives",
	"cadres",
	"reforms",
	"envelopes",
	"campaigns",
	"deck_cards",
	"marks",
	"market",
	"rerolls",
]
const OTHER: String = "cadres_and_campaigns"
## Where a purchase's coupons go by its kind, away from the black market.
const USES: Dictionary[BalanceOffer.Kind, String] = {
	BalanceOffer.Kind.DIRECTIVE: "directives",
	BalanceOffer.Kind.CADRE: "cadres",
	BalanceOffer.Kind.REFORM: "reforms",
	BalanceOffer.Kind.ENVELOPE: "envelopes",
	BalanceOffer.Kind.CAMPAIGN: "campaigns",
	BalanceOffer.Kind.DECK_CARD: "deck_cards",
	BalanceOffer.Kind.MARK: "marks",
}

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


## Where an offer's coupons go. A desk's mark is "marks" at either counter, so the
## desks' spending reads in one place; every other black market purchase is "market".
static func category(offer: BalanceOffer) -> String:
	if offer.market and offer.kind != BalanceOffer.Kind.MARK:
		return "market"
	return USES[offer.kind]


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
