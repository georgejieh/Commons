class_name Roster
extends RefCounted
## The village's households during a run (P4.5). Before every Set, families in
## reeducation count down and may return, sent-down youth arrive while fewer than two
## opponents are available, and two available families are seated. All draws are on
## the events stream.

const YOUTH_PREFIX: String = "youth_"


## A new run's roster: every family that starts in the village, plus any unlocked.
static func start(state: RunState, book: VillageBook, unlocked: Array[String]) -> void:
	state.roster.clear()
	for definition: FamilyDef in book.families:
		var joins: bool = definition.unlock == FamilyDef.Unlock.START
		if joins or unlocked.has(definition.id):
			state.roster.append(RosterEntry.new(definition.id))


## Readies the roster for a Set and seats its opponents.
static func prepare_set(state: RunState, book: VillageBook, stream: RandomStream) -> void:
	for found: RosterEntry in state.roster:
		if found.status == RosterEntry.Status.REEDUCATION:
			found.return_timer -= 1
			if found.return_timer <= 0:
				found.status = RosterEntry.Status.ACTIVE
				found.return_timer = 0
	var open: Array[RosterEntry] = available(state)
	while open.size() < book.opponents:
		open.append(_spawn_youth(state, book, stream))
	var table: Array[String] = [RunState.DEFAULT_TABLE[0]]
	for seat: int in book.opponents:
		var pick: RosterEntry = open[stream.next_int(0, open.size() - 1)]
		open.erase(pick)
		pick.sets_seated += 1
		table.append(pick.family_id)
	state.table = table


static func available(state: RunState) -> Array[RosterEntry]:
	return state.roster.filter(
		func(found: RosterEntry) -> bool: return found.status == RosterEntry.Status.ACTIVE
	)


static func entry(state: RunState, family_id: String) -> RosterEntry:
	for found: RosterEntry in state.roster:
		if found.family_id == family_id:
			return found
	return null


## Sends a family away for book.reeducation_sets Sets.
static func reeducate(state: RunState, family_id: String, book: VillageBook) -> void:
	var found: RosterEntry = entry(state, family_id)
	if found == null:
		return
	found.status = RosterEntry.Status.REEDUCATION
	found.return_timer = book.reeducation_sets


## The definition behind a roster entry: its family, or the youth template it came from.
static func definition(book: VillageBook, found: RosterEntry) -> FamilyDef:
	if not found.template_id.is_empty():
		return book.family(found.template_id)
	return book.family(found.family_id)


## The surname shown for a roster entry.
static func name_key(book: VillageBook, found: RosterEntry) -> String:
	if not found.name_key.is_empty():
		return found.name_key
	return definition(book, found).name_key


## How a seated family plays this Set. Rising families gain a tier per rise_sets Sets.
static func config_for(book: VillageBook, found: RosterEntry, seed_value: int) -> BotConfig:
	var family: FamilyDef = definition(book, found)
	var config: BotConfig = BotConfig.from_personality(family.personality, seed_value)
	if family.rising:
		@warning_ignore("integer_division")
		var gained: int = maxi(found.sets_seated - 1, 0) / book.rise_sets
		var tier: int = mini(config.tier + gained, BotConfig.Tier.HARD)
		config.tier = tier as BotConfig.Tier
	return config


static func _spawn_youth(state: RunState, book: VillageBook, stream: RandomStream) -> RosterEntry:
	var templates: Array[FamilyDef] = book.youth_templates
	var template: FamilyDef = templates[stream.next_int(0, templates.size() - 1)]
	var spawned: int = 0
	for found: RosterEntry in state.roster:
		if not found.template_id.is_empty():
			spawned += 1
	var arrival: RosterEntry = RosterEntry.new(YOUTH_PREFIX + str(spawned))
	arrival.template_id = template.id
	arrival.name_key = _free_surname(state, book, stream)
	state.roster.append(arrival)
	return arrival


## A youth surname nobody living in the village holds, or any when all are taken.
static func _free_surname(state: RunState, book: VillageBook, stream: RandomStream) -> String:
	var held: Array[String] = []
	for found: RosterEntry in state.roster:
		if found.status != RosterEntry.Status.DEAD:
			held.append(found.name_key)
	var free: Array[String] = []
	for key: String in book.youth_surnames:
		if not held.has(key):
			free.append(key)
	if free.is_empty():
		free = book.youth_surnames
	return free[stream.next_int(0, free.size() - 1)]
