class_name BalanceCurve
extends RefCounted
## The harness report's Quota by Quota sections (ADR 0027): for each strategy, how far
## its runs got against each Quota's target; how the player's scoring per round grows;
## and where the coupons came from and went.

const EARNED_LABELS: Dictionary[String, String] = {
	"rewards": "Earned: Quota rewards",
	"overfulfilment": "Earned: overfulfilment",
	"cadres_and_campaigns": "Earned: Cadres and Campaigns",
}
const SPENT_LABELS: Dictionary[String, String] = {
	"directives": "Spent: Directives",
	"cadres": "Spent: state store Cadres",
	"reforms": "Spent: Reforms",
	"envelopes": "Spent: envelopes",
	"campaigns": "Spent: state store Campaigns",
	"deck_cards": "Spent: deck stall cards",
	"marks": "Spent: desk marks, both counters",
	"market": "Spent: other black market goods",
	"rerolls": "Spent: rerolls",
}
## The percentiles of progress shown, as fractions.
const QUARTILES: Array[float] = [0.25, 0.5, 0.75]


## The report's sections on how far each strategy got: Quota by Quota, then growth and
## coupons.
static func sections(tally: BalanceTally) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for strategy: String in tally.strategies:
		lines.append_array(_targets(tally, strategy))
	lines.append_array(_growth(tally))
	lines.append_array(_coupons(tally))
	return lines


static func _targets(tally: BalanceTally, strategy: String) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray(["## Quota by Quota: %s" % strategy, ""])
	lines.append(
		(
			"Reached counts the runs still going at the Quota; the rest are of those that"
			+ " played it to its end. Progress is banked grain as a share of the target."
		)
	)
	lines.append("")
	lines.append("| Quota | Year | Kind | Reached | Finished | Met | Target | p25 | p50 | p75 |")
	lines.append("| ---: | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |")
	var runs: Array[BalanceResult] = tally.played(strategy)
	for index: int in range(1, _last_index(runs) + 1):
		var rows: Array[BalanceQuota] = tally.quota_rows(strategy, index)
		var reached: int = (
			runs.filter(func(run: BalanceResult) -> bool: return run.quota >= index).size()
		)
		if rows.is_empty():
			lines.append("| %d | | | %d | 0 | | | | | |" % [index, reached])
			continue
		var met: int = rows.filter(func(row: BalanceQuota) -> bool: return row.met).size()
		var shares: PackedFloat64Array = _sorted(
			rows, func(row: BalanceQuota) -> float: return row.share()
		)
		var targets: PackedFloat64Array = _sorted(
			rows, func(row: BalanceQuota) -> float: return row.target
		)
		var cells: PackedStringArray = PackedStringArray(
			[
				str(index),
				str(rows[0].year),
				rows[0].kind,
				str(reached),
				str(rows.size()),
				"%.0f%%" % (100.0 * met / rows.size()),
				"%.0f" % ToolStats.interpolated(targets, 0.5),
			]
		)
		for fraction: float in QUARTILES:
			cells.append("%.2f" % ToolStats.interpolated(shares, fraction))
		lines.append("| %s |" % " | ".join(cells))
	lines.append("")
	return lines


static func _growth(tally: BalanceTally) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray(["## Scoring per round", ""])
	lines.append("Median grain banked per round played, by Quota, over the runs that finished it.")
	lines.append("")
	lines.append("| Quota | " + " | ".join(tally.strategies) + " |")
	lines.append("| ---: |" + " ---: |".repeat(tally.strategies.size()))
	var last: int = 0
	for strategy: String in tally.strategies:
		last = maxi(last, _last_index(tally.played(strategy)))
	for index: int in range(1, last + 1):
		var cells: PackedStringArray = PackedStringArray([str(index)])
		for strategy: String in tally.strategies:
			var rows: Array[BalanceQuota] = tally.quota_rows(strategy, index)
			var per_round: PackedFloat64Array = _sorted(
				rows, func(row: BalanceQuota) -> float: return row.per_round()
			)
			cells.append("" if rows.is_empty() else "%.0f" % ToolStats.interpolated(per_round, 0.5))
		lines.append("| %s |" % " | ".join(cells))
	lines.append("")
	return lines


static func _coupons(tally: BalanceTally) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray(["## Coupons per Quota played", ""])
	lines.append(
		(
			"Means over every Quota played to its end. Cadres and Campaigns are what a Set paid"
			+ " besides its reward and bonus, and any rise at the shops (Grain Loan)."
		)
	)
	lines.append("")
	lines.append("| | " + " | ".join(tally.strategies) + " |")
	lines.append("| --- |" + " ---: |".repeat(tally.strategies.size()))
	for source: String in BalanceLedger.EARNED:
		lines.append(_flow_row(tally, EARNED_LABELS[source], source, true))
	for use: String in BalanceLedger.SPENT:
		lines.append(_flow_row(tally, SPENT_LABELS[use], use, false))
	lines.append("")
	return lines


static func _flow_row(tally: BalanceTally, label: String, key: String, earned: bool) -> String:
	var cells: PackedStringArray = PackedStringArray()
	for strategy: String in tally.strategies:
		var total: int = 0
		var quotas: int = 0
		for run: BalanceResult in tally.played(strategy):
			total += run.ledger.earned[key] if earned else run.ledger.spent[key]
			quotas += run.ledger.quotas.size()
		cells.append("%.2f" % (float(total) / quotas) if quotas > 0 else "")
	return "| %s | %s |" % [label, " | ".join(cells)]


static func _last_index(runs: Array[BalanceResult]) -> int:
	var last: int = 0
	for run: BalanceResult in runs:
		last = maxi(last, run.quota)
	return last


static func _sorted(rows: Array[BalanceQuota], value: Callable) -> PackedFloat64Array:
	var values: PackedFloat64Array = PackedFloat64Array()
	for row: BalanceQuota in rows:
		values.append(value.call(row))
	values.sort()
	return values
