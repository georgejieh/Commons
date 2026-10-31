extends GdUnitTestSuite
## Every path through call and grab, plus seat persistence and deposal.


func _play(first_seat: int, actions: Array[bool]) -> Bidding:
	var bidding: Bidding = Bidding.new(first_seat)
	for claim: bool in actions:
		assert_int(bidding.act(bidding.seat_to_act(), claim)).is_equal(Bidding.Reason.OK)
	return bidding


func test_all_pass_means_a_redeal() -> void:
	var bidding: Bidding = _play(0, [false, false, false])
	assert_bool(bidding.needs_redeal()).is_true()
	assert_int(bidding.landlord()).is_equal(Seats.NONE)
	assert_int(bidding.seat_to_act()).is_equal(Seats.NONE)


func test_a_call_nobody_grabs_keeps_the_base_stake() -> void:
	var bidding: Bidding = _play(1, [true, false, false])
	assert_int(bidding.landlord()).is_equal(1)
	assert_int(bidding.stake()).is_equal(1)
	assert_int(bidding.phase()).is_equal(Bidding.Phase.DONE)
	assert_bool(bidding.needs_redeal()).is_false()


func test_one_grab_doubles_and_takes_the_seat() -> void:
	var bidding: Bidding = _play(0, [true, true, false])
	assert_int(bidding.landlord()).is_equal(1)
	assert_int(bidding.stake()).is_equal(2)


func test_two_grabs_double_twice_and_the_last_wins() -> void:
	var bidding: Bidding = _play(0, [true, true, true])
	assert_int(bidding.landlord()).is_equal(2)
	assert_int(bidding.stake()).is_equal(4)


func test_a_later_grab_alone_takes_the_seat() -> void:
	var bidding: Bidding = _play(0, [true, false, true])
	assert_int(bidding.landlord()).is_equal(2)
	assert_int(bidding.stake()).is_equal(2)


func test_a_seat_that_passed_cannot_grab() -> void:
	var bidding: Bidding = Bidding.new(0)
	bidding.act(0, false)
	bidding.act(1, true)
	assert_int(bidding.act(0, true)).is_equal(Bidding.Reason.OUT_OF_TURN)
	assert_int(bidding.seat_to_act()).is_equal(2)
	bidding.act(2, false)
	assert_int(bidding.phase()).is_equal(Bidding.Phase.DONE)
	assert_int(bidding.landlord()).is_equal(1)


func test_a_call_from_the_last_seat_ends_bidding_at_once() -> void:
	var bidding: Bidding = _play(0, [false, false, true])
	assert_int(bidding.phase()).is_equal(Bidding.Phase.DONE)
	assert_int(bidding.landlord()).is_equal(2)
	assert_int(bidding.stake()).is_equal(1)


func test_the_middle_seat_call_leaves_one_grab() -> void:
	var bidding: Bidding = _play(0, [false, true, true])
	assert_int(bidding.landlord()).is_equal(2)
	assert_int(bidding.stake()).is_equal(2)


func test_acting_out_of_turn_is_rejected() -> void:
	var bidding: Bidding = Bidding.new(0)
	assert_int(bidding.act(1, true)).is_equal(Bidding.Reason.OUT_OF_TURN)
	assert_int(bidding.seat_to_act()).is_equal(0)


func test_acting_after_the_end_is_rejected() -> void:
	var bidding: Bidding = _play(0, [false, false, false])
	assert_int(bidding.act(0, true)).is_equal(Bidding.Reason.FINISHED)


func test_a_new_seat_tracker_needs_bidding() -> void:
	assert_bool(LandlordSeat.new().needs_bidding()).is_true()


func test_the_holder_keeps_the_seat_after_a_win() -> void:
	var seat: LandlordSeat = LandlordSeat.new()
	seat.assign(2)
	seat.record_round(true)
	assert_bool(seat.needs_bidding()).is_false()
	assert_int(seat.holder()).is_equal(2)


func test_a_lost_round_deposes_the_holder() -> void:
	var seat: LandlordSeat = LandlordSeat.new()
	seat.assign(2)
	seat.record_round(false)
	assert_bool(seat.needs_bidding()).is_true()
	assert_int(seat.holder()).is_equal(Seats.NONE)
