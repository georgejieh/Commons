class_name PerfLimits
extends RefCounted
## The performance budget table (P5.3) and the sample sizes tools/perf_budget.gd takes by
## default. Every threshold the tool judges by is here and nowhere else.

const CLASSIFY_MAX_USEC: float = 50.0
const MOVEGEN_MEDIAN_MAX_USEC: float = 1000.0
const BOT_MEDIAN_MAX_MS: float = 30.0
const BOT_P99_MAX_MS: float = 100.0
const EXPERT_P99_MAX_MS: float = 400.0
## One frame at 60 fps is 16.67 ms; the budget says 16.6. A vsynced frame clock lands a
## few tenths of a millisecond either side of the refresh, so the verdict allows the slack.
const FRAME_MAX_MS: float = 16.6
const FRAME_SLACK_MS: float = 0.5
const SAVE_MAX_BYTES: int = 64 * 1024
const SAVE_TIME_MAX_MS: float = 50.0
const MEMORY_MAX_BYTES: int = 512 * 1024 * 1024
const STARTUP_MAX_MS: float = 5000.0

const DEFAULT_SEED: int = 0
## Random hands timed for classification and for move generation.
const DEFAULT_HANDS: int = 20000
const DEFAULT_MOVEGEN_HANDS: int = 2000
## Seeded deals each of Easy, Medium and Hard plays, all three seats the same tier.
const DEFAULT_BOT_DEALS: int = 60
const DEFAULT_EXPERT_DEALS: int = 20
## Sets (Quotas) a run plays before its save is measured, and the saves and loads timed.
const DEFAULT_SAVE_SETS: int = 8
const DEFAULT_SAVE_REPS: int = 40
const MIN_SAVE_REPS: int = 20
const DEFAULT_FRAME_SECONDS: float = 40.0

const DEFAULT_OUT: String = "res://reports/perf_budget.md"
const SANDBOX: String = "user://perf_budget/"
