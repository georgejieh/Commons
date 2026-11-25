class_name BalanceResult
extends RefCounted
## One run the harness played: its CSV row, and the counts the tests read to see that
## each strategy made its own choices.

const HEADER: String = (
	"seed,strategy,stake,outcome,survived,year,quota,class,quotas_met,quotas_played,"
	+ "coupons,famine,denunciation,resentment,starved,cadres,campaigns_used,seconds,failure"
)

var seed_value: int = 0
var strategy: String = ""
var stake: int = 0
var outcome: String = ""
var survived: bool = false
var year: int = 0
## The Quota reached, counted across the run from 1.
var quota: int = 0
var landlord_class: bool = false
var quotas_met: int = 0
var quotas_played: int = 0
var coupons: int = 0
var famine: int = 0
var denunciation: int = 0
var resentment: int = 0
var starved: int = 0
var cadres: int = 0
var campaigns_used: int = 0
var seconds: float = 0.0
## Why the run failed: a refused command, a refused bot action, a script error or the
## command limit. Empty for a run that played to its end.
var failure: String = ""
## The run Quota by Quota, and where its coupons came from and went.
var ledger: BalanceLedger = BalanceLedger.new()

## What the choices were, for the tests.
var calls: int = 0
var grabs: int = 0
var landlord_rounds: int = 0
var max_need: int = 0
## State store purchases besides Directives, and Directives issued.
var store_buys: int = 0
var directive_buys: int = 0
var market_buys: int = 0
## Resentment from black market purchases and private Cadres.
var market_resentment: int = 0
## The fewest coupons a state store purchase other than a Directive left, or -1 before any.
var store_floor: int = -1
## Black market purchases made while Resentment stood at the mixed limit or over it.
var market_buys_over_limit: int = 0
## The most black market purchases in one visit.
var market_buys_per_visit: int = 0
var swapped_cards: int = 0
## The wild ranks' items bought, by ID, and the ranks made wild over the run (ADR 0029),
## for the harness's closing line; not in the CSV.
var wild_buys: Dictionary[String, int] = {}
var wild_draws: int = 0
var workers_used: int = 0
var rerolls: int = 0
## ADR 0032's pieces bought at either counter, and its Campaigns used, by ID, for the
## harness's closing line; not in the CSV.
var wave_buys: Dictionary[String, int] = {}
var wave_uses: Dictionary[String, int] = {}


## Fills the run's final numbers from its last state.
func finish(state: RunState) -> void:
	outcome = Endings.outcome(state, RunLoop.DEFAULT_METERS)
	survived = not Endings.is_death(outcome)
	year = state.year
	quota = (state.year - 1) * SetConfig.SETS_PER_YEAR + state.set_index + 1
	landlord_class = YearClass.is_landlord(state)
	coupons = state.coupons
	famine = state.famine
	denunciation = state.denunciation
	resentment = state.resentment
	cadres = state.inventory.cadres.size()


## True when the run failed: a refused command, a refused bot action or a script error.
func failed() -> bool:
	return not failure.is_empty()


## The run's CSV row; the wall seconds only when asked, since they alone differ between
## two plays of one seed.
func csv(with_seconds: bool = true) -> String:
	var cells: Array[String] = [
		str(seed_value),
		strategy,
		str(stake),
		outcome,
		"1" if survived else "0",
		str(year),
		str(quota),
		"landlord" if landlord_class else "peasant",
		str(quotas_met),
		str(quotas_played),
		str(coupons),
		str(famine),
		str(denunciation),
		str(resentment),
		str(starved),
		str(cadres),
		str(campaigns_used),
		"%.2f" % seconds if with_seconds else "",
		failure.replace(",", ";"),
	]
	return ",".join(cells)
