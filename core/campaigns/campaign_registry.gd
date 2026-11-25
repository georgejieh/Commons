class_name CampaignRegistry
extends RefCounted
## Maps Campaign IDs to effect scripts. Definitions stay data; behaviour stays here.


static func has_effect(campaign_id: String) -> bool:
	return _build(campaign_id) != null


## Returns a new effect for the definition, with its parameters.
static func create(definition: CampaignDef) -> CampaignEffect:
	var effect: CampaignEffect = _build(definition.id)
	effect.parameters = definition.parameters.duplicate()
	return effect


static func _build(campaign_id: String) -> CampaignEffect:
	match campaign_id:
		"model_harvest":
			return MarkCardsEffect.new(CardInstance.MODEL)
		"autumn_gleaning":
			return MarkCardsEffect.new(CardInstance.SHEAF)
		"emulation_contest":
			return MarkCardsEffect.new(CardInstance.PENNANT)
		"surplus_sale":
			return MarkCardsEffect.new(CardInstance.SURPLUS)
		"registration_drive":
			return MarkCardsEffect.new(CardInstance.NO_ID)
		"mutual_aid":
			return MutualAidEffect.new()
		"overfulfillment":
			return OverfulfillmentEffect.new()
		"appeal":
			return AppealEffect.new()
		"grain_loan":
			return GrainLoanEffect.new()
		"seizure_notice":
			return SeizureNoticeEffect.new()
		"anonymous_letter":
			return AnonymousLetterEffect.new()
		"model_worker":
			return ModelWorkerEffect.new()
		"self_criticism":
			return SelfCriticismEffect.new()
		"relief_grain":
			return ReliefGrainEffect.new()
		"false_report":
			return FalseReportEffect.new()
	return null
