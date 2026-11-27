class_name RehabilitationEffect
extends ModifierEffect
## The holder's cards of the rank picked when it was bought beat more ranks the longer it
## is held: first_steps in the Year it is bought, and steps_per_year more for each Year
## since. A step moves the rank to just above the next rank up, and it stops below the
## jokers. Hand types still form by printed rank (ADR 0008). Held without a pick, as when
## reeducation hands it over, it uses the data's rank.

## Parameter key: the rank that climbs, used when none was picked at the purchase.
const RANK: String = "rank"
## Parameter key: the steps it climbs in the Year it is bought.
const FIRST_STEPS: String = "first_steps"
## Parameter key: the steps it climbs for each Year after.
const STEPS_PER_YEAR: String = "steps_per_year"


## Needs the rank, the first Year's steps and the steps per Year.
func required_parameters() -> PackedStringArray:
	return PackedStringArray([RANK, FIRST_STEPS, STEPS_PER_YEAR])


## The rank must be a valid rank.
func rank_parameters() -> PackedStringArray:
	return PackedStringArray([RANK])


## Moves the rank up past the next ranks, one step at a time, but never past the jokers.
func build_rank_map(context: RankMapContext) -> void:
	var rank: int = picked()
	for _step: int in steps():
		var up: int = RankShift.next_up(context.rank_map, rank)
		if up == Ranks.INVALID or RankShift.is_joker(up):
			return
		RankShift.move_above(context.rank_map, rank, up, context.step)


## The rank the player picked when buying it, or the data's rank when none was picked.
func picked() -> int:
	return memo.value(CadreMemo.RANK, parameters[RANK])


## Steps this Year, before the jokers stop them.
func steps() -> int:
	return parameters[FIRST_STEPS] + parameters[STEPS_PER_YEAR] * memo.value(CadreMemo.YEARS)


## Steps the rank can take up the printed order before it reaches the jokers.
func steps_taken() -> int:
	return mini(steps(), maxi(Ranks.TWO - picked(), 0))


## The rank and the steps it has taken, for the Cadre's state line.
func state_values() -> Dictionary[String, Variant]:
	return {"rank": picked(), "steps": steps_taken()}
