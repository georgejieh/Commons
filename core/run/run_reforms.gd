class_name RunReforms
extends RefCounted
## The player's Reforms (ADR 0021): permanent upgrades held in RunState.reforms, in the
## order they were enacted. This is the one place the run reads what they change: how
## many Cadres and Campaigns the player can hold, what a met Quota pays and a missed one
## costs, how many items an envelope holds, and whether the deck is gathered, not
## shuffled, between a Quota's rounds. A held ID with no definition changes nothing.

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


static func _effects(state: RunState) -> Array[ReformEffect]:
	var effects: Array[ReformEffect] = []
	for reform_id: String in state.reforms:
		var reform: ReformDef = definition(reform_id)
		if reform != null and ReformRegistry.has_effect(reform_id):
			effects.append(ReformRegistry.create(reform))
	return effects
