class_name ModifierStack
extends RefCounted
## The active modifiers. Every hook runs Cadres in slot order, then debuffs in ladder
## order, then the boss twist. Anything else is held in slot order with the Cadres.

## Changes with every add, remove, enable or disable, so caches can tell they are stale.
var revision: int = 0

var _entries: Array[ActiveModifier] = []
var _ordered: Array[ActiveModifier] = []
var _by_hook: Dictionary[String, Array] = {}


func _init() -> void:
	_changed()


func add(definition: ModifierDef, holder_seat: int) -> ActiveModifier:
	var entry: ActiveModifier = ActiveModifier.new(
		definition, EffectRegistry.create(definition, holder_seat)
	)
	add_entry(entry)
	return entry


func add_entry(entry: ActiveModifier) -> void:
	_entries.append(entry)
	_changed()


func remove(entry: ActiveModifier) -> void:
	_entries.erase(entry)
	_changed()


func set_enabled(entry: ActiveModifier, enabled: bool) -> void:
	entry.enabled = enabled
	_changed()


## Returns enabled entries in hook order.
func ordered_entries() -> Array[ActiveModifier]:
	return _ordered.duplicate()


func run_build_ruleset(context: RulesetContext) -> void:
	for entry: ActiveModifier in _by_hook[Hooks.BUILD_RULESET]:
		entry.effect.build_ruleset(context)


func run_build_rank_map(context: RankMapContext) -> void:
	for entry: ActiveModifier in _by_hook[Hooks.BUILD_RANK_MAP]:
		entry.effect.build_rank_map(context)


func run_on_deal(context: DealContext) -> void:
	for entry: ActiveModifier in _by_hook[Hooks.ON_DEAL]:
		entry.effect.on_deal(context)


func run_round_start(context: RoundContext) -> void:
	for entry: ActiveModifier in _by_hook[Hooks.ROUND_START]:
		entry.effect.round_start(context)


func run_play_scored(context: PlayContext) -> void:
	for entry: ActiveModifier in _by_hook[Hooks.PLAY_SCORED]:
		entry.effect.play_scored(context)


func run_card_scored(context: CardContext) -> void:
	for entry: ActiveModifier in _by_hook[Hooks.CARD_SCORED]:
		entry.effect.card_scored(context)


func run_trick_won(context: TrickContext) -> void:
	for entry: ActiveModifier in _by_hook[Hooks.TRICK_WON]:
		entry.effect.trick_won(context)


func run_round_end(context: RoundContext) -> void:
	for entry: ActiveModifier in _by_hook[Hooks.ROUND_END]:
		entry.effect.round_end(context)


func run_set_end(context: SetContext) -> void:
	for entry: ActiveModifier in _by_hook[Hooks.SET_END]:
		entry.effect.set_end(context)


func run_shop_open(context: ShopContext) -> void:
	for entry: ActiveModifier in _by_hook[Hooks.SHOP_OPEN]:
		entry.effect.shop_open(context)


func run_meter_change(context: MeterContext) -> void:
	for entry: ActiveModifier in _by_hook[Hooks.METER_CHANGE]:
		entry.effect.meter_change(context)


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
