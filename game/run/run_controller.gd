# gdlint: disable=max-public-methods
# Over 20 public methods: this is the UI's whole command and query surface, kept in one place.
class_name RunController
extends Node
## The one way the UI touches a run. It owns the run loop and its state, takes the UI's
## commands, and re-emits the loop's domain events as signals. Queries hand out copies,
## so a view can read the run but never change it. With a save service it saves after
## every state boundary and every command, so quitting at any moment loses nothing.

signal event_emitted(event: RunEvent)
## The loop now waits on this value, one of the AWAIT constants.
signal awaiting_changed(awaiting: int)
## A command the loop refused, with its reason.
signal command_refused(command: String, reason: int)

## Every command the UI may send. Selection is the hand model's, not the run's.
const COMMANDS: Array[String] = [
	"bid",
	"swap",
	"play",
	"pass",
	"declare_need",
	"finish_set",
	"buy",
	"reroll",
	"leave_store",
]
## What the run waits on, for views that may not name the loop.
const AWAIT_BID: int = RunLoop.Awaiting.PLAYER_BID
const AWAIT_SWAP: int = RunLoop.Awaiting.PLAYER_SWAP
const AWAIT_PLAY: int = RunLoop.Awaiting.PLAYER_PLAY
const AWAIT_NEED: int = RunLoop.Awaiting.PLAYER_NEED
const AWAIT_SET_OVER: int = RunLoop.Awaiting.SET_OVER
const AWAIT_STORE: int = RunLoop.Awaiting.SHOP
const AWAIT_RUN_OVER: int = RunLoop.Awaiting.RUN_OVER
const AWAIT_REEDUCATION: int = RunLoop.Awaiting.REEDUCATION
const OK: int = RunLoop.Reason.OK

var _loop: RunLoop
var _saves: SaveService = null
var _definitions: Dictionary[String, ModifierDef] = {}


## Starts a new run from seed, with one bot config per seat.
func start_run(
	seed_value: int,
	configs: Array[BotConfig],
	sets: SetConfig = SetConfig.new(),
	saves: SaveService = null,
	starting_coupons: int = 0
) -> void:
	var state: RunState = RunState.new(seed_value)
	state.coupons = starting_coupons
	_attach(RunLoop.new(state, configs, sets), saves)
	_loop.start_set()
	_loop.set_log.flush()
	awaiting_changed.emit(_loop.awaiting())


## Takes over a loop that was resumed from a save.
func resume(loop: RunLoop, saves: SaveService = null) -> void:
	_attach(loop, saves)
	awaiting_changed.emit(_loop.awaiting())


## Resumes the run in the save, falling back to its backup. False when neither loads.
func resume_saved(saves: SaveService, configs: Array[BotConfig], sets: SetConfig) -> bool:
	var loaded: SaveLoad = saves.load_save()
	if (
		loaded.status != SaveLoad.Status.OK
		and loaded.status != SaveLoad.Status.RESTORED_FROM_BACKUP
	):
		return false
	var loop: RunLoop = RunRecord.resume(loaded.data, configs, sets)
	if loop == null:
		return false
	resume(loop, saves)
	return true


func has_run() -> bool:
	return _loop != null


func bid(claim: bool) -> int:
	return _finish("bid", _loop.player_bid(claim))


func swap(hand_ids: Array[int], plot_ids: Array[int]) -> int:
	return _finish("swap", _loop.player_swap(hand_ids.duplicate(), plot_ids.duplicate()))


func play(card_ids: Array[int]) -> int:
	return _finish("play", _loop.player_play(card_ids.duplicate()))


func pass_turn() -> int:
	var none: Array[int] = []
	return _finish("pass", _loop.player_play(none))


func declare_need(need: int) -> int:
	return _finish("declare_need", _loop.player_need(need))


## Moves past a finished Set: into the state store, or past the run's last Set to its end.
func finish_set() -> int:
	if is_last_set():
		return _finish("finish_set", _loop.next_set())
	return _finish("finish_set", _loop.open_shop())


func buy(slot: int) -> int:
	return _finish("buy", _loop.player_buy(slot))


func reroll() -> int:
	return _finish("reroll", _loop.player_reroll())


## Leaves the store for the next Set, or the run's end.
func leave_store() -> int:
	return _finish("leave_store", _loop.next_set())


## Returns from reeducation to the next Set, or the run's end.
func leave_reeducation() -> int:
	return _finish("leave_reeducation", _loop.next_set())


func awaiting() -> int:
	return _loop.awaiting()


func is_last_set() -> bool:
	var state: RunState = _loop.state
	return state.set_type == RunState.SetType.BOSS and state.year == _loop.sets().years()


## The store's stock per slot, an empty ID for a sold slot.
func store_stock() -> Array[String]:
	return _loop.shop.stock()


func store_price(slot: int) -> int:
	return _loop.shop.price(slot)


func reroll_price() -> int:
	return _loop.shop.reroll_price()


## Coupons the current Set pays when its Quota is met.
func quota_reward() -> int:
	return _loop.sets().reward(_loop.state.set_type)


## How much Famine a missed Quota adds.
func famine_per_miss() -> int:
	return RunLoop.DEFAULT_METERS.source(RunMeters.MISSED_TARGET).amount


## True while high Famine cuts the store's slots.
func is_rationed() -> bool:
	return _loop.state.rationed


## The Famine value rationing must fall below to lift.
func rationing_lifts_below() -> int:
	var bands: MeterBands = RunLoop.DEFAULT_METERS.famine
	return bands.mid - bands.rearm_margin


## Cadres the player can hold at once.
func cadre_slots() -> int:
	return RunLoop.DEFAULT_SHOP.cadre_slots


## What every villager declares by default, a fair need to start the player's choice.
func base_need() -> int:
	return RunLoop.DEFAULT_PARAMS.base_need


## The Denunciation a lie about need costs when an audit catches it.
func lie_cost() -> int:
	return RunLoop.DEFAULT_METERS.source(RunMeters.CAUGHT_LIE).amount


## A reroll is worth pressing: affordable, and the board has room for what it draws.
func can_reroll() -> bool:
	var state: RunState = _loop.state
	return state.coupons >= reroll_price() and state.inventory.cadres.size() < cadre_slots()


func can_buy(slot: int) -> bool:
	return _loop.shop.check_buy(slot) == RunShop.Reason.OK


## The current Set's events so far, for a view that joins mid-Set.
func set_events() -> Array[RunEvent]:
	return _loop.events().duplicate()


## The player's seat view of the current round, or null between rounds.
func seat_view() -> SeatView:
	var round_state: RoundState = _loop.round_state()
	if round_state == null:
		return null
	return round_state.view_for(RunLoop.PLAYER)


## Copies of the player's cards.
func player_cards() -> Array[CardInstance]:
	return _loop.player_cards()


## The rules and rank order the player plays under.
func player_table() -> BotTable:
	return _loop.seat_table(RunLoop.PLAYER)


## The legal moves when the player must play, else none.
func legal_moves() -> Array[Pattern]:
	if _loop.awaiting() != RunLoop.Awaiting.PLAYER_PLAY:
		return []
	return _loop.round_state().legal_moves()


## The player's card IDs for a pattern, by the fixed selection policy.
func card_ids_for(pattern: Pattern) -> Array[int]:
	return _loop.round_state().action_for(pattern).card_ids.duplicate()


## How the player's chosen cards read and what they would score now, or null between
## rounds. A preview changes nothing.
func preview_play(card_ids: Array[int]) -> PlayPreview:
	if _loop.round_state() == null:
		return null
	return _loop.preview_play(card_ids.duplicate())


## The modifiers in play now: Cadres in slot order, then this Set's debuffs so far.
func active_modifier_ids() -> Array[String]:
	var state: RunState = _loop.state
	var ids: Array[String] = state.inventory.cadres.duplicate()
	for round_index: int in range(1, mini(state.round_index + 1, state.debuff_ladder.size())):
		if state.debuff_ladder[round_index] != RunState.NO_DEBUFF:
			ids.append(state.debuff_ladder[round_index])
	return ids


## The Set's ladder: one debuff ID per round, round 1 always empty.
func ladder() -> Array[String]:
	return _loop.state.debuff_ladder.duplicate()


## A modifier's rules text with its parameters filled in.
func modifier_text(modifier_id: String) -> String:
	var definition: ModifierDef = _definitions[modifier_id]
	return tr(definition.text_key).format(definition.parameters)


func target() -> float:
	return _loop.target()


## A copy of the run state, for display.
func state_copy() -> RunState:
	return RunState.from_dict(_loop.state.to_dict())


func _attach(loop: RunLoop, saves: SaveService) -> void:
	_loop = loop
	# A replayed loop may hold events banking appended unseen; the view reads those from
	# set_events(), so the listener starts after them.
	_loop.set_log.flush()
	for definition: ModifierDef in RunLoop.DEFAULT_POOL.debuffs + RunLoop.DEFAULT_CADRES.cadres:
		_definitions[definition.id] = definition
	_saves = saves
	_loop.set_log.on_add = func(event: RunEvent) -> void: event_emitted.emit(event)
	_loop.on_boundary = func(_at: RunLoop) -> void: _save()


func _finish(command: String, reason: RunLoop.Reason) -> int:
	_loop.set_log.flush()
	if reason != RunLoop.Reason.OK:
		command_refused.emit(command, reason)
	else:
		_save()
		awaiting_changed.emit(_loop.awaiting())
	return reason


func _save() -> void:
	if _saves != null:
		_saves.save(_loop.record.to_dict())
