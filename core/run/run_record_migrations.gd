class_name RunRecordMigrations
extends RefCounted
## Brings an older run save up to the current schema, one step a version: each migration
## fills in what the schema it names lacks, with the value a run of that time held, and
## leaves the rest as it was. SaveService runs them in order before RunRecordCheck reads
## the save.


## Schema 1 to 2: runs saved before the dossier start with nothing observed.
static func migrate_from_1(data: Dictionary) -> Dictionary:
	if data.get("checkpoint") is Dictionary:
		var checkpoint: Dictionary = data["checkpoint"]
		if not checkpoint.has("observations"):
			checkpoint["observations"] = {}
	return data


## Version 2 saves lack every field the meters, the village and the shops added before
## schema 4; migrate_from_3, which always runs next, fills them in.
static func migrate_from_2(data: Dictionary) -> Dictionary:
	return data


## Version 3 saves predate the state store's limited stock: nothing sold yet.
## Schema 3 was written for a long while as its fields were still being added, so a
## save from the middle of it may lack some: every such field missing gets the value a
## run starts with.
static func migrate_from_3(data: Dictionary) -> Dictionary:
	if data.get("checkpoint") is Dictionary:
		var checkpoint: Dictionary = data["checkpoint"]
		checkpoint.merge(_schema_3_defaults())
	return data


## Version 4 saves predate overfulfilment: no norm raised yet, and none earned by the
## Set they stand at. A schema 4 save from inside a Set replays its commands under the
## dice audit and may audit differently from the run it was saved from; as with the
## scoring change in ADR 0020, no attempt is made to keep the old rule. A saved command
## the loop no longer waits for makes resume() return null, so that save is not resumed.
static func migrate_from_4(data: Dictionary) -> Dictionary:
	if data.get("checkpoint") is Dictionary:
		var checkpoint: Dictionary = data["checkpoint"]
		checkpoint.merge({"norm_steps": 0, "over_steps": 0})
	return data


## Version 5 saves predate saved marks and hand levels: no card marked, and
## every hand type at its first level.
static func migrate_from_5(data: Dictionary) -> Dictionary:
	if data.get("checkpoint") is Dictionary:
		var checkpoint: Dictionary = data["checkpoint"]
		var fresh: RunState = RunState.new(0)
		checkpoint.merge(
			{"hand_levels": fresh.hand_levels.to_array(), "card_marks": fresh.card_marks.to_dict()}
		)
	return data


## Version 6 saves predate each Cadre's own run state (ADR 0021): no Cadre has any, so a
## Rehabilitation or Planned Allocation held then uses its data's rank, and every growth
## and count starts at nothing.
static func migrate_from_6(data: Dictionary) -> Dictionary:
	if data.get("checkpoint") is Dictionary:
		var checkpoint: Dictionary = data["checkpoint"]
		checkpoint.merge({"cadre_memos": {}})
	return data


## Version 7 saves predate Reforms (ADR 0021): none enacted, so no gathered deck either.
static func migrate_from_7(data: Dictionary) -> Dictionary:
	if data.get("checkpoint") is Dictionary:
		var checkpoint: Dictionary = data["checkpoint"]
		checkpoint.merge({"reforms": [], "deck_order": []})
	return data


## Version 8 saves predate Slogan of the Week (ADR 0023): no ladder named a hand type.
static func migrate_from_8(data: Dictionary) -> Dictionary:
	if data.get("checkpoint") is Dictionary:
		var checkpoint: Dictionary = data["checkpoint"]
		checkpoint.merge({"slogan_type": RunState.NO_SLOGAN})
	return data


## Version 9 saves predate the Year's class counters (ADR 0024): no round counted yet, so
## a run picked up mid-Year counts from there, and a Year with no rounds is a peasant's.
static func migrate_from_9(data: Dictionary) -> Dictionary:
	if data.get("checkpoint") is Dictionary:
		var checkpoint: Dictionary = data["checkpoint"]
		checkpoint.merge({"year_rounds": 0, "year_landlord_rounds": 0})
	return data


## Version 10 saves predate run identity (ADR 0025): every run then was the demo, so a
## migrated save is a demo run, with an ID made from its seed alone, and no family has
## starved in its Year.
static func migrate_from_10(data: Dictionary) -> Dictionary:
	if data.get("checkpoint") is Dictionary:
		var checkpoint: Dictionary = data["checkpoint"]
		var identity: RunIdentity = RunIdentity.new()
		identity.id = RunIdentity.make_id(str(checkpoint.get("seed", "0")).to_int(), 0)
		checkpoint.merge({"identity": identity.to_dict(), "year_starved": 0})
	return data


## Version 11 saves predate corruption (ADR 0025): no Quota's events kept, and no
## purchase in a famine counted yet.
static func migrate_from_11(data: Dictionary) -> Dictionary:
	if data.get("checkpoint") is Dictionary:
		var checkpoint: Dictionary = data["checkpoint"]
		checkpoint.merge({"quota_corruption": [], "famine_market_buys": 0})
	return data


## Version 12 saves predate written decisions (ADR 0030): marked as holding none, so
## they replay with the unlimited search, as they were made.
static func migrate_from_12(data: Dictionary) -> Dictionary:
	data["decisions"] = []
	data[RunRecord.WRITTEN_KEY] = false
	return data


## Version 13 saves predate the unheld seat (ADR 0031): no Quota counted yet without the
## landlord's seat, so a run picked up then counts from there.
static func migrate_from_13(data: Dictionary) -> Dictionary:
	if data.get("checkpoint") is Dictionary:
		var checkpoint: Dictionary = data["checkpoint"]
		checkpoint.merge({"seatless_sets": 0})
	return data


## Version 14 saves predate names and drift (ADR 0028): a full run is named from its seed
## and generation as it would have been at its start (RunNames.name_saved), the same
## way every time, and no village drifted. texts gives each surname key's text; the
## run save's service passes the string table's.
static func migrate_from_14(data: Dictionary, texts: Dictionary[String, String] = {}) -> Dictionary:
	if data.get("checkpoint") is Dictionary:
		var checkpoint: Dictionary = data["checkpoint"]
		RunNames.name_saved(checkpoint, RunDefaults.VILLAGE, texts)
		checkpoint["drift"] = {}
	return data


## Version 15 saves predate wild ranks (ADR 0029): no rank was wild in the round in play.
## Their plays name no reading, and with no rank wild their cards read only one way.
static func migrate_from_15(data: Dictionary) -> Dictionary:
	if data.get("checkpoint") is Dictionary:
		var checkpoint: Dictionary = data["checkpoint"]
		checkpoint.merge({"wild_ranks": []})
	return data


## Version 16 saves predate the books (ADR 0022): no figure corrected, none dark, and a
## run begun with no entry in the family's file.
static func migrate_from_16(data: Dictionary) -> Dictionary:
	if data.get("checkpoint") is Dictionary:
		var checkpoint: Dictionary = data["checkpoint"]
		checkpoint.merge({"books": RunBooks.new().to_dict()})
		if checkpoint.get("identity") is Dictionary:
			var identity: Dictionary = checkpoint["identity"]
			identity.merge({"file_entries": 0})
	return data


## Version 17 saves predate False Report (ADR 0032): no Set in play raised the norm by a
## report.
static func migrate_from_17(data: Dictionary) -> Dictionary:
	if data.get("checkpoint") is Dictionary:
		var checkpoint: Dictionary = data["checkpoint"]
		checkpoint.merge({"reported_steps": 0})
	return data


## Version 18 saves predate the deck exchange (ADR 0042): every slot of the communal deck
## holds its plain card.
static func migrate_from_18(data: Dictionary) -> Dictionary:
	if data.get("checkpoint") is Dictionary:
		var checkpoint: Dictionary = data["checkpoint"]
		checkpoint.merge({"deck": {}})
	return data


## Version 19 saves predate the count of claims a trait shift made larger (ADR 0043): no
## family was seen making one.
static func migrate_from_19(data: Dictionary) -> Dictionary:
	if data.get("checkpoint") is Dictionary:
		var checkpoint: Dictionary = data["checkpoint"]
		var observations: Variant = checkpoint.get("observations")
		if observations is Dictionary:
			var rows: Dictionary = observations
			for family: Variant in rows:
				if rows[family] is Array:
					var row: Array = rows[family]
					while row.size() < Observations.Kind.size():
						row.append(0)
	return data


## Every field schema 3 gained while it was written, at the value a run starts with.
static func _schema_3_defaults() -> Dictionary:
	return {
		"famine_armed": true,
		"denunciation_armed": true,
		"rationed": false,
		"reeducation_due": false,
		"resentment": 0,
		"villager_denunciation": {},
		"commons_received": "0",
		"commons_paid": "0",
		"memory": {},
		"risen": [],
		"risen_used": [],
		"officials_used": [],
		"boss_id": "",
		"next_plot_id": CardInstance.FIRST_PLOT_ID,
		"plot_capacity_bonus": 0,
		"swap_bonus": 0,
		"boss_family": "",
		"styles": [],
		"store_sold": {},
	}
