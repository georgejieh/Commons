class_name RunItemsView
extends RefCounted
## The run's Cadres, Campaigns, Reforms, Directives and debuffs: which are held and in
## force, what each asks for, and whether a held Campaign can be used now. Every list
## is a copy. RunController builds it over each run it attaches, as controller.items.

var _loop: RunLoop


func _init(loop: RunLoop) -> void:
	_loop = loop


## The Campaigns the player holds, in slot order.
func held_campaigns() -> Array[String]:
	return _loop.state.inventory.consumables.duplicate()


## The Reforms in force, in the order they were enacted.
func held_reforms() -> Array[String]:
	return _loop.state.reforms.duplicate()


## The modifiers in play now: Cadres in slot order, then this Set's debuffs so far.
func active_modifier_ids() -> Array[String]:
	var ids: Array[String] = _loop.state.inventory.cadres.duplicate()
	ids.append_array(active_debuff_ids())
	return ids


## This Set's debuffs so far, in the order they arrived.
func active_debuff_ids() -> Array[String]:
	var state: RunState = _loop.state
	var ids: Array[String] = []
	for round_index: int in range(1, mini(state.round_index + 1, state.debuff_ladder.size())):
		if state.debuff_ladder[round_index] != RunState.NO_DEBUFF:
			ids.append(state.debuff_ladder[round_index])
	return ids


## The Set's ladder: one debuff ID per round, round 1 always empty.
func ladder() -> Array[String]:
	return _loop.state.debuff_ladder.duplicate()


## The current Set's boss twist ID, or an empty string outside boss Sets.
func boss() -> String:
	return _loop.state.boss_id


## The held Reforms that give the player's seat a rule that changes play, such as
## Industrialization, for the rules strip and the Rules sheet.
func table_rule_reforms() -> Array[String]:
	return RunReforms.table_rule_ids(_loop.state)


## The held Cadres a Confiscation left out of this round.
func confiscated_cadres() -> Array[String]:
	return _loop.debuffs.confiscated_ids()


## The debuff Appeal lifted this round, or an empty ID.
func lifted_debuff() -> String:
	return _loop.campaigns.flags.lifted


## True when a Cadre's scoring also pays on the player's teammate's plays while the player
## is a peasant (ADR 0039). No Cadre changes another seat's rules or ranks.
func counts_for_teammate(modifier_id: String) -> bool:
	var definition: ModifierDef = RunDefinitions.modifiers[modifier_id]
	return definition.counts_for_teammate


## True when buying the Cadre asks for a rank first (ADR 0021).
func needs_rank(cadre_id: String) -> bool:
	return RunDefinitions.modifiers.has(cadre_id) and RunDefinitions.modifiers[cadre_id].needs_rank


## Where a held Cadre stands in the run: its state line and badge count, both empty when
## it keeps no state or is not held.
func cadre_standing(cadre_id: String) -> CadreStanding:
	var state: RunState = _loop.state
	if not RunDefinitions.modifiers.has(cadre_id) or not state.inventory.cadres.has(cadre_id):
		return CadreStanding.new()
	return CadreStanding.of(RunDefinitions.modifiers[cadre_id], state.cadre_memos.peek(cadre_id))


## The hand types a Directive raises, as Pattern.Type values.
func directive_types(directive_id: String) -> Array[int]:
	return RunDefinitions.directives[directive_id].hand_types.duplicate()


## Why the held Campaign in slot cannot be used now, as a CampaignEffect.Reason, or
## CAMPAIGN_OK. With check_cards false the chosen cards are left aside.
func campaign_reason(slot: int, card_ids: Array[int] = [], check_cards: bool = false) -> int:
	return _loop.campaign_reason(slot, card_ids.duplicate(), check_cards)


## The fewest and most hand cards a Campaign asks for, as x and y.
func campaign_cards(campaign_id: String) -> Vector2i:
	var definition: CampaignDef = RunDefinitions.campaigns[campaign_id]
	return Vector2i(definition.min_cards, definition.max_cards)


## One of a Campaign's numbers from its data, or 0.
func campaign_parameter(campaign_id: String, key: String) -> int:
	return RunDefinitions.campaigns[campaign_id].parameters.get(key, 0)


## True for a Campaign tagged private.
func is_private_campaign(campaign_id: String) -> bool:
	return RunDefinitions.campaigns[campaign_id].tag == ModifierDef.Tag.PRIVATE
