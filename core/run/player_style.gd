class_name PlayerStyle
extends RefCounted
## How the player played one Set (P4.7): how often they played each hand type and how
## often they called the landlord seat. The New Landlord and mirroring families copy it.

var type_counts: PackedInt64Array = PackedInt64Array()
var calls: int = 0
var bid_turns: int = 0


func _init() -> void:
	type_counts.resize(Pattern.Type.size())


## Reads one Set's log for the player's plays and bids.
static func from_events(events: Array[RunEvent], player: int) -> PlayerStyle:
	var style: PlayerStyle = PlayerStyle.new()
	for event: RunEvent in events:
		if event.type == RunEvent.Type.BID and event.seat == player:
			style.bid_turns += 1
			style.calls += event.value
		elif event.round_event != null and event.round_event.seat == player:
			if event.round_event.type == RoundEvent.Type.PLAYED:
				style.type_counts[event.round_event.pattern.type] += 1
	return style


static func from_dict(data: Dictionary) -> PlayerStyle:
	var style: PlayerStyle = PlayerStyle.new()
	var counts: Array = data["type_counts"]
	for index: int in mini(counts.size(), style.type_counts.size()):
		style.type_counts[index] = int(counts[index])
	style.calls = int(data["calls"])
	style.bid_turns = int(data["bid_turns"])
	return style


func to_dict() -> Dictionary:
	return {"type_counts": Array(type_counts), "calls": calls, "bid_turns": bid_turns}


## Each hand type's share of all the plays in styles, from 0 to 1.
static func type_shares(styles: Array[PlayerStyle]) -> PackedFloat32Array:
	var shares: PackedFloat32Array = PackedFloat32Array()
	shares.resize(Pattern.Type.size())
	var total: int = 0
	for style: PlayerStyle in styles:
		for type: int in style.type_counts.size():
			shares[type] += style.type_counts[type]
			total += style.type_counts[type]
	if total > 0:
		for type: int in shares.size():
			shares[type] /= total
	return shares


## How often the player called across styles, or one half with no bids to go on.
static func bid_rate(styles: Array[PlayerStyle]) -> float:
	var calls: int = 0
	var turns: int = 0
	for style: PlayerStyle in styles:
		calls += style.calls
		turns += style.bid_turns
	return 0.5 if turns == 0 else float(calls) / turns


## Makes config play like the player in styles: a bonus toward each hand type by its
## share, and ambition that matches the bid rate.
static func mirror(config: BotConfig, styles: Array[PlayerStyle], pool: BossPool) -> void:
	var shares: PackedFloat32Array = type_shares(styles)
	var bias: PackedFloat32Array = PackedFloat32Array()
	bias.resize(shares.size())
	for type: int in shares.size():
		bias[type] = shares[type] * pool.style_bias
	config.type_bias = bias
	config.ambition = (bid_rate(styles) - 0.5) * pool.ambition_span
	# An Easy bot plays greedily and never reads a type bias, so the mirror plays at
	# Medium or above.
	if config.tier < BotConfig.Tier.MEDIUM:
		config.tier = BotConfig.Tier.MEDIUM
