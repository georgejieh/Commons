class_name RunRecord
extends RefCounted
## What a save holds: the RunState where the loop last stood still, at a Set's start or
## end, the player's commands since, and the plays searching villagers made since (ADR
## 0030). The loop is deterministic but for those searches, so replaying the commands on
## that state, with the written plays, rebuilds any moment in between exactly, the Set's
## log too. RunRecordMigrations brings an older save up to the current schema, and
## RunRecordCheck says whether one is whole.

## Each command type and the fields its replay reads.
## Array values, because a constant of PackedStringArray values reads garbage in 4.7.2.
const COMMAND_FIELDS: Dictionary[String, Array] = {
	"bid": ["claim"],
	"swap": ["hand", "plot"],
	"play": ["cards"],
	"need": ["need"],
	"shop": [],
	"buy": ["slot"],
	"reroll": [],
	"market_buy": ["slot"],
	"market_reroll": [],
	"upgrade": ["kind"],
	"plot_card": ["slot"],
	"directive": ["slot"],
	"campaign": ["slot", "cards"],
	"begin": [],
	"campaign_buy": ["slot"],
	"market_campaign": ["slot"],
	"reform": ["slot"],
	"envelope_buy": ["slot"],
	"market_envelope": ["slot"],
	"envelope_pick": ["index"],
	"books": ["figures"],
	"sell_cadre": ["index", "market"],
	"sell_campaign": ["index", "market"],
	"mark_card": ["card", "market"],
	"deck_card": ["slot", "out"],
}
## True in every record written since searching villagers' plays were (ADR 0030).
const WRITTEN_KEY: String = "decisions_written"

## The saved state where the loop last stood still, at a Set's start or end.
var checkpoint: Dictionary = {}
## The player's commands since the checkpoint, in order, each a map of its fields.
var commands: Array[Dictionary] = []
## Every play a searching villager made since the checkpoint, in order.
var decisions: Array[Dictionary] = []


## Returns null when a saved command or a written decision no longer applies, so the
## caller can fall back. The searcher decides searching villagers once the replay is
## over; data without the written marker replays as a record from before it. With
## outside, searches are answered from outside the loop (ADR 0030): a villager the record
## ends before, as in a save written while it was thinking, is not decided here, and the
## loop comes back standing still for it. weights, when given, are what searching villagers
## decide with in place of their own, from the replay on, as the run saved did (ADR 0027).
static func resume(
	data: Dictionary,
	configs: Array[BotConfig],
	sets: SetConfig = SetConfig.new(),
	params: RunParams = RunDefaults.PARAMS,
	pool: Array[ModifierDef] = RunPools.DEBUFFS.debuffs,
	meters: MeterTable = RunDefaults.METERS,
	searcher: Callable = Callable(),
	outside: bool = false,
	weights: BotWeights = null
) -> RunLoop:
	var loop: RunLoop = RunLoop.new(
		RunState.from_dict(data["checkpoint"]), configs, sets, params, pool, meters
	)
	# The resumed loop's own record starts from the same checkpoint, so its next save
	# keeps it even when no new Set starts first, as in the store.
	loop.record.mark(loop.state)
	loop.decisions.searcher = searcher
	loop.decisions.answered_outside = outside
	loop.decisions.weights = weights
	# Before the checkpoint resumes, since villagers can act before the first command.
	var written: Array[Dictionary] = []
	written.assign(data.get("decisions", []))
	var recorded: Array = data["commands"]
	loop.decisions.begin_replay(written, bool(data.get(WRITTEN_KEY, false)), recorded.size())
	loop.resume_at_checkpoint()
	for command: Dictionary in recorded:
		loop.decisions.next_command()
		if loop.decisions.failed() or _replay(loop, command) != RunLoop.Reason.OK:
			return null
	if not loop.decisions.end_replay():
		return null
	return loop


static func _replay(loop: RunLoop, command: Dictionary) -> RunLoop.Reason:
	match str(command["type"]):
		"bid":
			return loop.player_bid(bool(command["claim"]))
		"swap":
			return loop.player_swap(_ids(command["hand"]), _ids(command["plot"]))
		"play":
			# A reading is saved only where the cards read more than one way (ADR 0029).
			var reading: Pattern = ReadingCodec.decode(command.get(ReadingCodec.KEY))
			return loop.player_play(_ids(command["cards"]), reading)
		"need":
			return loop.player_need(int(command["need"]))
		"shop":
			return loop.open_shop()
		"buy":
			return loop.player_buy(int(command["slot"]))
		"reroll":
			return loop.player_reroll()
		"market_buy":
			# A rank arrived with ADR 0021's picker; older records have none.
			var rank: int = int(command.get("rank", Ranks.INVALID))
			return loop.player_market_buy(int(command["slot"]), rank)
		"market_reroll":
			return loop.player_market_reroll()
		"upgrade":
			return loop.player_upgrade(str(command["kind"]))
		"plot_card":
			return loop.player_plot_card(int(command["slot"]))
		"directive":
			return loop.player_directive(int(command["slot"]))
		"campaign":
			return loop.player_campaign(int(command["slot"]), _ids(command["cards"]))
		"begin":
			return loop.player_begin()
		"campaign_buy":
			return loop.player_campaign_buy(int(command["slot"]))
		"market_campaign":
			return loop.player_market_campaign(int(command["slot"]))
		"reform":
			return loop.player_reform(int(command["slot"]))
		"envelope_buy":
			return loop.player_envelope_buy(int(command["slot"]))
		"market_envelope":
			return loop.player_market_envelope(int(command["slot"]))
		"envelope_pick":
			# A deck card kept names the slot it takes out (ADR 0042); no other pick does.
			var out: int = int(command.get("out", Deck.NO_SLOT))
			return loop.player_envelope_pick(int(command["index"]), out)
		"books":
			return loop.player_books(command["figures"])
		"sell_cadre":
			return loop.player_sell_cadre(int(command["index"]), bool(command["market"]))
		"sell_campaign":
			return loop.player_sell_campaign(int(command["index"]), bool(command["market"]))
		"mark_card":
			return loop.player_mark_card(int(command["card"]), bool(command["market"]))
		"deck_card":
			return loop.player_deck_card(int(command["slot"]), int(command["out"]))
	return RunLoop.Reason.ILLEGAL


## JSON reads every number as a float.
static func _ids(values: Array) -> Array[int]:
	var ids: Array[int] = []
	for value: Variant in values:
		ids.append(int(value))
	return ids


## Takes a new checkpoint from state and forgets the commands and plays made before it.
func mark(state: RunState) -> void:
	checkpoint = state.to_dict()
	commands.clear()
	decisions.clear()


## Records one command the player gave since the checkpoint.
func add(command: Dictionary) -> void:
	commands.append(command)


## Writes down a searching villager's play: its seat and card IDs, none for a pass, and
## its reading when the cards read more than one way (ADR 0029).
func decide(seat: int, card_ids: Array[int], reading: Pattern = null) -> void:
	var entry: Dictionary = {"seat": seat, "cards": card_ids.duplicate()}
	if reading != null:
		entry[ReadingCodec.KEY] = ReadingCodec.encode(reading)
	decisions.append(entry)


## The record as a map for the run save, marked as holding written decisions.
func to_dict() -> Dictionary:
	return {
		"checkpoint": checkpoint.duplicate(true),
		"commands": commands.duplicate(true),
		"decisions": decisions.duplicate(true),
		WRITTEN_KEY: true,
	}
