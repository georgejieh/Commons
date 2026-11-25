class_name RunState
extends RefCounted
## Everything a run needs to resume, as one serializable object. Numbers that can pass
## 2^53 are saved as text, because JSON numbers are doubles, and floats as their exact
## bits, because the JSON writer does not round-trip every double.

enum SetType { SMALL, LARGE, BOSS }

const NO_DEBUFF: String = ""
const NO_BOSS: String = ""
const NO_SLOGAN: int = -1
## Family IDs by seat until P4.5 seats the roster.
const DEFAULT_TABLE: Array[String] = ["player", "seat_1", "seat_2"]

var run_seed: int
var phase: RunFlow.State = RunFlow.State.RUN_START
var streams: RandomStreams
## Years count from 1, Sets and rounds from 0.
var year: int = 1
var set_index: int = 0
var set_type: SetType = SetType.SMALL
var round_index: int = 0
## The player's banked score toward the current Set's target.
var set_progress: float = 0.0
## One debuff ID per round of the current Set; round 0 is always NO_DEBUFF.
var debuff_ladder: Array[String] = []
## The hand type Slogan of the Week names, drawn and saved with the ladder, or
## NO_SLOGAN while the ladder has none (ADR 0023).
var slogan_type: int = NO_SLOGAN
var famine: int = 0
var denunciation: int = 0
## Setback state (P4.1). A meter's setback is armed until it fires, and re-arms once the
## meter falls back below its margin.
var famine_armed: bool = true
var denunciation_armed: bool = true
## Rationing holds while true.
var rationed: bool = false
## Reeducation replaces the next shop visit while true.
var reeducation_due: bool = false
## The village's Resentment of the player (P4.2).
var resentment: int = 0
## Sets in a row the player has ended without holding the landlord's seat (ADR 0031).
var seatless_sets: int = 0
## The ranks wild in the round in play (ADR 0029), at most two, drawn by the items that
## make them, for the player's seat alone (ADR 0039). Empty between rounds and while no
## rank is wild.
var wild_ranks: Array[int] = []
## Each villager family's own Denunciation, from lies caught at audit (P4.3).
var villager_denunciation: Dictionary[String, int] = {}
## Commons shares paid to the player, and to every peasant, this run (P4.4).
var commons_received: int = 0
var commons_paid: int = 0
## What each family remembers of the player, carried in from the profile (P4.6).
var memory: VillageMemory = VillageMemory.new()
## Families that held the landlord seat for a whole Set this run, and those that have
## already run a boss Set (P4.7).
var risen: Array[String] = []
var risen_used: Array[String] = []
## Officials that have run a boss Set since the pool last cycled.
var officials_used: Array[String] = []
## The current Set's boss, or NO_BOSS, and the risen family seated as it.
var boss_id: String = NO_BOSS
var boss_family: String = ""
## How the player played their most recent Sets, oldest first.
var styles: Array[PlayerStyle] = []
## The next ID for a card entering the plot, and the plot upgrades bought (P4.8).
var next_plot_id: int = CardInstance.FIRST_PLOT_ID
var plot_capacity_bonus: int = 0
var swap_bonus: int = 0
## How many of each item the state store has sold this run, against its limited stock
## (P4.10).
var store_sold: Dictionary[String, int] = {}
## Overfulfilment steps earned this run, which raise every later target, and the steps
## the Set just finished earned, 0 again once the next Set starts. The target in force
## for a Set counts norm_steps less over_steps.
var norm_steps: int = 0
var over_steps: int = 0
## The steps False Report raised the norm by in the Set in play (ADR 0032), held like
## over_steps, so the target in force for that Set leaves them out too; 0 again once the
## next Set starts.
var reported_steps: int = 0
## Each hand type's level, which Directives raise, and the marks saved on deck cards
## (P4.11).
var hand_levels: HandLevels = HandLevels.new(Scorer.DEFAULT_PARAMS.max_level)
var card_marks: CardMarks = CardMarks.new()
## The communal deck, slot by slot, as the state store's exchanges left it (ADR 0042).
var deck: Deck = Deck.new()
## Each held Cadre's own run state, such as a picked rank or a count it keeps (ADR 0021).
var cadre_memos: CadreMemos = CadreMemos.new()
## The Reforms enacted this run, in the order they were bought, and the deck as Unplanned
## Economy gathered it from the last round: empty at a Quota's start and without it.
var reforms: Array[String] = []
var deck_order: Array[int] = []
var roster: Array[RosterEntry] = []
## The family in each seat this Set.
var table: Array[String] = DEFAULT_TABLE.duplicate()
var inventory: RunInventory = RunInventory.new()
var coupons: int = 0
var commons_pool: int = 0
var landlord_seat: int = Seats.NONE
var summaries: Array[SetSummary] = []
## What the player has seen each villager do this run, for the dossier.
var observations: Observations = Observations.new()
## The rounds played in the current Year, and those the player held the landlord seat in,
## which give the run's final class (ADR 0024). Both start again with each Year.
var year_rounds: int = 0
var year_landlord_rounds: int = 0
## Families that have starved this Year, against the village's limit (ADR 0025). It
## starts again with each Year.
var year_starved: int = 0
## Which run this is, of which kind, and what it began with (ADR 0025).
var identity: RunIdentity = RunIdentity.new()
## The last Quota's corruption events, in order (CorruptionEvents), kept until the next
## Quota starts so the profile can take them from a save at the Quota's end; and the
## black-market purchases made in high Famine since the last Quota ended (ADR 0025).
var quota_corruption: Array[String] = []
var famine_market_buys: int = 0
## Who is who: the player's and every family's given name (ADR 0028).
var names: RunNames = RunNames.new()
## How far the village has drifted by this generation, from the profile (ADR 0028).
var drift: VillageDrift = VillageDrift.new()
## What figures reported from outside the game left in the books (ADR 0022).
var books: RunBooks = RunBooks.new()


func _init(seed_value: int) -> void:
	run_seed = seed_value
	streams = RandomStreams.new(seed_value)


static func from_dict(data: Dictionary) -> RunState:
	var state: RunState = RunState.new(str(data["seed"]).to_int())
	state.streams = RandomStreams.from_dict(data["streams"])
	state.phase = int(data["phase"]) as RunFlow.State
	state.year = int(data["year"])
	state.set_index = int(data["set_index"])
	state.set_type = int(data["set_type"]) as SetType
	state.round_index = int(data["round_index"])
	state.set_progress = float_from_text(str(data["set_progress"]))
	state.debuff_ladder.assign(data["debuff_ladder"])
	state.slogan_type = int(data["slogan_type"])
	state.famine = int(data["famine"])
	state.denunciation = int(data["denunciation"])
	state.famine_armed = bool(data["famine_armed"])
	state.denunciation_armed = bool(data["denunciation_armed"])
	state.rationed = bool(data["rationed"])
	state.reeducation_due = bool(data["reeducation_due"])
	state.resentment = int(data["resentment"])
	state.seatless_sets = int(data["seatless_sets"])
	for rank: Variant in data["wild_ranks"]:
		state.wild_ranks.append(int(rank))
	state.commons_received = str(data["commons_received"]).to_int()
	state.commons_paid = str(data["commons_paid"]).to_int()
	state.memory = VillageMemory.from_dict(data["memory"])
	state.risen.assign(data["risen"])
	state.risen_used.assign(data["risen_used"])
	state.officials_used.assign(data["officials_used"])
	state.boss_id = str(data["boss_id"])
	state.boss_family = str(data["boss_family"])
	state.next_plot_id = int(data["next_plot_id"])
	state.plot_capacity_bonus = int(data["plot_capacity_bonus"])
	state.swap_bonus = int(data["swap_bonus"])
	for item_id: String in data["store_sold"]:
		state.store_sold[item_id] = int(data["store_sold"][item_id])
	state.norm_steps = int(data["norm_steps"])
	state.over_steps = int(data["over_steps"])
	state.reported_steps = int(data["reported_steps"])
	var max_level: int = Scorer.DEFAULT_PARAMS.max_level
	state.hand_levels = HandLevels.from_array(data["hand_levels"], max_level)
	state.card_marks = CardMarks.from_dict(data["card_marks"])
	state.deck = Deck.from_dict(data["deck"])
	state.cadre_memos = CadreMemos.from_dict(data["cadre_memos"])
	state.reforms.assign(data["reforms"])
	for deck_id: Variant in data["deck_order"]:
		state.deck_order.append(int(deck_id))
	for style_data: Dictionary in data["styles"]:
		state.styles.append(PlayerStyle.from_dict(style_data))
	for family_id: String in data["villager_denunciation"]:
		state.villager_denunciation[family_id] = int(data["villager_denunciation"][family_id])
	state.table.assign(data["table"])
	for entry_data: Dictionary in data["roster"]:
		state.roster.append(RosterEntry.from_dict(entry_data))
	state.inventory = RunInventory.from_dict(data["inventory"])
	state.coupons = int(data["coupons"])
	state.commons_pool = str(data["commons_pool"]).to_int()
	state.landlord_seat = int(data["landlord_seat"])
	for summary_data: Dictionary in data["summaries"]:
		state.summaries.append(SetSummary.from_dict(summary_data))
	state.observations = Observations.from_dict(data["observations"])
	state.year_rounds = int(data["year_rounds"])
	state.year_landlord_rounds = int(data["year_landlord_rounds"])
	state.year_starved = int(data["year_starved"])
	state.identity = RunIdentity.from_dict(data["identity"])
	state.quota_corruption.assign(data["quota_corruption"])
	state.famine_market_buys = int(data["famine_market_buys"])
	state.names = RunNames.from_dict(data["names"])
	state.drift = VillageDrift.from_dict(data["drift"])
	state.books = RunBooks.from_dict(data["books"])
	return state


func to_dict() -> Dictionary:
	var roster_data: Array[Dictionary] = []
	for entry: RosterEntry in roster:
		roster_data.append(entry.to_dict())
	var summary_data: Array[Dictionary] = []
	for summary: SetSummary in summaries:
		summary_data.append(summary.to_dict())
	return {
		"seed": str(run_seed),
		"streams": streams.to_dict(),
		"phase": phase,
		"year": year,
		"set_index": set_index,
		"set_type": set_type,
		"round_index": round_index,
		"set_progress": float_text(set_progress),
		"debuff_ladder": debuff_ladder.duplicate(),
		"slogan_type": slogan_type,
		"famine": famine,
		"denunciation": denunciation,
		"famine_armed": famine_armed,
		"denunciation_armed": denunciation_armed,
		"rationed": rationed,
		"reeducation_due": reeducation_due,
		"resentment": resentment,
		"seatless_sets": seatless_sets,
		"wild_ranks": wild_ranks.duplicate(),
		"commons_received": str(commons_received),
		"commons_paid": str(commons_paid),
		"memory": memory.to_dict(),
		"risen": risen.duplicate(),
		"risen_used": risen_used.duplicate(),
		"officials_used": officials_used.duplicate(),
		"boss_id": boss_id,
		"next_plot_id": next_plot_id,
		"plot_capacity_bonus": plot_capacity_bonus,
		"swap_bonus": swap_bonus,
		"store_sold": store_sold.duplicate(),
		"norm_steps": norm_steps,
		"over_steps": over_steps,
		"reported_steps": reported_steps,
		"hand_levels": hand_levels.to_array(),
		"card_marks": card_marks.to_dict(),
		"deck": deck.to_dict(),
		"cadre_memos": cadre_memos.to_dict(),
		"reforms": reforms.duplicate(),
		"deck_order": deck_order.duplicate(),
		"boss_family": boss_family,
		"styles": styles.map(func(style: PlayerStyle) -> Dictionary: return style.to_dict()),
		"villager_denunciation": villager_denunciation.duplicate(),
		"roster": roster_data,
		"table": table.duplicate(),
		"inventory": inventory.to_dict(),
		"coupons": coupons,
		"commons_pool": str(commons_pool),
		"landlord_seat": landlord_seat,
		"summaries": summary_data,
		"observations": observations.to_dict(),
		"year_rounds": year_rounds,
		"year_landlord_rounds": year_landlord_rounds,
		"year_starved": year_starved,
		"identity": identity.to_dict(),
		"quota_corruption": quota_corruption.duplicate(),
		"famine_market_buys": famine_market_buys,
		"names": names.to_dict(),
		"drift": drift.to_dict(),
		"books": books.to_dict(),
	}


## A plot ID no card in the run has held. Past every ID in the plot, so plot cards
## made before the counter existed are never repeated.
func take_plot_id() -> int:
	var next: int = next_plot_id
	for card: CardInstance in inventory.plot:
		next = maxi(next, card.id() + 1)
	next_plot_id = next + 1
	return next


## Halves keep the text unsigned, as RandomStream does.
static func float_text(value: float) -> String:
	var bits: int = PackedFloat64Array([value]).to_byte_array().decode_s64(0)
	return "%08x%08x" % [(bits >> 32) & 0xFFFFFFFF, bits & 0xFFFFFFFF]


static func float_from_text(text: String) -> float:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(8)
	bytes.encode_s64(0, (text.substr(0, 8).hex_to_int() << 32) | text.substr(8).hex_to_int())
	return bytes.decode_double(0)
