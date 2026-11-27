class_name RunLineage
extends RefCounted
## What a finished run leaves the next generation, by the class it ended in, and how the
## next run takes it (ADR 0025, "Lineage"). A landlord ending leaves an heirloom: one
## Model plot card, its rank and suit drawn when the run ends, so run setup can name it.
## A peasant ending but Labeled leaves one loyal family, The Commons two, Labeled leaves
## the label, and a death nothing. A loyal family is, among the families still active at
## the end, the one with the lowest grudge, the earlier in roster order on a tie, and only
## when its grudge is below zero. Sent-down youth are never chosen: their place in the
## village lasts one run.

## The lineage kind of a run that leaves nothing.
const NONE: String = ""
## The lineage kind that leaves one Model plot card.
const HEIRLOOM: String = "heirloom"
## The lineage kind that leaves loyal families.
const LOYAL: String = "loyal"
## The lineage kind that leaves the label, which raises Denunciation.
const LABEL: String = "label"
## The key of the heirloom's rank in a lineage's values.
const RANK: String = "rank"
## The key of the heirloom's suit in a lineage's values.
const SUIT: String = "suit"
## The key of the loyal families' IDs in a lineage's values.
const FAMILIES: String = "families"
## The stream the heirloom is drawn on, seeded from the finished run alone.
const HEIRLOOM_STREAM: String = "heirloom"
## The heirloom's ranks and the counts and amounts a lineage uses, when a caller gives none.
const DEFAULT_PARAMS: LineageParams = preload("res://data/run/lineage.tres")


## The lineage a run that ended in this state leaves.
static func left_by(
	state: RunState,
	meters: MeterTable,
	memory: MemoryParams,
	params: LineageParams = DEFAULT_PARAMS
) -> Lineage:
	var outcome: String = Endings.outcome(state, meters)
	if Endings.is_death(outcome):
		return Lineage.new()
	if YearClass.is_landlord(state):
		var stream: RandomStream = RandomStream.new(
			RandomStreams.derive_seed(state.run_seed, HEIRLOOM_STREAM)
		)
		var rank: int = stream.next_int(params.heirloom_low_rank, params.heirloom_high_rank)
		var suit: int = stream.next_int(0, Deck.SUITS - 1)
		return Lineage.new(HEIRLOOM, {RANK: rank, SUIT: suit})
	if outcome == Endings.LABELED:
		return Lineage.new(LABEL)
	var count: int = params.social_families
	if outcome == Endings.THE_COMMONS:
		count = params.commons_families
	var loyal: Array[String] = loyal_families(state, memory, count)
	if loyal.is_empty():
		return Lineage.new()
	return Lineage.new(LOYAL, {FAMILIES: loyal})


## Up to count active families whose grudge is below zero, lowest first, the earlier in
## roster order on a tie.
static func loyal_families(state: RunState, memory: MemoryParams, count: int) -> Array[String]:
	var candidates: Array[RosterEntry] = []
	for entry: RosterEntry in state.roster:
		var active: bool = entry.status == RosterEntry.Status.ACTIVE
		if active and entry.template_id.is_empty():
			if state.memory.grudge(entry.family_id, memory) < 0.0:
				candidates.append(entry)
	# A stable order: lowest grudge first, then roster order.
	var order: Array[int] = []
	for index: int in candidates.size():
		order.append(index)
	order.sort_custom(
		func(a: int, b: int) -> bool:
			var left: float = state.memory.grudge(candidates[a].family_id, memory)
			var right: float = state.memory.grudge(candidates[b].family_id, memory)
			return left < right or (left == right and a < b)
	)
	var chosen: Array[String] = []
	for index: int in order.slice(0, count):
		chosen.append(candidates[index].family_id)
	return chosen


## Puts the inherited lineage on the opening state: the heirloom into the plot, each loyal
## family's memory set to the feedings alone (after the usual carry-over, for families in
## this run's roster only), or the label's Denunciation. Values that do not read are
## skipped.
static func apply(
	state: RunState,
	kind: String,
	values: Dictionary,
	run: RunParams,
	params: LineageParams = DEFAULT_PARAMS
) -> void:
	match kind:
		HEIRLOOM:
			var rank: int = int(values.get(RANK, Ranks.INVALID))
			var suit: int = int(values.get(SUIT, Deck.NO_SUIT))
			if not Ranks.is_valid(rank) or suit < 0 or suit >= Deck.SUITS:
				return
			var card: CardInstance = CardInstance.new(
				state.take_plot_id(), rank, suit, CardInstance.Origin.PLOT
			)
			CardMarks.enhance(state, card, CardInstance.MODEL)
			PlotSwap.store(state, card, run)
		LOYAL:
			for family_id: String in families(values):
				_make_loyal(state, family_id, params)
		LABEL:
			RunOpening.raise(state, RunMeters.DENUNCIATION, params.label_denunciation, run)


## The inherited families in a lineage's values, as IDs.
static func families(values: Dictionary) -> Array[String]:
	var found: Array[String] = []
	var listed: Variant = values.get(FAMILIES, [])
	if listed is Array:
		for family_id: Variant in listed:
			found.append(str(family_id))
	return found


static func _make_loyal(state: RunState, family_id: String, params: LineageParams) -> void:
	if Roster.entry(state, family_id) == null:
		return
	var row: PackedFloat64Array = []
	row.resize(SetSummary.Kind.size())
	row[SetSummary.Kind.FED] = params.loyal_feedings
	state.memory.counts[family_id] = row
