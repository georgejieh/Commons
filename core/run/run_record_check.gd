class_name RunRecordCheck
extends RefCounted
## Whether a run save, migrated to the current schema, has the shape RunRecord.resume()
## needs: a checkpoint with every RunState field of the kind a fresh run holds, and
## commands and written decisions as the record writes them. A save that fails is
## damaged, and the save service falls back to its backup instead of loading it.


## True when data has a checkpoint with every RunState field and well-formed commands,
## so a save that parses but lost its shape falls back to the backup.
static func is_valid(data: Dictionary) -> bool:
	if not data.get("checkpoint") is Dictionary or not data.get("commands") is Array:
		return false
	if not SearchedDecisions.is_valid(data.get("decisions"), data.get(RunRecord.WRITTEN_KEY)):
		return false
	var checkpoint: Dictionary = data["checkpoint"]
	for key: String in RunState.new(0).to_dict():
		if not checkpoint.has(key):
			return false
	if not _observations_valid(checkpoint["observations"]):
		return false
	if not _shapes_valid(checkpoint):
		return false
	var phase: Variant = checkpoint["phase"]
	if not (phase is int or phase is float) or phase < 0 or phase >= RunFlow.State.size():
		return false
	for entry: Variant in data["commands"]:
		if not entry is Dictionary:
			return false
		var command: Dictionary = entry
		var type: String = str(command.get("type"))
		if not RunRecord.COMMAND_FIELDS.has(type):
			return false
		for field: String in RunRecord.COMMAND_FIELDS[type]:
			if not command.has(field):
				return false
		if command.has(ReadingCodec.KEY) and not ReadingCodec.is_valid(command[ReadingCodec.KEY]):
			return false
		if type == "books" and not RunCorrections.is_valid(command["figures"]):
			return false
	return true


## Every saved field holds the kind of value a fresh run's does: a dictionary where one
## belongs, an array where one belongs, a number where one belongs. A save that fails
## here is damaged, and the save service falls back to its backup instead of loading it.
static func _shapes_valid(checkpoint: Dictionary) -> bool:
	var fresh: Dictionary = RunState.new(0).to_dict()
	for key: String in fresh:
		if fresh[key] is Dictionary and not checkpoint[key] is Dictionary:
			return false
		if fresh[key] is Array and not checkpoint[key] is Array:
			return false
		# JSON reads every number as a float.
		var number: bool = checkpoint[key] is int or checkpoint[key] is float
		if fresh[key] is int and not number:
			return false
	if not CardMarks.is_valid(checkpoint["card_marks"]):
		return false
	if not Deck.is_valid(checkpoint["deck"]):
		return false
	if not CadreMemos.is_valid(checkpoint["cadre_memos"]):
		return false
	if not DeckOrder.is_valid(checkpoint["deck_order"]):
		return false
	for reform_id: Variant in checkpoint["reforms"]:
		if not reform_id is String:
			return false
	if not _counters_valid(checkpoint["year_rounds"], checkpoint["year_landlord_rounds"]):
		return false
	if not RunIdentity.is_valid(checkpoint["identity"]):
		return false
	# The file's count is in every identity saved since the books (schema 17).
	var identity: Dictionary = checkpoint["identity"]
	if not RunState.is_count(identity.get("file_entries")):
		return false
	if not RunBooks.is_valid(checkpoint["books"]):
		return false
	if not RunState.is_count(checkpoint["year_starved"]):
		return false
	if not RunState.is_count(checkpoint["famine_market_buys"]):
		return false
	if not RunState.is_count(checkpoint["seatless_sets"]):
		return false
	# False Report's steps are a whole count, none past the norm they raised (ADR 0032).
	if not RunState.is_count(checkpoint["reported_steps"]):
		return false
	if checkpoint["reported_steps"] > checkpoint["norm_steps"]:
		return false
	for event_id: Variant in checkpoint["quota_corruption"]:
		if not event_id is String:
			return false
	if not RunNames.is_valid(checkpoint["names"]) or not VillageDrift.is_valid(checkpoint["drift"]):
		return false
	if not ReadingCodec.wild_ranks_valid(checkpoint["wild_ranks"]):
		return false
	return _levels_valid(checkpoint["hand_levels"])


## The Year's class counters are whole and in order: no fewer than none, and never more
## rounds as landlord than rounds played.
static func _counters_valid(rounds: Variant, landlord: Variant) -> bool:
	for value: Variant in [rounds, landlord]:
		if not RunState.is_count(value):
			return false
	return landlord <= rounds


## Hand levels are one number per hand type.
static func _levels_valid(value: Variant) -> bool:
	if not value is Array:
		return false
	var levels: Array = value
	if levels.size() != Pattern.Type.size():
		return false
	for level: Variant in levels:
		if not (level is int or level is float):
			return false
	return true


## Observations are a dictionary of family IDs to arrays of counts.
static func _observations_valid(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var observations: Dictionary = value
	for family: Variant in observations:
		if not family is String or not observations[family] is Array:
			return false
	return true
