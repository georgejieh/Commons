class_name RunStarter
extends RefCounted
## The one place a run begins (ADR 0025). From a RunRequest it builds the run's opening
## state: its identity, starting coupons, the village's memory carried in, and for a full
## run the village roster and the family's next generation. It also names the Sets and
## seat configs each kind plays with, so Continue rebuilds exactly the kind that was saved.

const FULL_RUN: FullRunParams = preload("res://data/run/full_run.tres")
const DEMO_RUN: DemoParams = preload("res://data/run/demo.tres")


## The run's opening state. A profile of null is left untouched, and the run carries no
## memory in.
static func state(request: RunRequest, profile: SaveService = null) -> RunState:
	var opening: RunState = RunState.new(request.seed_value)
	var start: int = request.start_time
	if start == 0:
		start = int(Time.get_unix_time_from_system())
	opening.identity.id = RunIdentity.make_id(request.seed_value, start)
	opening.identity.kind = request.kind as RunIdentity.Kind
	opening.identity.household = request.household
	opening.identity.stake = request.stake
	opening.coupons = starting_coupons(request.kind)
	var data: ProfileData = ProfileData.new()
	if profile != null:
		data = Profile.read(profile)
		opening.memory = data.memory.carried(RunLoop.DEFAULT_MEMORY)
		ProfileCommits.start_run(profile, opening)
	if request.kind == RunRequest.FULL:
		Roster.start(opening, RunLoop.DEFAULT_VILLAGE, unlocked_families(data))
	return opening


## The families the profile has unlocked beyond those every village starts with. Empty
## until villager unlocks arrive (ADR 0025, step 3); the roster already takes the list.
static func unlocked_families(_data: ProfileData) -> Array[String]:
	var unlocked: Array[String] = []
	return unlocked


static func starting_coupons(kind: int) -> int:
	return FULL_RUN.starting_coupons if kind == RunRequest.FULL else DEMO_RUN.starting_coupons


## The Sets a kind of run plays: the full run's eight Years, or the demo's one.
static func sets(kind: int) -> SetConfig:
	return SetConfig.new(FULL_RUN.sets if kind == RunRequest.FULL else DEMO_RUN.sets)


## One config per seat. A full run seats its roster each Set, which replaces the
## villagers' configs; the demo plays its two fixed villagers by its tiers.
static func configs(_kind: int) -> Array[BotConfig]:
	var configs_out: Array[BotConfig] = []
	for tier: int in DEMO_RUN.tiers:
		configs_out.append(BotConfig.new(BotConfig.DEFAULT_WEIGHTS, tier as BotConfig.Tier))
	return configs_out


## The kind of run a save holds, read from its checkpoint, or the demo's for a save that
## names none.
static func saved_kind(data: Dictionary) -> int:
	var checkpoint: Variant = data.get("checkpoint")
	if not checkpoint is Dictionary:
		return RunRequest.DEMO
	var saved: Dictionary = checkpoint
	if not RunIdentity.is_valid(saved.get("identity")):
		return RunRequest.DEMO
	return RunIdentity.from_dict(saved["identity"]).kind


## True when the run save, or its backup, holds a run that loads.
static func resumable(saves: SaveService) -> bool:
	var loaded: SaveLoad = saves.load_save()
	return (
		loaded.status == SaveLoad.Status.OK or loaded.status == SaveLoad.Status.RESTORED_FROM_BACKUP
	)
