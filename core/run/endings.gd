class_name Endings
extends RefCounted
## How a run ends (ADR 0024), worked out from the final RunState alone, so a save loaded
## at the run's end gives the same page. A run whose meter reached death gets the record
## of that death and no epilogue. A run that survived its last Year gets one of six
## endings from its class and the meter in its high band, or The Commons in place of The
## Secret Contract when it also ended collective. Nothing here changes the state it reads.

## The peasant ending when neither meter ended in its high band.
const SECRET_CONTRACT: String = "secret_contract"
## The ending that takes The Secret Contract's place when the run also ended collective.
const THE_COMMONS: String = "the_commons"
## The peasant ending when Famine ended in its high band.
const LEAN_YEARS: String = "lean_years"
## The peasant ending when Denunciation ended in its high band.
const LABELED: String = "labeled"
## The landlord ending when neither meter ended in its high band.
const BENEVOLENT_LANDLORD: String = "benevolent_landlord"
## The landlord ending when Famine ended in its high band.
const FULL_GRANARY: String = "full_granary"
## The landlord ending when Denunciation ended in its high band.
const STRUGGLED: String = "struggled"
## The death of a run whose Famine reached its death threshold.
const DEATH_FAMINE: String = "death_famine"
## The death of a run whose Denunciation reached its death threshold.
const DEATH_DENUNCIATION: String = "death_denunciation"
## Every ending of a run that survived its last Year, in the order of its string keys.
const ENDINGS: Array[String] = [
	SECRET_CONTRACT,
	THE_COMMONS,
	LEAN_YEARS,
	LABELED,
	BENEVOLENT_LANDLORD,
	FULL_GRANARY,
	STRUGGLED,
]
## Both deaths, which get a record and no epilogue.
const DEATHS: Array[String] = [DEATH_FAMINE, DEATH_DENUNCIATION]
## A peasant run's ending by the meter in its high band, or by none ("").
const PEASANT: Dictionary[String, String] = {
	"": SECRET_CONTRACT,
	RunMeters.FAMINE: LEAN_YEARS,
	RunMeters.DENUNCIATION: LABELED,
}
## A landlord run's ending by the meter in its high band, or by none ("").
const LANDLORD: Dictionary[String, String] = {
	"": BENEVOLENT_LANDLORD,
	RunMeters.FAMINE: FULL_GRANARY,
	RunMeters.DENUNCIATION: STRUGGLED,
}
## Endings whose epilogue adds a line naming the dead.
const ROLL_CALL: Array[String] = [LEAN_YEARS, FULL_GRANARY]
## Endings that close on the historical note.
const NOTED: Array[String] = [SECRET_CONTRACT, THE_COMMONS]
## A family's disposition when feeding it outweighed the harm done to it.
const WARM: String = "warm"
## A family's disposition when it is neither warm nor bitter.
const WARY: String = "wary"
## A family's disposition when its pull is at or above the data's bitter_pull.
const BITTER: String = "bitter"
## Every disposition, in the order an ending's epilogue lines are keyed by.
const DISPOSITIONS: Array[String] = [WARM, WARY, BITTER]
## The string key of the epilogue line for families away in reeducation.
const REEDUCATION_KEY: String = "epilogue.state.reeducation"
## The string key of the epilogue line for deposed families.
const DEPOSED_KEY: String = "epilogue.state.deposed"
## The string key of the epilogue line that names the dead.
const MISSING_KEY: String = "epilogue.missing"
## The string key of the historical note that closes The Secret Contract and The Commons.
const NOTE_KEY: String = "ending.note.xiaogang"
## The thresholds used when a caller gives none.
const DEFAULT_PARAMS: EndingParams = preload("res://data/run/endings.tres")


## The ending's ID, or the death's when a meter reached its death threshold.
static func outcome(
	state: RunState, meters: MeterTable, params: EndingParams = DEFAULT_PARAMS
) -> String:
	if RunMeters.dead(state, meters):
		var by_denunciation: bool = death_meter(state, meters) == RunMeters.DENUNCIATION
		return DEATH_DENUNCIATION if by_denunciation else DEATH_FAMINE
	var high: String = high_meter(state, meters)
	if YearClass.is_landlord(state):
		return LANDLORD[high]
	if high.is_empty() and collective(state, meters, params):
		return THE_COMMONS
	return PEASANT[high]


## True when outcome_id is a death, which has a record and no epilogue.
static func is_death(outcome_id: String) -> bool:
	return DEATHS.has(outcome_id)


## The meter that ended a run, read from its saved values: Denunciation first when both
## reached death, as the loop rules.
static func death_meter(state: RunState, meters: MeterTable) -> String:
	if state.denunciation >= meters.denunciation.death:
		return RunMeters.DENUNCIATION
	return RunMeters.FAMINE


## The meter in its high band, or "" for neither. When both are, the larger decides, and
## Denunciation a tie.
static func high_meter(state: RunState, meters: MeterTable) -> String:
	var famine: bool = state.famine >= meters.famine.high
	var denunciation: bool = state.denunciation >= meters.denunciation.high
	if denunciation and (not famine or state.denunciation >= state.famine):
		return RunMeters.DENUNCIATION
	return RunMeters.FAMINE if famine else ""


## Played through the collective without standing out: low Resentment, both meters
## below mid.
static func collective(state: RunState, meters: MeterTable, params: EndingParams) -> bool:
	return (
		state.resentment <= params.collective_resentment
		and state.famine < meters.famine.mid
		and state.denunciation < meters.denunciation.mid
	)


## Every family not dead is named in exactly one line: its state's line in reeducation or
## deposed, otherwise the ending's line for its disposition. Families that would get the
## same line share it, and the lines run in the roster order of each one's first family.
## Lean Years and Full Granary add one line naming the dead, when there are any. A death
## has no epilogue.
static func epilogue(
	state: RunState,
	outcome_id: String,
	book: VillageBook,
	memory: MemoryParams,
	params: EndingParams = DEFAULT_PARAMS
) -> Array[EpilogueLine]:
	var lines: Array[EpilogueLine] = []
	if is_death(outcome_id):
		return lines
	var by_key: Dictionary[String, EpilogueLine] = {}
	var missing: EpilogueLine = EpilogueLine.new(MISSING_KEY)
	for entry: RosterEntry in state.roster:
		var surname: String = _name_key(book, entry)
		var key: String = ""
		match entry.status:
			RosterEntry.Status.DEAD:
				missing.name_keys.append(surname)
				continue
			RosterEntry.Status.REEDUCATION:
				key = REEDUCATION_KEY
			RosterEntry.Status.DEPOSED:
				key = DEPOSED_KEY
			_:
				var feeling: String = disposition(state.memory, entry.family_id, memory, params)
				key = line_key(outcome_id, feeling)
		if not by_key.has(key):
			by_key[key] = EpilogueLine.new(key)
			lines.append(by_key[key])
		by_key[key].add(entry.family_id, surname)
	if ROLL_CALL.has(outcome_id) and not missing.name_keys.is_empty():
		lines.append(missing)
	return lines


## How a family remembers the player: warm when feeding outweighs harm, bitter when its
## pull is at or above bitter_pull, wary otherwise, a family with no history included.
static func disposition(
	memory: VillageMemory, family_id: String, weights: MemoryParams, params: EndingParams
) -> String:
	if memory.grudge(family_id, weights) < 0.0:
		return WARM
	if memory.pull(family_id, weights) >= params.bitter_pull:
		return BITTER
	return WARY


## The string key of the ending's or death's title.
static func title_key(outcome_id: String) -> String:
	return _prefix(outcome_id) + ".title"


## The string key of the ending's or death's text.
static func text_key(outcome_id: String) -> String:
	return _prefix(outcome_id) + ".text"


## The string key of an ending's epilogue line for a family's disposition.
static func line_key(ending_id: String, feeling: String) -> String:
	return "epilogue.%s.%s" % [ending_id, feeling]


## Every string key an ending, a death or an epilogue can use.
static func keys() -> Array[String]:
	var found: Array[String] = [REEDUCATION_KEY, DEPOSED_KEY, MISSING_KEY, NOTE_KEY]
	for outcome_id: String in ENDINGS + DEATHS:
		found.append(title_key(outcome_id))
		found.append(text_key(outcome_id))
	for ending_id: String in ENDINGS:
		for feeling: String in DISPOSITIONS:
			found.append(line_key(ending_id, feeling))
	return found


static func _prefix(outcome_id: String) -> String:
	if is_death(outcome_id):
		return "death." + outcome_id.trim_prefix("death_")
	return "ending." + outcome_id


## A family's surname key, from its roster entry or its definition. A family the book
## does not hold keeps its ID.
static func _name_key(book: VillageBook, entry: RosterEntry) -> String:
	if not entry.name_key.is_empty():
		return entry.name_key
	var family: FamilyDef = Roster.definition(book, entry)
	return entry.family_id if family == null else family.name_key
