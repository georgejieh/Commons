extends GdUnitTestSuite
## ADR 0037's soak: a run saved as it plays and resumed from its save at every Set's end
## plays to its end with every count at zero, and is the same run; a run whose save is
## damaged before it is loaded back counts as failed, with the load counted; the report
## lists each count and the failed run's seed. The seed is one whose run ends early, so
## the suite stays quick.

const SEED: int = 16
const SOAK: String = "res://tools/soak.gd"

static var _folder: String = TestFolder.of("test_soak")


## A run whose save and its backup are spoiled just before each is loaded back.
class SpoiltSoak:
	extends SoakDriver

	func _resume() -> void:
		for path: String in [saves.path(), saves.backup_path()]:
			var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
			file.store_string("{")
			file.close()
		super()


var _log: SoakLog


func before() -> void:
	_log = SoakLog.new()
	OS.add_logger(_log)


func after() -> void:
	OS.remove_logger(_log)


func _strategy() -> BalanceStrategy:
	return BalanceDriver.strategy_named("collective")


func test_a_run_saved_and_resumed_at_every_set_end_plays_the_same_with_no_fault() -> void:
	var soaked: SoakDriver = SoakDriver.new(_strategy(), 0, _log, _folder)
	var result: BalanceResult = soaked.play(SEED)
	assert_str(result.failure).is_empty()
	assert_int(soaked.faults.total()).is_equal(0)
	assert_int(result.quotas_played).is_greater(1)
	var plain: BalanceResult = BalanceDriver.new(_strategy()).play(SEED)
	assert_str(result.csv(false)).is_equal(plain.csv(false))
	assert_bool(FileAccess.file_exists(_folder.path_join("run.json"))).is_false()


func test_a_damaged_save_fails_the_run_and_is_counted() -> void:
	var spoilt: SpoiltSoak = SpoiltSoak.new(_strategy(), 0, _log, _folder)
	var result: BalanceResult = spoilt.play(SEED)
	assert_bool(result.failed()).is_true()
	assert_int(spoilt.faults.load_failures).is_equal(1)
	assert_int(spoilt.faults.total()).is_equal(1)
	var failed: Array[BalanceResult] = [result]
	var report: String = load(SOAK).call("markdown", spoilt.faults, failed, 1, SEED, "")
	assert_str(report).contains("| load failures | 1 |").contains("- seed %d," % SEED)
	spoilt.saves.delete()


func test_runs_take_the_strategies_and_stakes_in_turn() -> void:
	var soak: GDScript = load(SOAK)
	var strategies: int = BalanceDriver.STRATEGIES.size()
	assert_that(soak.call("plan", 0)).is_equal(Vector2i(0, 0))
	assert_that(soak.call("plan", 1)).is_equal(Vector2i(1, 0))
	assert_that(soak.call("plan", strategies)).is_equal(Vector2i(0, 1))
	var last: int = (RunStakes.last() + 1) * strategies
	assert_that(soak.call("plan", last)).is_equal(Vector2i(0, 0))
