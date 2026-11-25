class_name RehabilitationEffect
extends ModifierEffect
## The holder's cards of the rank picked when it was bought beat more ranks the longer it
## is held: first_steps in the Year it is bought, and steps_per_year more for each Year
## since. A step moves the rank to just above the next rank up, and it stops below the
## jokers. Hand types still form by printed rank (ADR 0008). Held without a pick, as when
## reeducation hands it over, it uses the data's rank.

const RANK: String = "rank"
const FIRST_STEPS: String = "first_steps"
const STEPS_PER_YEAR: String = "steps_per_year"


func required_parameters() -> PackedStringArray:
	return PackedStringArray([RANK, FIRST_STEPS, STEPS_PER_YEAR])


func rank_parameters() -> PackedStringArray:
	return PackedStringArray([RANK])


func build_rank_map(context: RankMapContext) -> void:
	var rank: int = picked()
	for _step: int in steps():
		var up: int = RankShift.next_up(context.rank_map, rank)
		if up == Ranks.INVALID or RankShift.is_joker(up):
			return
		RankShift.move_above(context.rank_map, rank, up, context.step)


func picked() -> int:
	return memo.value(CadreMemo.RANK, parameters[RANK])


## Steps this Year, before the jokers stop them.
func steps() -> int:
	return parameters[FIRST_STEPS] + parameters[STEPS_PER_YEAR] * memo.value(CadreMemo.YEARS)


## Steps the rank can take up the printed order before it reaches the jokers.
func steps_taken() -> int:
	return mini(steps(), maxi(Ranks.TWO - picked(), 0))


func state_values() -> Dictionary[String, Variant]:
	return {"rank": picked(), "steps": steps_taken()}
