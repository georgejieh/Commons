extends GdUnitTestSuite
## A data field typed by an enum loads from its .tres as the member it always held: a
## villager's tier, the demo's tiers, a Cadre's rarity, a flicker's kind and a
## Directive's hand types.


func test_each_enum_field_loads_the_member_its_file_holds() -> void:
	var deng: FamilyDef = load("res://data/villagers/families/deng.tres")
	assert_int(deng.personality.tier).is_equal(BotConfig.Tier.HARD)
	var demo: DemoParams = load("res://data/run/demo.tres")
	assert_array(demo.tiers).is_equal(
		[BotConfig.Tier.MEDIUM, BotConfig.Tier.MEDIUM, BotConfig.Tier.HARD]
	)
	var plan: ModifierDef = load("res://data/modifiers/five_year_plan.tres")
	assert_int(plan.rarity).is_equal(ModifierDef.Rarity.RARE)
	var horror: HorrorConfig = load("res://data/horror/horror_config.tres")
	var kinds: Array[FlickerDef.Kind] = []
	for flicker: FlickerDef in horror.flickers:
		kinds.append(flicker.kind)
	assert_array(kinds).contains([FlickerDef.Kind.PORTRAIT_BLINK, FlickerDef.Kind.EXTRA_CHAIR])
	assert_int(horror.flickers[1].kind).is_equal(FlickerDef.Kind.EXTRA_CHAIR)
	var brigades: DirectiveDef = load("res://data/modifiers/directives/on_combined_brigades.tres")
	assert_array(brigades.hand_types).is_equal(
		[Pattern.Type.AIRPLANE, Pattern.Type.AIRPLANE_SINGLES, Pattern.Type.AIRPLANE_PAIRS]
	)
