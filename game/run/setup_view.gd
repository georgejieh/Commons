class_name SetupView
extends RefCounted
## What run setup offers a full run (ADR 0025), read from the profile: the households,
## open or locked by finished runs; the stakes, unlocked up to the profile's highest; the
## one line saying what the last generation left; the generation this run will be, and
## the player's own name in it, drawn from the seed the run will start with (ADR 0028).
## Only the first locked stake says how it opens, since its line names the stake below.

const HOUSEHOLDS: HouseholdPool = preload("res://data/run/households/households.tres")
const LINEAGE: LineageParams = preload("res://data/run/lineage.tres")
const SUIT_KEYS: Array[String] = RunController.SUIT_KEYS

var households: Array[UnlockSheet] = []
var stakes: Array[UnlockSheet] = []
## What was inherited, in one line, or empty for nothing.
var inherited: String = ""
## The generation the next run is, from 1.
var generation: int = 1
## The highest stake unlocked, which the page opens on.
var top_stake: int = 0
## "Jianguo Zhang": the name the player will have in a run started from the seed.
var player_name: String = ""


static func of(profile: SaveService, seed_value: int = 0) -> SetupView:
	return from_data(Profile.read(profile), seed_value)


static func from_data(data: ProfileData, seed_value: int = 0) -> SetupView:
	var view: SetupView = SetupView.new()
	view.generation = data.generation + 1
	var surname: String = Surnames.or_fallback(data.surname)
	var given: String = RunNames.player_given(seed_value, view.generation, surname)
	view.player_name = Surnames.full_name(given, surname)
	view.top_stake = mini(data.stake, RunStakes.last())
	var base: int = RunStarter.FULL_RUN.starting_coupons
	for household: HouseholdDef in HOUSEHOLDS.households:
		var left: int = RunUnlocks.runs_left(household.unlock_tier, data.finished_runs)
		var sheet: UnlockSheet = UnlockSheet.locked(UnlockSheet.runs_line(left))
		if left == 0:
			var rules: String = TranslationServer.translate(household.text_key).format(
				household.text_values(base)
			)
			sheet = UnlockSheet.opened(
				household.id, TranslationServer.translate(household.name_key), rules
			)
		sheet.index = view.households.size()
		view.households.append(sheet)
	var list: Array[StakeDef] = RunStakes.STAKES.stakes
	for index: int in list.size():
		var sheet: UnlockSheet = UnlockSheet.locked("")
		if index <= view.top_stake:
			sheet = UnlockSheet.opened(
				list[index].id, TranslationServer.translate(list[index].name_key), _rule(index)
			)
		elif index == view.top_stake + 1:
			var below: String = TranslationServer.translate(list[view.top_stake].name_key)
			sheet = UnlockSheet.locked(
				TranslationServer.translate("unlock.win_at").format({"stake": below})
			)
		sheet.index = index
		view.stakes.append(sheet)
	view.inherited = inherited_line(data.lineage_kind, data.lineage_values)
	return view


## The household run setup opens on.
func default_household() -> String:
	return HOUSEHOLDS.default_id


## The rules a stake plays under, one line each: its own and every lower stake's, which it
## keeps, or the base's line alone for the base.
func stake_rules(stake: int) -> Array[String]:
	var lines: Array[String] = []
	for index: int in range(1, stake + 1):
		lines.append(_rule(index))
	if lines.is_empty():
		lines.append(_rule(0))
	return lines


## The one line naming what a lineage leaves, or empty for none.
static func inherited_line(kind: String, values: Dictionary) -> String:
	match kind:
		RunLineage.HEIRLOOM:
			var rank: int = int(values.get(RunLineage.RANK, Ranks.INVALID))
			var suit: int = int(values.get(RunLineage.SUIT, -1))
			if not Ranks.is_valid(rank) or suit < 0 or suit >= SUIT_KEYS.size():
				return ""
			var card: String = TranslationServer.translate("card.name").format(
				{
					"rank": TranslationServer.translate(Ranks.label_key(rank)),
					"suit": TranslationServer.translate(SUIT_KEYS[suit])
				}
			)
			return TranslationServer.translate("lineage.heirloom").format({"card": card})
		RunLineage.LOYAL:
			return _loyal_line(RunLineage.families(values))
		RunLineage.LABEL:
			return TranslationServer.translate("lineage.label").format(
				{"amount": LINEAGE.label_denunciation}
			)
	return ""


static func _loyal_line(families: Array[String]) -> String:
	var names: Array[String] = []
	for family_id: String in families:
		var family: FamilyDef = RunLoop.DEFAULT_VILLAGE.family(family_id)
		if family != null:
			names.append(TranslationServer.translate(family.name_key))
	if names.is_empty():
		return ""
	if names.size() == 1:
		return TranslationServer.translate("lineage.loyal").format({"name": names[0]})
	var joined: String = TranslationServer.translate("list.pair").format(
		{"a": names[0], "b": names[1]}
	)
	return TranslationServer.translate("lineage.loyal_many").format({"names": joined})


static func _rule(index: int) -> String:
	var stake: StakeDef = RunStakes.STAKES.stakes[index]
	return TranslationServer.translate(stake.text_key).format(stake.text_values())
