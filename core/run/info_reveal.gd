class_name InfoReveal
extends RefCounted
## Fills the player's InfoView from the information flags their modifiers turn on (P4.9).
## Bots never get one, so with no flags the player sees exactly the public view.

const INFO: String = "info"


## The flags turned on by the given definitions' info parameters.
static func flags(definitions: Array[ModifierDef]) -> int:
	var found: int = 0
	for definition: ModifierDef in definitions:
		found |= definition.parameters.get(INFO, 0)
	return found


static func build(round_state: RoundState, seat: int, info_flags: int, table: BotTable) -> InfoView:
	var info: InfoView = InfoView.new()
	info.flags = info_flags
	var landlord: int = round_state.public_view().landlord
	if info_flags & InfoView.OPPONENT_TYPES:
		for other: int in Seats.COUNT:
			var opponent: bool = other != seat and (other == landlord or seat == landlord)
			if opponent:
				info.opponent_types[other] = _types(round_state.view_for(other).own_counts, table)
	if info_flags & InfoView.CLOSEST_HAND:
		var fewest: int = 99
		for other: int in Seats.COUNT:
			var size: int = round_state.remaining()[other]
			if other != seat and size < fewest:
				fewest = size
				info.closest_seat = other
		info.closest_counts = round_state.view_for(info.closest_seat).own_counts
	return info


static func _types(counts: PackedByteArray, table: BotTable) -> PackedInt32Array:
	var types: PackedInt32Array = PackedInt32Array()
	types.resize(Pattern.Type.size())
	for group: Pattern in Bot.suggest_groups(counts, table, BotConfig.new()):
		types[group.type] += 1
	return types
