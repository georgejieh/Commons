class_name IndustrializationEffect
extends ReformEffect
## Industrialization (ADR 0029): bombs may hold five or more cards, for every seat, and
## each card past the fourth adds Zeal to that play. Its rule is BigBombsRule, which the
## run puts on the table each round; the comparator already ranks a bigger bomb higher.


func required_parameters() -> PackedStringArray:
	return PackedStringArray([BigBombsRule.ZEAL_PERCENT])


func rule_hooks() -> Array[String]:
	return [Hooks.BUILD_RULESET, Hooks.PLAY_SCORED]


func table_rule() -> ModifierEffect:
	var rule: BigBombsRule = BigBombsRule.new()
	rule.parameters = parameters.duplicate()
	return rule
