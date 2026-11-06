extends GdUnitTestSuite
## P4.4 harness: the same Sets played with the player holding a fair Commons share and
## holding all of it. A low-cooperation teammate scores measurably less in the second.

const SEEDS: Array[int] = [4401, 4402, 4403, 4404, 4405, 4406, 4407, 4408]
const BIG: int = 1_000_000_000


## The teammate's mean round total over rounds where the player was a peasant.
func _teammate_mean(received: int) -> float:
	var total: float = 0.0
	var rounds: int = 0
	for seed_value: int in SEEDS:
		var state: RunState = RunState.new(seed_value)
		state.commons_paid = BIG
		state.commons_received = received
		var configs: Array[BotConfig] = RunScript.bots()
		for config: BotConfig in configs:
			config.cooperation = BotConfig.TABLE.cooperation[Personality.Level.LOW]
		var loop: RunLoop = RunLoop.new(state, configs)
		loop.start_set()
		RunScript.new().play_until_set_over(loop)
		var landlord: int = Seats.NONE
		for event: RunEvent in loop.events():
			if event.type == RunEvent.Type.LANDLORD_CHOSEN:
				landlord = event.seat
			elif event.type == RunEvent.Type.ROUND_SCORED and landlord > 0:
				if event.seat != 0 and event.seat != landlord:
					total += event.amount
					rounds += 1
	assert_int(rounds).is_greater(0)
	return total / rounds


func test_the_teammate_contributes_less_at_a_high_player_share() -> void:
	var fair: float = _teammate_mean(BIG / 2)
	var greedy: float = _teammate_mean(BIG)
	print("teammate mean round total: %.1f at a fair share, %.1f at a full share" % [fair, greedy])
	assert_float(greedy).is_less(fair * 0.9)
