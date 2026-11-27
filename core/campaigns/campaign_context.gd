class_name CampaignContext
extends RefCounted
## What one use of a Campaign reads and changes: the run, the round when there is one,
## the round's Campaign flags, the cards chosen and where events go.

## Where the run stands when a Campaign is checked.
enum Moment { ELSEWHERE, OPENING, TURN, SHOP }

## The meter row a Campaign's Famine moves through; its amount is the Campaign's.
const FAMINE_SOURCE: String = "campaign_famine"
## The meter row a Campaign's Denunciation moves through; its amount is the Campaign's.
const DENUNCIATION_SOURCE: String = "campaign_denunciation"

## The Campaign being used; its parameters and timing are read from it.
var definition: CampaignDef
## The run's state, which a Campaign changes when it applies.
var state: RunState
## Null in a shop.
var round_state: RoundState = null
## The round's seat rules, for a Campaign that changes what is wild or reads a rank order.
var table: SeatRules
## The modifier stack of the Set; a Campaign may switch an entry off in it.
var stack: ModifierStack
## The meter table a Campaign's Famine or Denunciation moves through.
var meters: MeterTable
## The run's parameters, read when a meter moves.
var params: RunParams
## What Campaigns hold in force this round; effects set and read it.
var flags: CampaignRound
## The Set's event log, where every event a Campaign makes goes.
var set_log: SetLog
## Where the run stands: between rounds, at the opening, on a turn or in a shop.
var moment: Moment = Moment.ELSEWHERE
## True before the round's first play.
var opening: bool = false
## The IDs of the cards the player chose for this use; empty for a Campaign that takes none.
var card_ids: Array[int] = []
## The player's seat.
var player: int = 0
## The Quota's target in force now, 0 when the loop gave none (ADR 0032).
var target: float = 0.0


## The player's cards now, as copies, or none outside a round.
func hand() -> Array[CardInstance]:
	if round_state == null:
		return []
	return round_state.view_for(player).own_cards


## The rules and rank order a seat plays under, for a bot's choice.
func seat_table(seat: int) -> BotTable:
	table.refresh()
	return BotTable.of_seat(table, seat)


## Logs an event in the Set's log.
func add_event(event: RunEvent) -> void:
	set_log.add(event)


## Raises Resentment by amount for a Campaign; 0 does nothing.
func resent(amount: int) -> void:
	if amount != 0:
		Resentment.add(state, amount, Resentment.CAMPAIGN, RunDefaults.RESENTMENT, set_log.events())


## Lowers Resentment through its one path down (ADR 0032).
func relent(amount: int) -> void:
	if amount != 0:
		Resentment.lower(
			state, amount, Resentment.CAMPAIGN, RunDefaults.RESENTMENT, set_log.events()
		)


## Moves a meter through the Campaign's row: a rise for a positive amount, a fall through
## the meters' one path down for a negative one.
func move_meter(source_id: String, amount: int) -> void:
	var logged: Array[RunEvent] = set_log.events()
	if amount < 0:
		RunMeters.lower(state, source_id, -amount, meters, stack, params, player, logged)
	elif amount > 0:
		RunMeters.apply_amount(state, source_id, amount, meters, stack, params, player, logged)


## Moves cards one for one between the player and seat, logging each direction.
func trade(seat: int, given: Array[int], taken: Array[int]) -> void:
	var done: RoundState.Reason = round_state.trade(player, given, seat, taken)
	assert(done == RoundState.Reason.OK, "A checked trade was refused")
	add_event(RunEvent.new(RunEvent.Type.CARDS_MOVED, player, seat, 0.0, _joined(given)))
	add_event(RunEvent.new(RunEvent.Type.CARDS_MOVED, seat, player, 0.0, _joined(taken)))


## Marks each chosen card for the run: with the enhancement, or with the player's stamp
## when it is CardInstance.NO_ID.
func mark_chosen(enhancement_id: String) -> void:
	var stamping: bool = enhancement_id == CardInstance.NO_ID
	var mark: Callable = _stamp if stamping else _enhance.bind(enhancement_id)
	for card_id: int in card_ids:
		round_state.mark(player, card_id, mark)
	var value: int = CardInstance.mark_value(enhancement_id)
	add_event(RunEvent.new(RunEvent.Type.CARDS_MARKED, player, value, 0.0, _joined(card_ids)))


func _stamp(card: CardInstance) -> void:
	CardMarks.stamp(state, card, player)


func _enhance(card: CardInstance, enhancement_id: String) -> void:
	CardMarks.enhance(state, card, enhancement_id)


static func _joined(ids: Array[int]) -> String:
	var parts: PackedStringArray = []
	for card_id: int in ids:
		parts.append(str(card_id))
	return ",".join(parts)
