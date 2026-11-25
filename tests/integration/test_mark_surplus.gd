extends GdUnitTestSuite
## Surplus cards through a whole Set (ADR 0041): with every deck card marked Surplus, each
## of the player's scored plays pays a coupon for each such card, at most two in a round,
## shown as a coupon step on the card that paid; a villager's plays pay nothing and show
## none.

const SEED: int = 5101
const DECK_SIZE: int = 54
const MOST: int = 2


func _surplus_loop(seed_value: int) -> RunLoop:
	var state: RunState = RunState.new(seed_value)
	for deck_id: int in DECK_SIZE:
		CardMarks.enhance(state, CardInstance.from_deck_id(deck_id), CardInstance.SURPLUS)
	var loop: RunLoop = RunLoop.new(state, RunScript.bots(), SetConfig.new())
	loop.start_set()
	return loop


## The coupons a play's steps paid. They come after every step of the score.
func _coupon_steps(event: RunEvent) -> int:
	var count: int = 0
	for step: ScoreStep in event.steps:
		if step.figure == ScoreStep.Figure.COUPONS:
			assert_str(step.source_id).is_equal(CardInstance.SURPLUS)
			assert_int(step.card_id).is_greater_equal(0)
			count += int(step.value)
		else:
			assert_int(count).is_zero()
	return count


func test_the_player_is_paid_up_to_two_a_round_and_villagers_nothing() -> void:
	var loop: RunLoop = _surplus_loop(SEED)
	var script: RunScript = RunScript.new()
	var paid_by_round: Dictionary[int, int] = {}
	var round_index: int = -1
	var seen: int = 0
	var player_plays: int = 0
	for _step: int in 2000:
		if loop.awaiting() == RunLoop.Awaiting.SET_OVER:
			break
		var events: Array[RunEvent] = loop.events()
		for index: int in range(seen, events.size()):
			var event: RunEvent = events[index]
			if event.type == RunEvent.Type.DEALT:
				round_index += 1
			if event.type != RunEvent.Type.PLAY_SCORED:
				continue
			var coupons: int = _coupon_steps(event)
			if event.seat == RunLoop.PLAYER:
				player_plays += 1
				paid_by_round[round_index] = paid_by_round.get(round_index, 0) + coupons
			else:
				assert_int(coupons).is_zero()
		seen = events.size()
		if not script.act(loop):
			break
	assert_int(player_plays).is_greater(0)
	assert_bool(paid_by_round.is_empty()).is_false()
	for each: int in paid_by_round:
		assert_int(paid_by_round[each]).is_between(1, MOST)
