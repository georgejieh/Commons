class_name ModifierStack
extends RefCounted
## The active modifiers. Every hook runs Cadres in slot order, then debuffs in ladder
## order, then the boss twist. Anything else is held in slot order with the Cadres. The
## four seat hooks skip an entry whose reach leaves the seat out (SeatScope, ADR 0039).

## Changes with every add, remove, enable or disable, so caches can tell they are stale.
var revision: int = 0

var _entries: Array[ActiveModifier] = []
var _ordered: Array[ActiveModifier] = []
var _by_hook: Dictionary[String, Array] = {}


func _init() -> void:
	_changed()


## memo is the Cadre's saved run state; without one the effect keeps a fresh one.
func add(definition: ModifierDef, holder_seat: int, memo: CadreMemo = null) -> ActiveModifier:
	var entry: ActiveModifier = ActiveModifier.new(
		definition, EffectRegistry.create(definition, holder_seat, memo)
	)
	add_entry(entry)
	return entry


## Adds an entry already built, after the ones held, in its order group.
func add_entry(entry: ActiveModifier) -> void:
	_entries.append(entry)
	_changed()


## Removes the entry; an entry not held is ignored.
func remove(entry: ActiveModifier) -> void:
	_entries.erase(entry)
	_changed()


## Removes every entry, enabled or not.
func clear() -> void:
	_entries.clear()
	_changed()


## Switches the entry on or off; an entry that is off runs no hook until switched on.
func set_enabled(entry: ActiveModifier, enabled: bool) -> void:
	entry.enabled = enabled
	_changed()


## Returns enabled entries in hook order.
func ordered_entries() -> Array[ActiveModifier]:
	return _ordered.duplicate()


## Runs the build ruleset hook of every entry that reaches the context's seat.
func run_build_ruleset(context: RulesetContext) -> void:
	for entry: ActiveModifier in _by_hook[Hooks.BUILD_RULESET]:
		if entry.builds_for(context.seat):
			entry.effect.build_ruleset(context)


## Runs the build rank map hook of every entry that reaches the context's seat.
func run_build_rank_map(context: RankMapContext) -> void:
	for entry: ActiveModifier in _by_hook[Hooks.BUILD_RANK_MAP]:
		if entry.builds_for(context.seat):
			entry.effect.build_rank_map(context)


## Runs the on deal hook of every entry, in hook order.
func run_on_deal(context: DealContext) -> void:
	for entry: ActiveModifier in _by_hook[Hooks.ON_DEAL]:
		entry.effect.on_deal(context)


## Runs the round start hook of every entry, in hook order.
func run_round_start(context: RoundContext) -> void:
	for entry: ActiveModifier in _by_hook[Hooks.ROUND_START]:
		entry.effect.round_start(context)


## With a trail, each hook's change is recorded as it runs, for the table.
func run_play_scored(context: PlayContext, trail: ScoreTrail = null) -> void:
	if trail != null:
		trail.start_play(context)
	for entry: ActiveModifier in _by_hook[Hooks.PLAY_SCORED]:
		if not entry.scores_for(context.seat, context.landlord):
			continue
		entry.effect.play_scored(context)
		if trail != null:
			trail.play_hook(entry.definition, context)


## Runs the card scored hook of every entry that scores the context's seat. With a trail, each
## change is recorded as it runs.
func run_card_scored(context: CardContext, trail: ScoreTrail = null) -> void:
	for entry: ActiveModifier in _by_hook[Hooks.CARD_SCORED]:
		if not entry.scores_for(context.seat, context.landlord):
			continue
		var before: float = context.grain
		entry.effect.card_scored(context)
		if trail != null:
			trail.card_hook(entry.definition, context, before)


## Runs the round end hook of every entry, in hook order.
func run_round_end(context: RoundContext) -> void:
	for entry: ActiveModifier in _by_hook[Hooks.ROUND_END]:
		entry.effect.round_end(context)


## Runs the Set end hook of every entry, in hook order.
func run_set_end(context: SetContext) -> void:
	for entry: ActiveModifier in _by_hook[Hooks.SET_END]:
		entry.effect.set_end(context)


## Runs the shop open hook of every entry, in hook order.
func run_shop_open(context: ShopContext) -> void:
	for entry: ActiveModifier in _by_hook[Hooks.SHOP_OPEN]:
		entry.effect.shop_open(context)


## Runs the meter change hook of every entry, in hook order.
func run_meter_change(context: MeterContext) -> void:
	for entry: ActiveModifier in _by_hook[Hooks.METER_CHANGE]:
		entry.effect.meter_change(context)


## Runs the audit hook of every entry, in hook order.
func run_audit(context: AuditContext) -> void:
	for entry: ActiveModifier in _by_hook[Hooks.AUDIT]:
		entry.effect.audit(context)


## Runs the turn taken hook of every entry, in hook order.
func run_turn_taken(context: TurnContext) -> void:
	for entry: ActiveModifier in _by_hook[Hooks.TURN_TAKEN]:
		entry.effect.turn_taken(context)


## Runs the need settled hook of every entry, in hook order.
func run_need_settled(context: NeedContext) -> void:
	for entry: ActiveModifier in _by_hook[Hooks.NEED_SETTLED]:
		entry.effect.need_settled(context)


func _changed() -> void:
	revision += 1
	_ordered.clear()
	for group: int in ActiveModifier.ORDER_GROUPS:
		for entry: ActiveModifier in _entries:
			if entry.enabled and entry.order_group() == group:
				_ordered.append(entry)
	for hook: String in Hooks.ALL:
		var listed: Array[ActiveModifier] = []
		for entry: ActiveModifier in _ordered:
			if entry.definition.hooks.has(hook):
				listed.append(entry)
		_by_hook[hook] = listed
