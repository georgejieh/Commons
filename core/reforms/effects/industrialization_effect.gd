class_name IndustrializationEffect
extends ReformEffect
## Industrialization (ADR 0029): the player's bombs may hold five or more cards, and each
## card past the fourth adds Zeal to that play. Its rule is BigBombsRule, which the run
## gives the player's seat alone each round (ADR 0039); the comparator already ranks a
## bigger bomb higher, so only the Rocket answers one.


func required_parameters() -> PackedStringArray:
	return PackedStringArray([BigBombsRule.ZEAL_PERCENT])


func rule_hooks() -> Array[String]:
	return [Hooks.BUILD_RULESET, Hooks.PLAY_SCORED]


func table_rule() -> ModifierEffect:
	var rule: BigBombsRule = BigBombsRule.new()
	rule.parameters = parameters.duplicate()
	return rule
