class_name BalanceTally
extends RefCounted
## Adds up the harness's runs by strategy, and writes them as CSV, one row per run, by
## seed and then by strategy in the order they were asked for.

var strategies: Array[String] = []
var _runs: Array[BalanceResult] = []


func _init(names: Array[String] = BalanceDriver.STRATEGIES) -> void:
	strategies = names.duplicate()


func add(result: BalanceResult) -> void:
	_runs.append(result)


## Every run, failed ones too, by seed and then strategy.
func runs() -> Array[BalanceResult]:
	var sorted: Array[BalanceResult] = _runs.duplicate()
	sorted.sort_custom(
		func(a: BalanceResult, b: BalanceResult) -> bool:
			if a.seed_value != b.seed_value:
				return a.seed_value < b.seed_value
			return strategies.find(a.strategy) < strategies.find(b.strategy)
	)
	return sorted


## The runs of one strategy that played to their end.
func played(strategy: String) -> Array[BalanceResult]:
	return runs().filter(
		func(run: BalanceResult) -> bool: return run.strategy == strategy and not run.failed()
	)


func failures() -> Array[BalanceResult]:
	return runs().filter(func(run: BalanceResult) -> bool: return run.failed())


## Survived runs (x) out of runs played to their end (y), by strategy.
func survivals() -> Dictionary[String, Vector2i]:
	var out: Dictionary[String, Vector2i] = {}
	for strategy: String in strategies:
		var counted: Array[BalanceResult] = played(strategy)
		var survived: int = (
			counted.filter(func(run: BalanceResult) -> bool: return run.survived).size()
		)
		out[strategy] = Vector2i(survived, counted.size())
	return out


func verdict() -> BalanceVerdict:
	return BalanceVerdict.judge(survivals())


## The share of a strategy's runs with this outcome.
func outcome_share(strategy: String, outcome: String) -> float:
	var counted: Array[BalanceResult] = played(strategy)
	if counted.is_empty():
		return 0.0
	var matched: int = (
		counted.filter(func(run: BalanceResult) -> bool: return run.outcome == outcome).size()
	)
	return float(matched) / counted.size()


## The mean of a result's field over a strategy's runs, or over those with an outcome.
func mean(strategy: String, field: String, outcome: String = "") -> float:
	var counted: Array[BalanceResult] = played(strategy)
	if not outcome.is_empty():
		counted = counted.filter(func(run: BalanceResult) -> bool: return run.outcome == outcome)
	if counted.is_empty():
		return 0.0
	var total: float = 0.0
	for run: BalanceResult in counted:
		total += float(run.get(field))
	return total / counted.size()


## Quotas met as a share of Quotas played, over a strategy's runs.
func quotas_met_share(strategy: String) -> float:
	var met: int = 0
	var played_quotas: int = 0
	for run: BalanceResult in played(strategy):
		met += run.quotas_met
		played_quotas += run.quotas_played
	return float(met) / played_quotas if played_quotas > 0 else 0.0


func csv(with_seconds: bool = true) -> String:
	var lines: PackedStringArray = PackedStringArray([BalanceResult.HEADER])
	for run: BalanceResult in runs():
		lines.append(run.csv(with_seconds))
	return "\n".join(lines) + "\n"
