class_name RunOpening
extends RefCounted
## What a run starts with beyond its starting coupons (ADR 0025): the household picked at
## run setup and the stake's starting meters, put on the opening state before the first
## checkpoint so a save holds them. Amounts of the same thing from the household, the
## lineage and the stake add up. A starting meter fires no setback: the run has not
## begun, so nothing has risen through mid.

## The stream a household's plot cards are drawn on, seeded from the run alone.
const HOUSEHOLD_STREAM: String = "household"
const DEFAULT_RESENTMENT: ResentmentParams = preload("res://data/run/resentment.tres")
const DEFAULT_METERS: MeterTable = preload("res://data/run/meters.tres")
## The cause a starting Resentment is logged under.
const OPENING: String = "household"


## The household's coupons, plot cards, Cadre, Resentment, Denunciation and Famine.
## cadre is the definition of household.cadre_id, or null for none.
static func household(
	state: RunState, chosen: HouseholdDef, cadre: ModifierDef, run: RunParams
) -> void:
	state.coupons += chosen.coupons
	var stream: RandomStream = RandomStream.new(
		RandomStreams.derive_seed(state.run_seed, HOUSEHOLD_STREAM)
	)
	plot_cards(state, chosen.plot_cards, chosen.plot_low_rank, chosen.plot_high_rank, stream, run)
	if cadre != null and not state.inventory.cadres.has(cadre.id):
		state.inventory.cadres.append(cadre.id)
		RunCadres.bought(state, cadre, Ranks.INVALID)
	resent(state, chosen.resentment)
	raise(state, RunMeters.DENUNCIATION, chosen.denunciation, run)
	raise(state, RunMeters.FAMINE, chosen.famine, run)


## The stake's starting Famine and Denunciation.
static func stake(state: RunState, sum: StakeDef, run: RunParams) -> void:
	raise(state, RunMeters.FAMINE, sum.famine, run)
	raise(state, RunMeters.DENUNCIATION, sum.denunciation, run)


## Puts count plain cards in the plot, each a rank from low to high and a suit drawn
## evenly, none the same as a card the plot already holds, each a new plot card.
static func plot_cards(
	state: RunState, count: int, low: int, high: int, stream: RandomStream, run: RunParams
) -> void:
	var open: Array[Vector2i] = []
	for rank: int in range(low, high + 1):
		for suit: int in Deck.SUITS:
			if not _in_plot(state, rank, suit):
				open.append(Vector2i(rank, suit))
	for _card: int in count:
		if open.is_empty():
			return
		var drawn: Vector2i = open.pop_at(stream.next_int(0, open.size() - 1))
		var card: CardInstance = CardInstance.new(
			state.take_plot_id(), drawn.x, drawn.y, CardInstance.Origin.PLOT
		)
		if not PlotSwap.store(state, card, run):
			return


## Raises a meter at the run's start, kept under its ceiling. A start at or past mid is
## not a rise through it, so the setback waits until the meter has fallen back and risen
## again, as the bands rule.
static func raise(state: RunState, meter: String, amount: int, run: RunParams) -> void:
	if amount == 0:
		return
	var bands: MeterBands = DEFAULT_METERS.bands(meter)
	var after: int = clampi(RunMeters.value(state, meter) + amount, 0, run.meter_max)
	var armed: bool = after < bands.mid
	if meter == RunMeters.FAMINE:
		state.famine = after
		state.famine_armed = armed
	else:
		state.denunciation = after
		state.denunciation_armed = armed


static func resent(state: RunState, amount: int) -> void:
	var unseen: Array[RunEvent] = []
	Resentment.add(state, amount, OPENING, DEFAULT_RESENTMENT, unseen)


static func _in_plot(state: RunState, rank: int, suit: int) -> bool:
	for card: CardInstance in state.inventory.plot:
		if card.base_rank() == rank and card.suit() == suit:
			return true
	return false
