class_name BigBombsRule
extends ModifierEffect
## Industrialization's rule at the table (ADR 0029, rule 6): five or more cards read as one
## rank are a bomb, for every seat, so a fifth copy from the private plot counts too, and
## each card past the fourth in a bomb adds Zeal to that play, for whoever plays it.

## Zeal each card past the fourth adds, in hundredths.
const ZEAL_PERCENT: String = "zeal_percent_per_card"
## A bomb's cards without bigger bombs.
const BOMB_CARDS: int = 4
const PERCENT: float = 100.0


func required_parameters() -> PackedStringArray:
	return PackedStringArray([ZEAL_PERCENT])


func build_ruleset(context: RulesetContext) -> void:
	context.params.five_plus_is_bomb = true


func play_scored(context: PlayContext) -> void:
	var pattern: Pattern = context.pattern
	if pattern.type != Pattern.Type.BOMB or pattern.card_count <= BOMB_CARDS:
		return
	context.add_zeal += (pattern.card_count - BOMB_CARDS) * parameters[ZEAL_PERCENT] / PERCENT
