class_name DebuffLadder
extends RefCounted
## Draws a Set's debuff ladder on the debuff stream, one round at a time. Round 0 is
## clean, and a later round's tier never passes its round number. The tier is weighted
## toward the round's own, and a debuff never repeats or shares a lever with another in
## the Set. Each round keeps one severity point of the budget for every round after it,
## so a ladder never runs dry; a draw that would spend more is redrawn a tier lower.
## Cost is O(rounds × pool size).

const DEFAULT_PARAMS: LadderParams = preload("res://data/run/default_ladder.tres")


## Returns one debuff ID per round. A round with nothing left to draw stays clean.
static func draw(
	pool: Array[ModifierDef],
	set_type: RunState.SetType,
	rounds: int,
	stream: RandomStream,
	params: LadderParams = DEFAULT_PARAMS
) -> Array[String]:
	var ladder: Array[String] = [RunState.NO_DEBUFF]
	var used_ids: Dictionary[String, bool] = {}
	var used_levers: Dictionary[int, bool] = {}
	var budget: int = params.severity_budgets[set_type]
	for round_index: int in range(1, rounds):
		var cap: int = mini(round_index + 1, ModifierDef.MAX_TIER)
		var reserved: int = rounds - 1 - round_index
		var tier: int = mini(_weighted_tier(cap, stream, params), budget - reserved)
		var picked: ModifierDef = null
		while tier >= 1 and picked == null:
			picked = _pick(pool, tier, used_ids, used_levers, stream)
			tier -= 1
		if picked == null:
			ladder.append(RunState.NO_DEBUFF)
			continue
		ladder.append(picked.id)
		used_ids[picked.id] = true
		used_levers[picked.lever] = true
		budget -= picked.tier
	return ladder


## Tier cap - k gets weight k; tiers below 1 drop out and the rest renormalize.
static func _weighted_tier(cap: int, stream: RandomStream, params: LadderParams) -> int:
	var total: int = 0
	for offset: int in params.tier_weights.size():
		if cap - offset >= 1:
			total += params.tier_weights[offset]
	var roll: int = stream.next_int(1, total)
	for offset: int in params.tier_weights.size():
		if cap - offset < 1:
			break
		roll -= params.tier_weights[offset]
		if roll <= 0:
			return cap - offset
	return 1


static func _pick(
	pool: Array[ModifierDef],
	tier: int,
	used_ids: Dictionary[String, bool],
	used_levers: Dictionary[int, bool],
	stream: RandomStream
) -> ModifierDef:
	var eligible: Array[ModifierDef] = []
	for definition: ModifierDef in pool:
		if (
			definition.kind == ModifierDef.Kind.DEBUFF
			and definition.tier == tier
			and not used_ids.has(definition.id)
			and not used_levers.has(definition.lever)
		):
			eligible.append(definition)
	if eligible.is_empty():
		return null
	return eligible[stream.next_int(0, eligible.size() - 1)]
