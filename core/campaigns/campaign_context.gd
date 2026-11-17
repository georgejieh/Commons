class_name CampaignContext
extends RefCounted
## What one use of a Campaign reads and changes: the run, the round when there is one,
## the round's Campaign flags, the cards chosen and where events go.

## Where the run stands when a Campaign is checked.
enum Moment { ELSEWHERE, OPENING, TURN, SHOP }

const RESENTMENT: ResentmentParams = preload("res://data/run/resentment.tres")
## The meter row a Campaign's Famine moves through; its amount is the Campaign's.
const FAMINE_SOURCE: String = "campaign_famine"
## The meter row a Campaign's Denunciation moves through; its amount is the Campaign's.
const DENUNCIATION_SOURCE: String = "campaign_denunciation"

var definition: CampaignDef
var state: RunState
## Null in a shop.
var round_state: RoundState = null
var table: SeatRules
var stack: ModifierStack
var meters: MeterTable
var params: RunParams
var flags: CampaignRound
var set_log: SetLog
var moment: Moment = Moment.ELSEWHERE
## True before the round's first play.
var opening: bool = false
var card_ids: Array[int] = []
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
	return BotTable.new(table.rules_for(seat), table.map_for(seat))


func add_event(event: RunEvent) -> void:
	set_log.add(event)


func resent(amount: int) -> void:
	if amount != 0:
		Resentment.add(state, amount, Resentment.CAMPAIGN, RESENTMENT, set_log.events())


## Lowers Resentment through its one path down (ADR 0032).
func relent(amount: int) -> void:
	if amount != 0:
		Resentment.lower(state, amount, Resentment.CAMPAIGN, RESENTMENT, set_log.events())


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


## Marks each chosen card for the run: Model, or the player's stamp.
func mark_chosen(model: bool) -> void:
	for card_id: int in card_ids:
		round_state.mark(player, card_id, _make_model if model else _stamp)
	var value: int = 1 if model else 0
	add_event(RunEvent.new(RunEvent.Type.CARDS_MARKED, player, value, 0.0, _joined(card_ids)))


func _stamp(card: CardInstance) -> void:
	CardMarks.stamp(state, card, player)


func _make_model(card: CardInstance) -> void:
	CardMarks.make_model(state, card)


static func _joined(card_ids: Array[int]) -> String:
	var parts: PackedStringArray = []
	for card_id: int in card_ids:
		parts.append(str(card_id))
	return ",".join(parts)
