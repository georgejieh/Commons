class_name RunStarter
extends RefCounted
## The one place a run begins (ADR 0025). From a RunRequest it builds the run's opening
## state: its identity, starting coupons, the village's memory carried in, and for a full
## run the village roster and the family's next generation; then the lineage it inherits,
## its household and its stake's starting meters. It also names the Sets and seat configs
## each kind plays with, so Continue rebuilds exactly the kind that was saved.

const FULL_RUN: FullRunParams = preload("res://data/run/full_run.tres")
const DEMO_RUN: DemoParams = preload("res://data/run/demo.tres")
const HOUSEHOLDS: HouseholdPool = preload("res://data/run/households/households.tres")


## The run's opening state, or null for a request the profile does not allow: a
## household past the open tier, or a stake past the highest unlocked. A profile of null
## is left untouched, and the run carries no memory in and takes the request's lineage.
static func state(request: RunRequest, profile: SaveService = null) -> RunState:
	var data: ProfileData = ProfileData.new() if profile == null else Profile.read(profile)
	if not allows(request, data):
		return null
	var opening: RunState = RunState.new(request.seed_value)
	var start: int = request.start_time
	if start == 0:
		start = int(Time.get_unix_time_from_system())
	opening.identity.id = RunIdentity.make_id(request.seed_value, start)
	opening.identity.kind = request.kind as RunIdentity.Kind
	opening.identity.household = request.household
	opening.identity.stake = request.stake
	opening.coupons = starting_coupons(request.kind)
	var lineage: Dictionary = RunLineage.make(request.lineage_kind, request.lineage_values)
	if profile != null:
		opening.memory = data.memory.carried(RunLoop.DEFAULT_MEMORY)
		lineage = ProfileCommits.start_run(profile, opening)
	if request.kind == RunRequest.FULL:
		Roster.start(opening, RunLoop.DEFAULT_VILLAGE, unlocked_families(data))
	_open(opening, request, lineage)
	return opening


## True when the profile allows what the request asks: no household or one whose tier is
## open, and a stake no higher than the highest unlocked.
static func allows(request: RunRequest, data: ProfileData) -> bool:
	if request.stake < 0 or request.stake > data.stake:
		return false
	if request.household.is_empty():
		return true
	var chosen: HouseholdDef = HOUSEHOLDS.household(request.household)
	return chosen != null and chosen.unlock_tier <= data.finished_runs


## The lineage first, so the heirloom goes into the plot before the household's cards,
## then the household, then the stake's starting meters (ADR 0025).
static func _open(opening: RunState, request: RunRequest, lineage: Dictionary) -> void:
	var run: RunParams = RunLoop.DEFAULT_PARAMS
	RunLineage.apply(opening, str(lineage["kind"]), lineage["values"], run)
	var chosen: HouseholdDef = HOUSEHOLDS.household(request.household)
	if chosen != null:
		RunOpening.household(opening, chosen, _cadre(chosen.cadre_id), run)
	RunOpening.stake(opening, RunStakes.total(request.stake), run)


static func _cadre(cadre_id: String) -> ModifierDef:
	for definition: ModifierDef in RunLoop.all_cadres():
		if definition.id == cadre_id:
			return definition
	return null


## The families the profile has unlocked beyond those every village starts with (ADR
## 0025): those that join after enough finished runs, by their own threshold, and those
## that join after any landlord ending that was not a death, by the profile's count of
## them, which outlives the history's cap.
static func unlocked_families(data: ProfileData) -> Array[String]:
	var unlocked: Array[String] = []
	var landlord: bool = data.landlord_endings > 0
	for family: FamilyDef in RunLoop.DEFAULT_VILLAGE.families:
		match family.unlock:
			FamilyDef.Unlock.RUNS:
				if data.finished_runs >= family.unlock_runs:
					unlocked.append(family.id)
			FamilyDef.Unlock.LANDLORD_ENDING:
				if landlord:
					unlocked.append(family.id)
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
