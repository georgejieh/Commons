class_name RunTexts
extends RefCounted
## What the run's items and rules say in the player's words: the names, rules and
## prompts of the Directives, Campaigns, Reforms and modifiers, with the run's numbers
## filled in. RunController builds it over each run it attaches, as controller.texts.

var _loop: RunLoop


## The string key that says why a Campaign is refused, one per reason.
static func campaign_reason_key(reason: int) -> String:
	return "campaign.reason." + String(CampaignEffect.Reason.keys()[reason]).to_lower()


func _init(loop: RunLoop) -> void:
	_loop = loop


## A Directive's name.
func directive_name(directive_id: String) -> String:
	return tr(RunDefinitions.directives[directive_id].name_key)


## A Directive's rules.
func directive_text(directive_id: String) -> String:
	return tr(RunDefinitions.directives[directive_id].text_key)


## A Campaign's name.
func campaign_name(campaign_id: String) -> String:
	return tr(RunDefinitions.campaigns[campaign_id].name_key)


## A Campaign's rules, with its numbers filled in.
func campaign_text(campaign_id: String) -> String:
	var definition: CampaignDef = RunDefinitions.campaigns[campaign_id]
	return tr(definition.text_key).format(definition.text_values())


## What a Campaign asks the player to choose, with its numbers filled in.
func campaign_prompt(campaign_id: String) -> String:
	var definition: CampaignDef = RunDefinitions.campaigns[campaign_id]
	return tr(definition.prompt_key).format(definition.text_values())


## Every Campaign's prompt, held or not, for the table's pieces that must have room for
## the longest (ADR 0034).
func every_campaign_prompt() -> Array[String]:
	var prompts: Array[String] = []
	for pool: CampaignPool in [RunPools.STORE_CAMPAIGNS, RunPools.MARKET_CAMPAIGNS]:
		for definition: CampaignDef in pool.campaigns:
			prompts.append(tr(definition.prompt_key).format(definition.text_values()))
	return prompts


## Every surname a seat can show, for the same pieces.
func every_surname() -> Array[String]:
	return RunPeople.every_surname()


## A Reform's name.
func reform_name(reform_id: String) -> String:
	return tr(RunDefinitions.reforms[reform_id].name_key)


## A Reform's rules with its numbers filled in, the limits it raises included.
func reform_text(reform_id: String) -> String:
	return ItemText.reform(RunDefinitions.reforms[reform_id])


## A modifier's name; a Slogan's names the hand type it was drawn with (ADR 0023).
func modifier_name(modifier_id: String) -> String:
	var type: int = _loop.state.slogan_type
	if modifier_id == RunDebuffs.SLOGAN_ID and type != RunState.NO_SLOGAN:
		return tr("modifier.slogan_of_the_week.named").format({"type": _type_plural(type)})
	return tr(RunDefinitions.modifiers[modifier_id].name_key)


## A modifier's rules text with its parameters filled in.
func modifier_text(modifier_id: String) -> String:
	return CadreText.rules(RunDefinitions.modifiers[modifier_id], _run_values(modifier_id))


## What a card from an envelope is: its name, text or caption by key, with its mark's
## numbers from data. kind is one of EnvelopeShelf's card kinds.
func envelope_card_text(kind: int, key: String, card: CardInstance) -> String:
	var marks: Dictionary[int, String] = {
		EnvelopeShelf.KIND_STAMPED: "stamped",
		EnvelopeShelf.KIND_MODEL: "model",
		EnvelopeShelf.KIND_DECK: "deck",
		EnvelopeShelf.KIND_MARKED_DECK: "marked_deck",
	}
	var model: float = Scorer.DEFAULT_PARAMS.model_grain_percent / 100.0
	var values: Dictionary[String, Variant] = {
		"resentment": RunDefaults.RESENTMENT.stamped_card,
		"model_times": ModifierDef.multiple(model),
		"card": CardName.of(card),
		"mark":
		"" if card.enhancement_id().is_empty() else tr("keyword.%s.name" % card.enhancement_id()),
	}
	return tr("envelope.card.%s.%s" % [marks[kind], key]).format(values)


## Values a modifier's text takes from the run: the Slogan's hand type, and the meter rise
## a lost round costs.
func _run_values(modifier_id: String) -> Dictionary[String, Variant]:
	var values: Dictionary[String, Variant] = {}
	if modifier_id == RunDebuffs.SLOGAN_ID:
		var type: int = _loop.state.slogan_type
		values["type"] = (
			tr("modifier.slogan_of_the_week.no_type")
			if type == RunState.NO_SLOGAN
			else _type_plural(type)
		)
	var effect: ModifierEffect = EffectRegistry.create(
		RunDefinitions.modifiers[modifier_id], RunLoop.PLAYER
	)
	if effect is HandicapEffect:
		values[HandicapEffect.CARDS] = HandicapEffect.count_at(effect.parameters, _loop.state.year)
	if effect is LossMeterEffect:
		var source: String = (effect as LossMeterEffect).source()
		values["amount"] = RunDefaults.METERS.source(source).amount
	return values


func _type_plural(type: int) -> String:
	return tr("pattern.plural." + String(Pattern.Type.keys()[type]).to_lower())
