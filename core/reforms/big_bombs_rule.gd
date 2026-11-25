class_name BigBombsRule
extends ModifierEffect
## Industrialization's rule (ADR 0029, rule 6): five or more cards read as one rank are a
## bomb for the holder's seat alone (ADR 0039), so a fifth copy from the private plot
## counts too, and each card past the fourth in a bomb adds Zeal to that play. Only the
## holder can play one, so the Zeal is theirs; a villager answers one with the Rocket.

## Zeal each card past the fourth adds, in hundredths.
const ZEAL_PERCENT: String = "zeal_percent_per_card"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([ZEAL_PERCENT])


func build_ruleset(context: RulesetContext) -> void:
	context.params.five_plus_is_bomb = true


func play_scored(context: PlayContext) -> void:
	var pattern: Pattern = context.pattern
	if pattern.type != Pattern.Type.BOMB or pattern.card_count <= Pattern.MIN_BOMB_WIDTH:
		return
	context.add_zeal += fraction(
		(pattern.card_count - Pattern.MIN_BOMB_WIDTH) * parameters[ZEAL_PERCENT]
	)
