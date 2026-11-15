class_name CollectionView
extends RefCounted
## What the collection page shows (ADR 0025): every Cadre, Campaign, Directive, Reform and
## envelope either shop can sell, under one heading per kind, each open or locked by the
## profile's finished runs. A locked item's sheet says only when it opens.

const SECTION_KEYS: Array[String] = [
	"coll.collective",
	"coll.private",
	"coll.campaigns",
	"coll.directives",
	"coll.reforms",
	"coll.envelopes",
]
const COLLECTIVE: int = 0
const PRIVATE: int = 1
const CAMPAIGNS: int = 2
const DIRECTIVES: int = 3
const REFORMS: int = 4
const ENVELOPES: int = 5

## The finished runs the page opens items by.
var finished_runs: int = 0
var _sections: Array[Array] = []


## The collection as the profile has opened it.
static func of(profile: SaveService) -> CollectionView:
	return for_runs(Profile.read(profile).finished_runs)


static func for_runs(runs: int) -> CollectionView:
	var view: CollectionView = CollectionView.new()
	view.finished_runs = runs
	for _key: String in SECTION_KEYS:
		view._sections.append([])
	for definition: ModifierDef in RunPools.STORE_CADRES.cadres:
		view._add(COLLECTIVE, definition, ItemText.cadre(definition))
	for definition: ModifierDef in RunPools.MARKET_CADRES.cadres:
		view._add(PRIVATE, definition, ItemText.cadre(definition))
	for definition: CampaignDef in RunCampaigns.all():
		view._add(CAMPAIGNS, definition, ItemText.campaign(definition))
	for definition: DirectiveDef in RunPools.DIRECTIVES.directives:
		view._add(DIRECTIVES, definition, ItemText.directive(definition))
	for definition: ReformDef in RunReforms.all():
		view._add(REFORMS, definition, ItemText.reform(definition))
	for definition: EnvelopeDef in RunPools.STORE.envelopes + RunPools.MARKET.envelopes:
		var rules: String = ItemText.envelope(definition, definition.choices)
		view._add(ENVELOPES, definition, rules)
	return view


## The headings in order, as string keys.
func section_keys() -> Array[String]:
	return SECTION_KEYS.duplicate()


## One section's sheets, in shop order.
func sheets(section: int) -> Array[UnlockSheet]:
	var found: Array[UnlockSheet] = []
	found.assign(_sections[section])
	return found


func total() -> int:
	var count: int = 0
	for section: Array in _sections:
		count += section.size()
	return count


func open_count() -> int:
	var count: int = 0
	for section: Array in _sections:
		for sheet: UnlockSheet in section:
			if sheet.open:
				count += 1
	return count


## The line at the top: how many are open.
func open_line() -> String:
	var values: Dictionary = {"open": open_count(), "total": total()}
	return TranslationServer.translate("coll.open").format(values)


## Adds an item's sheet. Every kind of item carries an ID, a name key and a tier.
func _add(section: int, item: Resource, rules: String) -> void:
	var left: int = RunUnlocks.runs_left(int(item.get("unlock_tier")), finished_runs)
	var sheet: UnlockSheet = UnlockSheet.locked(UnlockSheet.runs_line(left))
	var item_id: String = str(item.get("id"))
	if left == 0:
		var name: String = TranslationServer.translate(str(item.get("name_key")))
		sheet = UnlockSheet.opened(item_id, name, rules)
		if section == COLLECTIVE or section == PRIVATE:
			sheet.art_id = item_id
	sheet.index = _sections[section].size()
	_sections[section].append(sheet)
