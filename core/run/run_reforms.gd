class_name RunReforms
extends RefCounted
## The player's Reforms (ADR 0021): permanent upgrades held in RunState.reforms, in the
## order they were enacted. This is the one place the run reads what they change: how
## many Cadres and Campaigns the player can hold, what a met Quota pays and a missed one
## costs, how many items an envelope holds, whether the deck is gathered, not shuffled,
## between a Quota's rounds, how many ranks each deal makes wild, and the rules a Reform
## puts on the table. A held ID with no definition changes nothing.

const POOL: ReformPool = preload("res://data/run/reform_pool.tres")
## The player's limits before any Reform are the state store's numbers.
const LIMITS: ShopParams = preload("res://data/run/default_shop.tres")


## Every Reform the state store sells.
static func all() -> Array[ReformDef]:
	return POOL.reforms


static func definition(reform_id: String) -> ReformDef:
	for reform: ReformDef in POOL.reforms:
		if reform.id == reform_id:
			return reform
	return null


## Cadres the player can hold at once. Both shops, both boards and every rule that
## counts a full board read this.
static func cadre_slots(state: RunState) -> int:
	var extra: int = 0
	for effect: ReformEffect in _effects(state):
		extra += effect.extra_cadres()
	return LIMITS.cadre_slots + extra


## Campaigns the player can hold at once.
static func campaign_slots(state: RunState) -> int:
	var extra: int = 0
	for effect: ReformEffect in _effects(state):
		extra += effect.extra_campaigns()
	return LIMITS.campaign_slots + extra


## More items every envelope holds to choose from, for the envelopes (P4.11g).
static func extra_envelope_choices(state: RunState) -> int:
	var extra: int = 0
	for effect: ReformEffect in _effects(state):
		extra += effect.extra_envelope_choices()
	return extra


## Coupons a met Quota pays on top of its reward.
static func quota_coupons(state: RunState) -> int:
	var extra: int = 0
	for effect: ReformEffect in _effects(state):
		extra += effect.quota_coupons()
	return extra


## The Famine a missed Quota adds, from the meter table's amount: less by every relief
## held, and never below 0.
static func missed_famine(state: RunState, amount: int) -> int:
	var relief: int = 0
	for effect: ReformEffect in _effects(state):
		relief += effect.famine_relief()
	return maxi(amount - relief, 0)


## True while the deck is gathered and cut between a Quota's rounds.
static func gathers_deck(state: RunState) -> bool:
	for effect: ReformEffect in _effects(state):
		if effect.gathers_deck():
			return true
	return false


## Ranks drawn wild with every deal, for every seat: Mass Line's (ADR 0029).
static func wild_ranks_per_round(state: RunState) -> int:
	var ranks: int = 0
	for effect: ReformEffect in _effects(state):
		ranks += effect.wild_ranks_per_round()
	return ranks


## The rules held Reforms put on the table for every seat, in the order they were
## enacted, each as a stack entry of kind REFORM that runs only its own hooks: today
## Industrialization's bigger bombs (ADR 0029).
static func table_rules(state: RunState) -> Array[ActiveModifier]:
	var rules: Array[ActiveModifier] = []
	for reform_id: String in state.reforms:
		var reform: ReformDef = definition(reform_id)
		if reform == null or not ReformRegistry.has_effect(reform_id):
			continue
		var effect: ReformEffect = ReformRegistry.create(reform)
		if effect.rule_hooks().is_empty():
			continue
		var rule: ModifierDef = ModifierDef.new()
		rule.id = reform.id
		rule.kind = ModifierDef.Kind.REFORM
		rule.lever = ModifierDef.Lever.RULE
		rule.hooks.assign(effect.rule_hooks())
		rule.parameters = reform.parameters.duplicate()
		rule.name_key = reform.name_key
		rule.text_key = reform.text_key
		rule.table_wide = true
		rules.append(ActiveModifier.new(rule, effect.table_rule()))
	return rules


## The held Reforms that put a rule on the table, in the order they were enacted.
static func table_rule_ids(state: RunState) -> Array[String]:
	var ids: Array[String] = []
	for rule: ActiveModifier in table_rules(state):
		ids.append(rule.definition.id)
	return ids


static func _effects(state: RunState) -> Array[ReformEffect]:
	var effects: Array[ReformEffect] = []
	for reform_id: String in state.reforms:
		var reform: ReformDef = definition(reform_id)
		if reform != null and ReformRegistry.has_effect(reform_id):
			effects.append(ReformRegistry.create(reform))
	return effects
