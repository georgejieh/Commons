class_name EffectRegistry
extends RefCounted
## Maps modifier IDs to effect scripts. Definitions stay data; behavior stays here.

## The meter each loss-meter debuff raises, by ID. Its effect is the one built with an
## argument.
const LOSS_METERS: Dictionary[String, String] = {
	"big_character_poster": RunMeters.DEBUFF_DENUNCIATION,
	"hungry_winter": RunMeters.DEBUFF_FAMINE,
}

## Every other effect script, by the ID of the definition it serves.
static var _scripts: Dictionary[String, Script] = {
	"cultural_revolution": CulturalRevolutionEffect,
	"promotion_of_the_masses": PromotionEffect,
	"criticism_meeting": RankAsEffect,
	"inverted_order": InvertedOrderEffect,
	"iron_rice_bowl": IronRiceBowlEffect,
	"stakhanovite": StakhanoviteEffect,
	"hidden_reserves": HiddenReservesEffect,
	"landlords_ledger": LandlordsLedgerEffect,
	"ration_cut": RationCutEffect,
	"paperwork": TypeShareEffect,
	"straightened_lines": TypeShareEffect,
	"morning_meeting": MorningMeetingEffect,
	"struggle_session": StruggleSessionEffect,
	"requisition": RequisitionEffect,
	"great_leap": GreatLeapEffect,
	"the_handicap": HandicapEffect,
	"the_purge": BossMarkerEffect,
	"risen_villager": BossMarkerEffect,
	"new_landlord": BossMarkerEffect,
	"planned_allocation": PlannedAllocationEffect,
	"red_ink": OwnerStampEffect,
	"the_informant": InfoMarkerEffect,
	"peek": InfoMarkerEffect,
	"the_tally_clerk": InfoMarkerEffect,
	"rehabilitation": RehabilitationEffect,
	"class_label": ClassLabelEffect,
	"collective_farm": CollectiveFarmEffect,
	"show_trial": ShowTrialEffect,
	"model_commune": ModelCommuneEffect,
	"ration_coupon": RationCouponEffect,
	"shock_brigade": ShockBrigadeEffect,
	"canteen": CanteenEffect,
	"red_banner": RedBannerEffect,
	"poor_peasants_association": PoorPeasantsEffect,
	"seed_grain": SeedGrainEffect,
	"the_bookkeeper": BookkeeperEffect,
	"last_sheaf": LastSheafEffect,
	"steel_target": SteelTargetEffect,
	"short_supply": ShortSupplyEffect,
	"slogan_of_the_week": SloganEffect,
	"levy": LevyEffect,
	"work_point_audit": AuditFacesEffect,
	"night_shift": NightShiftEffect,
	"grain_tax": GrainTaxEffect,
	"shared_kitchen": SharedKitchenEffect,
	"confiscation": ConfiscationEffect,
	"glass_walls": GlassWallsEffect,
	"redistribution": RedistributionEffect,
	"overtime": OvertimeEffect,
	"plot_seized": PlotSeizedEffect,
	"night_school": NightSchoolEffect,
	"iron_and_coal": IronAndCoalEffect,
	"advanced_cooperative": AdvancedCooperativeEffect,
	"double_share_plough": DoubleSharePloughEffect,
	"open_accounts": OpenAccountsEffect,
	"tractor_station": TractorStationEffect,
	"the_gleaners": GleanersEffect,
	"public_granary": PublicGranaryEffect,
	"five_year_plan": FiveYearPlanEffect,
	"back_door": BackDoorEffect,
	"informers_reward": InformersRewardEffect,
	"forged_seal": ForgedSealEffect,
	"loudspeaker": LoudspeakerEffect,
	"rent_book": RentBookEffect,
	"grain_speculator": GrainSpeculatorEffect,
	"prize_exhibit": PrizeExhibitEffect,
}


## True when the modifier ID has an effect script or is a loss meter; a definition without one is a
## data error.
static func has_effect(modifier_id: String) -> bool:
	return _scripts.has(modifier_id) or LOSS_METERS.has(modifier_id)


## Returns a new effect for the definition, held by the seat, with the Cadre's saved run
## state when it has one.
static func create(
	definition: ModifierDef, holder_seat: int, memo: CadreMemo = null
) -> ModifierEffect:
	var effect: ModifierEffect = _build(definition.id)
	effect.parameters = definition.parameters.duplicate()
	effect.holder_seat = holder_seat
	if memo != null:
		effect.memo = memo
	return effect


static func _build(modifier_id: String) -> ModifierEffect:
	if LOSS_METERS.has(modifier_id):
		return LossMeterEffect.new(LOSS_METERS[modifier_id])
	# Only a GDScript has new(), and core names no engine script class, so the effect
	# is made through call.
	return _scripts[modifier_id].call("new")
