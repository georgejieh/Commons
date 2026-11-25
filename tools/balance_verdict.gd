class_name BalanceVerdict
extends RefCounted
## How ADR 0027 reads the target "mixed > private > collective > 0": on survival of the
## eighth Year, each gap holds only when the lower end of one strategy's 90% interval
## clears the upper end of the next, and collective's lower end clears 0.

## The two-sided 90% normal quantile.
const Z_90: float = 1.6448536269514722
## The strategies from the one that should survive most to the one that should least.
const ORDER: Array[String] = ["mixed", "private", "collective"]
## The seeds a strategy needs before the nightly reading counts (ADR 0027).
const NIGHTLY_SEEDS: int = 300

var passed: bool = false
## Each gap that fails, as "mixed > private", "private > collective" or "collective > 0".
var failed_gaps: Array[String] = []
## Strategies in ORDER the tally has no runs for; with any, the ordering is not judged.
var missing: Array[String] = []


## The 90% Wilson score interval for survived runs out of runs, as lower and upper.
static func wilson(survived: int, runs: int) -> Vector2:
	if runs <= 0:
		return Vector2(0.0, 1.0)
	var share: float = float(survived) / runs
	var z: float = Z_90
	var z2: float = z * z
	var denominator: float = 1.0 + z2 / runs
	var centre: float = (share + z2 / (2.0 * runs)) / denominator
	var half: float = (
		z * sqrt(share * (1.0 - share) / runs + z2 / (4.0 * runs * runs)) / denominator
	)
	var lower: float = 0.0 if survived == 0 else maxf(centre - half, 0.0)
	var upper: float = 1.0 if survived == runs else minf(centre + half, 1.0)
	return Vector2(lower, upper)


## Judges survivals, keyed by strategy name, each as survived runs (x) out of runs (y).
static func judge(survivals: Dictionary[String, Vector2i]) -> BalanceVerdict:
	var verdict: BalanceVerdict = BalanceVerdict.new()
	for strategy: String in ORDER:
		if not survivals.has(strategy) or survivals[strategy].y <= 0:
			verdict.missing.append(strategy)
	if not verdict.missing.is_empty():
		return verdict
	for index: int in ORDER.size() - 1:
		var upper: Vector2i = survivals[ORDER[index]]
		var lower: Vector2i = survivals[ORDER[index + 1]]
		if wilson(upper.x, upper.y).x <= wilson(lower.x, lower.y).y:
			verdict.failed_gaps.append("%s > %s" % [ORDER[index], ORDER[index + 1]])
	var last: Vector2i = survivals[ORDER[-1]]
	if wilson(last.x, last.y).x <= 0.0:
		verdict.failed_gaps.append("%s > 0" % ORDER[-1])
	verdict.passed = verdict.failed_gaps.is_empty()
	return verdict


## One line saying PASS or FAIL and which gaps fail.
func line() -> String:
	if not missing.is_empty():
		return "FAIL: not judged, no runs for %s" % ", ".join(missing)
	if passed:
		return "PASS: mixed > private > collective > 0, every gap past the 90% intervals"
	return "FAIL: %s does not hold past the 90%% intervals" % ", ".join(failed_gaps)
