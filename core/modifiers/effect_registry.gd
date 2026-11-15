class_name EffectRegistry
extends RefCounted
## Maps modifier IDs to effect scripts. Definitions stay data; behavior stays here.


static func has_effect(modifier_id: String) -> bool:
	return _build(modifier_id) != null


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
	match modifier_id:
		"cultural_revolution":
			return CulturalRevolutionEffect.new()
		"promotion_of_the_masses":
			return PromotionEffect.new()
		"criticism_meeting":
			return RankAsEffect.new()
		"inverted_order":
			return InvertedOrderEffect.new()
		"iron_rice_bowl":
			return IronRiceBowlEffect.new()
		"stakhanovite":
			return StakhanoviteEffect.new()
		"hidden_reserves":
			return HiddenReservesEffect.new()
		"landlords_ledger":
			return LandlordsLedgerEffect.new()
		"ration_cut":
			return RationCutEffect.new()
		"paperwork", "straightened_lines":
			return TypeShareEffect.new()
		"morning_meeting":
			return MorningMeetingEffect.new()
		"struggle_session":
			return StruggleSessionEffect.new()
		"requisition":
			return RequisitionEffect.new()
		"great_leap":
			return GreatLeapEffect.new()
		"the_purge", "risen_villager", "new_landlord":
			return BossMarkerEffect.new()
		"planned_allocation":
			return PlannedAllocationEffect.new()
		"red_ink":
			return OwnerStampEffect.new()
		"the_informant", "peek":
			return InfoMarkerEffect.new()
	return _build_starter(modifier_id)


## The Cadres ADR 0021 adds.
static func _build_starter(modifier_id: String) -> ModifierEffect:
	match modifier_id:
		"rehabilitation":
			return RehabilitationEffect.new()
		"class_label":
			return ClassLabelEffect.new()
		"collective_farm":
			return CollectiveFarmEffect.new()
		"show_trial":
			return ShowTrialEffect.new()
		"model_commune":
			return ModelCommuneEffect.new()
		"ration_coupon":
			return RationCouponEffect.new()
		"shock_brigade":
			return ShockBrigadeEffect.new()
		"canteen":
			return CanteenEffect.new()
		"red_banner":
			return RedBannerEffect.new()
		"poor_peasants_association":
			return PoorPeasantsEffect.new()
		"seed_grain":
			return SeedGrainEffect.new()
		"the_bookkeeper":
			return BookkeeperEffect.new()
		"last_sheaf":
			return LastSheafEffect.new()
		"steel_target":
			return SteelTargetEffect.new()
	return _build_debuff(modifier_id)


## The debuffs ADR 0023 adds.
static func _build_debuff(modifier_id: String) -> ModifierEffect:
	match modifier_id:
		"short_supply":
			return ShortSupplyEffect.new()
		"slogan_of_the_week":
			return SloganEffect.new()
		"levy":
			return LevyEffect.new()
		"work_point_audit":
			return AuditFacesEffect.new()
		"night_shift":
			return NightShiftEffect.new()
		"grain_tax":
			return GrainTaxEffect.new()
		"shared_kitchen":
			return SharedKitchenEffect.new()
		"confiscation":
			return ConfiscationEffect.new()
		"glass_walls":
			return GlassWallsEffect.new()
		"redistribution":
			return RedistributionEffect.new()
		"overtime":
			return OvertimeEffect.new()
		"big_character_poster":
			return LossMeterEffect.new(RunMeters.DEBUFF_DENUNCIATION)
		"hungry_winter":
			return LossMeterEffect.new(RunMeters.DEBUFF_FAMINE)
		"plot_seized":
			return PlotSeizedEffect.new()
	return null
