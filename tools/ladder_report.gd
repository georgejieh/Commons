extends SceneTree
## Draws seeded debuff ladders and writes the tier distribution per Set type and round
## as CSV. Uses the Plan's pool until P4.12 adds the real one. Run:
##   godot --headless --path . --script res://tools/ladder_report.gd -- --ladders 100000
## Options: --seed N, --out PATH.

const DEFAULT_OUT: String = "res://reports/ladder_tiers.csv"
const ROUNDS: int = 4


func _initialize() -> void:
	var options: Dictionary[String, String] = _options()
	var ladders: int = int(options.get("ladders", "0"))
	if ladders < 1:
		printerr("Needs --ladders N of at least 1.")
		quit(2)
		return
	var pool: Array[ModifierDef] = PlanDebuffs.pool()
	var tiers: Dictionary[String, int] = {}
	for definition: ModifierDef in pool:
		tiers[definition.id] = definition.tier
	var max_tier: int = ModifierDef.MAX_TIER
	# counts[(set_type * ROUNDS + round) * (max_tier + 1) + tier]; tier 0 is a clean round.
	var counts: PackedInt64Array = []
	counts.resize(RunState.SetType.size() * ROUNDS * (max_tier + 1))
	var stream: RandomStream = RandomStream.new(int(options.get("seed", "0")))
	for index: int in ladders:
		var set_type: int = index % RunState.SetType.size()
		var ladder: Array[String] = DebuffLadder.draw(
			pool, set_type as RunState.SetType, ROUNDS, stream
		)
		for round_index: int in ROUNDS:
			var tier: int = tiers.get(ladder[round_index], 0)
			counts[(set_type * ROUNDS + round_index) * (max_tier + 1) + tier] += 1
	var out: String = options.get("out", DEFAULT_OUT)
	var saved: bool = _save(out, _csv(counts, ladders, max_tier))
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


func _options() -> Dictionary[String, String]:
	var options: Dictionary[String, String] = {}
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var at: int = 0
	while at < args.size():
		var name: String = args[at].trim_prefix("--")
		var has_value: bool = at + 1 < args.size() and not args[at + 1].begins_with("--")
		options[name] = args[at + 1] if has_value else ""
		at += 2 if has_value else 1
	return options


func _save(path: String, text: String) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("Can't write %s" % path)
		return false
	file.store_string(text)
	return true
