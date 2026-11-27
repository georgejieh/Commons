extends GdUnitTestSuite
## Wang's slip and the store's detail slip on their own (ADR 0026): where the slip
## stands beside a target on screens that give it no home, and that the store's own
## slip stays shut while the arrival runs.


## The slip keeps clear of the brigade notice at step 7's cards, with the notice, the
## hand and the cards where the table first lays them.
func test_the_slip_keeps_clear_of_the_brigade_notice() -> void:
	var cards: Rect2 = Rect2(330, 790, 330, 200)
	var hand: Rect2 = Rect2(320, 780, 690, 230)
	var notice: Rect2 = Rect2(150, 622, 280, 124)
	var extent: Vector2 = Vector2(TutorialSlip.WIDTH, 140)
	var at: Vector2 = TutorialSlip.spot(extent, cards, [hand, notice], Vector2(1920, 1080))
	var slip: Rect2 = Rect2(at, extent)
	for kept: Rect2 in [cards, hand, notice]:
		assert_bool(slip.intersects(kept)).is_false()
	# Still beside its target, not across the room.
	assert_float(slip.get_center().distance_to(cards.get_center())).is_less(700.0)


## The store's detail slip stays closed while the arrival runs, and opens again after.
func test_the_detail_slip_stays_closed_through_the_arrival() -> void:
	var slip: DetailSlip = auto_free(DetailSlip.new())
	var piece: Control = auto_free(Control.new())
	add_child(piece)
	add_child(slip)
	var running: Array[bool] = [true]
	slip.quiet = func() -> bool: return running[0]
	slip.show_for(piece, "Iron Rice Bowl", "rule")
	assert_bool(slip.visible).is_false()
	running[0] = false
	slip.show_for(piece, "Iron Rice Bowl", "rule")
	assert_bool(slip.visible).is_true()
