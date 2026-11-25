class_name BalanceReport
extends RefCounted
## Writes the harness's summary in Markdown (ADR 0027): per strategy its survival with
## a 90% Wilson interval, each ending's share, deaths by meter and their Year, how far it
## got and its final numbers; then the ordering verdict, the runs that failed, and the
## slowest and fastest run.

## A result's field and the label its row shows.
const FINAL_NUMBERS: Array[Array] = [
	["coupons", "Mean final coupons"],
	["famine", "Mean final Famine"],
	["denunciation", "Mean final Denunciation"],
	["resentment", "Mean final Resentment"],
	["starved", "Mean families starved"],
	["cadres", "Mean Cadres held"],
	["campaigns_used", "Mean Campaigns used"],
]
const DEATHS: Array[Array] = [
	[Endings.DEATH_FAMINE, "Died of Famine"],
	[Endings.DEATH_DENUNCIATION, "Died of Denunciation"],
]


## The whole report of tally, opened by what setup says the run was.
static func markdown(tally: BalanceTally, setup: BalanceSetup) -> String:
	var lines: PackedStringArray = PackedStringArray(["# Balance harness", ""])
	lines.append_array(_setup(tally, setup))
	lines.append_array(_table(tally))
	lines.append_array(_endings(tally))
	lines.append_array(BalanceCurve.sections(tally))
	lines.append_array(_verdict(tally, setup.seeds))
	lines.append_array(_failures(tally))
	lines.append_array(_extremes(tally))
	return "\n".join(lines) + "\n"


static func _setup(tally: BalanceTally, setup: BalanceSetup) -> PackedStringArray:
	var seeds: int = setup.seeds
	var first: int = setup.first_seed
	var lines: PackedStringArray = PackedStringArray()
	lines.append(
		(
			"%d seeds a strategy (%d to %d), stake %d, Poor Peasants, every unlock tier open."
			% [seeds, first, first + seeds - 1, setup.stake]
		)
	)
	var budget: String = "no time budget"
	if setup.minutes > 0.0:
		budget = "a %s-minute budget" % str(setup.minutes)
	lines.append(
		(
			"Played in %.0f s on %d jobs, %s. The Hard bot plays the player's cards."
			% [setup.wall_seconds, setup.jobs, budget]
		)
	)
	lines.append("Strategies: %s." % ", ".join(tally.strategies))
	var own: int = BotConfig.DEFAULT_WEIGHTS.expert_samples
	var samples: int = setup.expert_samples
	if samples > 0:
		lines.append(
			(
				"Expert villagers sample %d deals (--expert-samples), not the game's %d."
				% [samples, own]
			)
		)
	else:
		lines.append("Expert villagers sample the game's own %d deals." % own)
	lines.append("")
	return lines


static func _table(tally: BalanceTally) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("| | " + " | ".join(tally.strategies) + " |")
	lines.append("| --- |" + " ---: |".repeat(tally.strategies.size()))
	var survivals: Dictionary[String, Vector2i] = tally.survivals()
	lines.append(_row(tally, "Runs", func(name: String) -> String: return str(survivals[name].y)))
	lines.append(
		_row(
			tally,
			"Survived the eighth Year (90% interval)",
			func(name: String) -> String: return _survival(survivals[name])
		)
	)
	for death: Array in DEATHS:
		lines.append(
			_row(
				tally,
				"%s (mean Year)" % death[1],
				func(name: String) -> String: return _death(tally, name, death[0])
			)
		)
	lines.append(
		_row(
			tally,
			"Mean Year reached",
			func(name: String) -> String: return "%.2f" % tally.mean(name, "year")
		)
	)
	lines.append(
		_row(
			tally,
			"Quotas met, of Quotas played",
			func(name: String) -> String: return _percent(tally.quotas_met_share(name))
		)
	)
	for number: Array in FINAL_NUMBERS:
		lines.append(
			_row(
				tally,
				number[1],
				func(name: String) -> String: return "%.1f" % tally.mean(name, number[0])
			)
		)
	lines.append("")
	return lines


static func _endings(tally: BalanceTally) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray(["## Endings", ""])
	lines.append("| Outcome | " + " | ".join(tally.strategies) + " |")
	lines.append("| --- |" + " ---: |".repeat(tally.strategies.size()))
	for outcome: String in Endings.ENDINGS + Endings.DEATHS:
		lines.append(
			_row(
				tally,
				outcome,
				func(name: String) -> String: return _percent(tally.outcome_share(name, outcome))
			)
		)
	lines.append("")
	return lines


static func _verdict(tally: BalanceTally, seeds: int) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray(["## Ordering", ""])
	var verdict: BalanceVerdict = tally.verdict()
	lines.append("**%s**" % verdict.line())
	lines.append("")
	if verdict.missing.is_empty():
		var survivals: Dictionary[String, Vector2i] = tally.survivals()
		for strategy: String in BalanceVerdict.ORDER:
			lines.append("- %s: %s" % [strategy, _survival(survivals[strategy])])
		lines.append("")
	if seeds < BalanceVerdict.NIGHTLY_SEEDS:
		lines.append(
			(
				"A local check: %d seeds a strategy, fewer than the %d the nightly reading needs."
				% [seeds, BalanceVerdict.NIGHTLY_SEEDS]
			)
		)
		lines.append("")
	return lines


static func _failures(tally: BalanceTally) -> PackedStringArray:
	var failed: Array[BalanceResult] = tally.failures()
	if failed.is_empty():
		return PackedStringArray(
			["No run failed: every command was accepted and no error was logged.", ""]
		)
	var lines: PackedStringArray = PackedStringArray(["## Failed runs", ""])
	for run: BalanceResult in failed:
		lines.append("- seed %d, %s: %s" % [run.seed_value, run.strategy, run.failure])
	lines.append("")
	return lines


static func _extremes(tally: BalanceTally) -> PackedStringArray:
	var runs: Array[BalanceResult] = tally.runs()
	if runs.is_empty():
		return PackedStringArray()
	var slowest: BalanceResult = runs[0]
	var fastest: BalanceResult = runs[0]
	var total: float = 0.0
	for run: BalanceResult in runs:
		total += run.seconds
		if run.seconds > slowest.seconds:
			slowest = run
		if run.seconds < fastest.seconds:
			fastest = run
	return PackedStringArray(
		[
			"## Time",
			"",
			"- Mean run: %.1f s" % (total / runs.size()),
			"- Slowest: %s" % _named(slowest),
			"- Fastest: %s" % _named(fastest),
		]
	)


static func _named(run: BalanceResult) -> String:
	return (
		"seed %d, %s, %.1f s, %s at Year %d"
		% [run.seed_value, run.strategy, run.seconds, run.outcome, run.year]
	)


static func _row(tally: BalanceTally, label: String, cell: Callable) -> String:
	var cells: PackedStringArray = PackedStringArray()
	for strategy: String in tally.strategies:
		cells.append(str(cell.call(strategy)))
	return "| %s | %s |" % [label, " | ".join(cells)]


static func _survival(count: Vector2i) -> String:
	var bounds: Vector2 = BalanceVerdict.wilson(count.x, count.y)
	var share: float = float(count.x) / count.y if count.y > 0 else 0.0
	return "%s (%s to %s)" % [_percent(share), _percent(bounds.x), _percent(bounds.y)]


static func _death(tally: BalanceTally, strategy: String, outcome: String) -> String:
	var share: float = tally.outcome_share(strategy, outcome)
	if share == 0.0:
		return "0.0%"
	return "%s (%.2f)" % [_percent(share), tally.mean(strategy, "year", outcome)]


static func _percent(share: float) -> String:
	return "%.1f%%" % (share * 100.0)
