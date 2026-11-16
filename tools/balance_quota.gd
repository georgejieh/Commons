class_name BalanceQuota
extends RefCounted
## One Quota a harness run played to its end (ADR 0027): where it stood in the run, what
## the player banked against its target, and what they held after it. A row of
## reports/balance_quotas.csv.

const HEADER: String = (
	"seed,strategy,quota,year,kind,target,progress,met,rounds,coupons_before_shop,"
	+ "coupons_after_shop,cadres,hand_levels,famine,denunciation,resentment"
)
## RunState.SetType by name.
const KINDS: Array[String] = ["small", "large", "boss"]

## Counted across the run from 1.
var index: int = 0
var year: int = 0
var kind: String = ""
var target: float = 0.0
## Banked at the Quota's end.
var progress: float = 0.0
var met: bool = false
var rounds: int = 0
## Coupons as the Quota ended, its pay included, and as the player left the shops after
## it; the same when no shop followed.
var coupons_before_shop: int = 0
var coupons_after_shop: int = 0
var cadres: int = 0
## Every hand type's level, added up.
var hand_levels: int = 0
var famine: int = 0
var denunciation: int = 0
var resentment: int = 0


## The row for the Quota state has just ended, against the target it was played for.
static func of(state: RunState, quota_target: float) -> BalanceQuota:
	var row: BalanceQuota = BalanceQuota.new()
	row.index = (state.year - 1) * SetConfig.SETS_PER_YEAR + state.set_index + 1
	row.year = state.year
	row.kind = KINDS[state.set_type]
	row.target = quota_target
	row.progress = state.set_progress
	row.met = state.set_progress >= quota_target
	row.rounds = state.round_index
	row.coupons_before_shop = state.coupons
	row.coupons_after_shop = state.coupons
	row.cadres = state.inventory.cadres.size()
	for level: int in state.hand_levels.to_array():
		row.hand_levels += level
	row.famine = state.famine
	row.denunciation = state.denunciation
	row.resentment = state.resentment
	return row


## Progress as a share of the target.
func share() -> float:
	return progress / target if target > 0.0 else 0.0


func per_round() -> float:
	return progress / rounds if rounds > 0 else 0.0


func csv(seed_value: int, strategy: String) -> String:
	var cells: Array[String] = [
		str(seed_value),
		strategy,
		str(index),
		str(year),
		kind,
		"%.1f" % target,
		"%.1f" % progress,
		"1" if met else "0",
		str(rounds),
		str(coupons_before_shop),
		str(coupons_after_shop),
		str(cadres),
		str(hand_levels),
		str(famine),
		str(denunciation),
		str(resentment),
	]
	return ",".join(cells)
