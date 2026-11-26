class_name RunPeople
extends RefCounted
## The people of a run as pages show them (ADR 0028): a seated villager's full name, the
## player's, and a seated family's voice with the village's drift applied to a copy, so
## the shared definitions never change. Read from the run state alone.


## "Jianguo Wang" for the family in a villager's seat, its surname alone for a run that
## names nobody, and the demo's villager's surname when the run seats no roster.
static func seat_full_name(state: RunState, seat: int) -> String:
	var entry: RosterEntry = _seated(state, seat)
	if entry == null:
		var keys: Array[String] = RunStarter.DEMO_RUN.name_keys
		return TranslationServer.translate(keys[seat]) if seat >= 0 and seat < keys.size() else ""
	var surname: String = TranslationServer.translate(Roster.name_key(RunDefaults.VILLAGE, entry))
	return Surnames.full_name(state.names.given_name(entry.family_id), surname)


## The player's surname in this run: the profile's when it started, or the fallback.
static func player_surname(state: RunState) -> String:
	return Surnames.or_fallback(state.names.player_surname)


## The player's full name in this run, or their surname alone in one that names nobody.
static func player_full_name(state: RunState) -> String:
	return Surnames.full_name(state.names.player_given_name(), player_surname(state))


## A copy of the seated family's voice, played back at the pitch the village's drift
## moved it to, or null when the run seats no roster. Sent-down youth never drift.
static func seat_voice(state: RunState, seat: int) -> VoiceProfile:
	var entry: RosterEntry = _seated(state, seat)
	if entry == null:
		return null
	var family: FamilyDef = Roster.definition(RunDefaults.VILLAGE, entry)
	if family == null or family.voice == null:
		return null
	var voice: VoiceProfile = family.voice.duplicate() as VoiceProfile
	if entry.template_id.is_empty():
		voice.playback_pitch = state.drift.pitch_factor(family.id)
	return voice


## Every surname a villager's seat can show: each family's and each sent-down youth's.
static func every_surname() -> Array[String]:
	var names: Array[String] = []
	for family: FamilyDef in RunDefaults.VILLAGE.families:
		names.append(TranslationServer.translate(family.name_key))
	for key: String in RunDefaults.VILLAGE.youth_surnames:
		names.append(TranslationServer.translate(key))
	return names


static func _seated(state: RunState, seat: int) -> RosterEntry:
	if state.roster.is_empty() or seat <= 0 or seat >= state.table.size():
		return null
	return Roster.entry(state, state.table[seat])
