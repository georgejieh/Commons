class_name CampaignTrayLayout
extends RefCounted
## The table's Campaign tray against everything it must keep clear of, for the tests.


## Every visible piece of the tray, its head, leaflets and buttons, keeps clear of the
## table's pieces and of where the dice bowl lands, and stays on screen.
static func check_clear(suite: GdUnitTestSuite, table: TableScreen, screen: Vector2) -> void:
	var campaigns: TableCampaigns = table.campaigns
	var tray: CampaignTray = campaigns.tray
	var ledger: Control = table.ledger
	var keep_clear: Array[Control] = [
		table.hand_view,
		table.actions,
		table.board,
		table.you,
		table.pile,
		table.debuffs,
		ledger.get_parent() as Control,
	]
	var seats: Dictionary[int, SeatPanel] = table.seats
	keep_clear.append_array(seats.values())
	var dressing: Control = table.dressing
	for child: Node in dressing.get_children():
		if (
			child is PanelContainer
			and (child as Control).position == DreadDressing.NOTICE_AT.position
		):
			keep_clear.append(child as Control)
	suite.assert_int(keep_clear.size()).is_equal(10)
	var bowl: Vector2 = TableMoments.BOWL_AT
	for piece: Node in tray.get_children():
		var shown: Control = piece as Control
		if shown == null or not shown.is_visible_in_tree():
			continue
		var area: Rect2 = shown.get_global_rect()
		suite.assert_bool(Rect2(Vector2.ZERO, screen).encloses(area)).is_true()
		var near: Vector2 = bowl.clamp(area.position, area.end)
		suite.assert_float(near.distance_to(bowl)).is_greater(DiceBowl.RADIUS)
		for control: Control in keep_clear:
			if not control.is_visible_in_tree():
				continue
			(
				suite
				. assert_bool(area.intersects(control.get_global_rect()))
				. override_failure_message(
					(
						"%s %s meets %s %s"
						% [shown.get_path(), area, control.get_path(), control.get_global_rect()]
					)
				)
				. is_false()
			)
