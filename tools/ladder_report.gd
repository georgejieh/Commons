extends SceneTree
## Draws seeded debuff ladders and writes the tier distribution per Set type and round
## as CSV, from the real debuff pool. Run:
##   godot --headless --path . --script res://tools/ladder_report.gd -- --ladders 100000
## Options: --seed N, --out PATH.

const USAGE: String = "ladder_report.gd -- --ladders N [--seed N] [--out PATH]"
const DEFAULT_OUT: String = "reports/ladder_tiers.csv"
const ROUNDS: int = 4
const POOL: DebuffPool = preload("res://data/run/debuff_pool.tres")


func _initialize() -> void:
	var options: ToolOptions = ToolOptions.new(USAGE)
	if not options.has("ladders"):
		options.refuse("Needs --ladders N.")
	var ladders: int = options.integer("ladders", 0, 1)
	var seed_value: int = options.integer("seed", 0)
	var out: String = options.path("out", DEFAULT_OUT)
	if options.failed():
		quit(2)
		return
	var pool: Array[ModifierDef] = POOL.debuffs
	var tiers: Dictionary[String, int] = {}
	for definition: ModifierDef in pool:
		tiers[definition.id] = definition.tier
	var max_tier: int = ModifierDef.MAX_TIER
	# counts[(set_type * ROUNDS + round) * (max_tier + 1) + tier]; tier 0 is a clean round.
	var counts: PackedInt64Array = []
	counts.resize(RunState.SetType.size() * ROUNDS * (max_tier + 1))
	var stream: RandomStream = RandomStream.new(seed_value)
	for index: int in ladders:
		var set_type: int = index % RunState.SetType.size()
		var ladder: Array[String] = DebuffLadder.draw(
			pool, set_type as RunState.SetType, ROUNDS, stream
		)
		for round_index: int in ROUNDS:
			var tier: int = tiers.get(ladder[round_index], 0)
			counts[(set_type * ROUNDS + round_index) * (max_tier + 1) + tier] += 1
	var saved: bool = ToolFiles.write(out, _csv(counts, ladders, max_tier))
	print("%d ladders, CSV at %s" % [ladders, out])
	quit(0 if saved else 1)


func _csv(counts: PackedInt64Array, ladders: int, max_tier: int) -> String:
	var lines: PackedStringArray = ["set_type,round,tier,count,share"]
	for set_type: int in RunState.SetType.size():
		var per_type: float = ceilf(float(ladders - set_type) / RunState.SetType.size())
		for round_index: int in ROUNDS:
			for tier: int in max_tier + 1:
				var count: int = counts[(set_type * ROUNDS + round_index) * (max_tier + 1) + tier]
				lines.append(
					(
						"%s,%d,%d,%d,%.4f"
						% [
							str(RunState.SetType.keys()[set_type]).to_lower(),
							round_index + 1,
							tier,
							count,
							count / per_type
						]
					)
				)
	return "\n".join(lines) + "\n"
