extends GdUnitTestSuite
## A round that begins with no bidding says so the moment it begins (P5.2a, the owner's
## Year 2 boss Quota): the landlord who won the last round keeps the seat, and the risen
## villager starts the boss Quota as landlord. The table calls it out once a round, live,
## or once its replay is over when it opens on such a round; the swap sheet prints the
## line instead when it opens over it. A round that was bid for says nothing.

const NAMES: Dictionary[int, String] = {0: "You", 1: "Zhao", 2: "Qian"}


func _events_of(round_index: int, bids: int, landlord: int) -> Array[RunEvent]:
	var events: Array[RunEvent] = [
		RunEvent.new(RunEvent.Type.SET_STARTED, Seats.NONE, 4),
		RunEvent.new(RunEvent.Type.DEALT, Seats.NONE, round_index),
	]
	for bid: int in bids:
		events.append(RunEvent.new(RunEvent.Type.BID, bid, 1))
	events.append(RunEvent.wrap(RoundEvent.new(RoundEvent.Type.ROUND_STARTED, landlord)))
	return events


func test_a_kept_seat_and_a_risen_landlord_say_who_and_why() -> void:
	var kept: KeptSeat = KeptSeat.of(_events_of(2, 0, 2))
	assert_bool(kept.kept()).is_true()
	assert_str(kept.word()).is_equal(tr("seat.kept.word"))
	assert_str(kept.line(NAMES)).is_equal(tr("seat.kept.sub").format({"name": "Qian"}))
	assert_str(KeptSeat.of(_events_of(1, 0, 0)).line(NAMES)).is_equal(tr("seat.kept.you"))
	var risen: KeptSeat = KeptSeat.of(_events_of(0, 0, 1))
	assert_str(risen.line(NAMES)).is_equal(tr("seat.risen.sub").format({"name": "Zhao"}))
	assert_bool(KeptSeat.of(_events_of(1, 2, 1)).kept()).is_false()


## Live, the call comes with the round's start and holds the queue; a replay is quiet, and
## the call comes after it unless the swap sheet opens; a round is called once.
func test_the_table_calls_a_kept_seat_once() -> void:
	KeptSeat.said = ""
	var player: EventPlayer = auto_free(EventPlayer.new())
	var callout: Callout = Callout.new()
	add_child(callout)
	auto_free(callout)
	var call: KeptSeatCall = auto_free(KeptSeatCall.new())
	var faces: Dictionary[int, Texture2D] = {}
	call.setup(player, callout, NAMES, faces)
	for event: RunEvent in _events_of(1, 0, 2):
		player.push(event)
	player.flush()
	assert_bool(callout.is_showing()).is_false()
	call.after_replay(true)
	assert_bool(callout.is_showing()).is_false()
	assert_str(KeptSeat.said).is_equal("4:1")
	KeptSeat.said = ""
	call.after_replay(false)
	assert_bool(callout.is_showing()).is_true()
	callout.dismiss()
	call.after_replay(false)
	assert_bool(callout.is_showing()).is_false()
	# The next round, live: played one by one, the start of the round calls it.
	for event: RunEvent in _events_of(2, 0, 2).slice(1):
		player.played.emit(event)
	assert_bool(callout.is_showing()).is_true()
	assert_str(KeptSeat.said).is_equal("4:2")
