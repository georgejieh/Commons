extends GdUnitTestSuite
## The Campaign tray at the table (ADR 0021): it is not shown while nothing is held, shows
## only held leaflets, holds three with Courier's Bag, and its head, leaflets and buttons,
## armed or not, keep clear of the brigade notice, the seats, the trick, the hand, the
## prompt and role lines, the action bar, the ledger, the debuff strip, the Cadre board
## and where the dice bowl lands.

const SEED: int = 4242
const SCREEN: Vector2i = Vector2i(1920, 1080)

var _app: DemoApp
var _was_size: Vector2i


func before_test() -> void:
	_was_size = get_tree().root.size
	get_tree().root.size = SCREEN
	AppKit.fresh_saves(self)
	_app = AppKit.make(self)
	_app.new_run(SEED)


func after_test() -> void:
	get_tree().root.size = _was_size
	Saves.run_service().delete()


func _hold(held: Array[String]) -> void:
	var loop: RunLoop = _app.controller.run_loop()
	loop.state.inventory.consumables.assign(held)


func _drive_to(moment: int) -> bool:
	var driver: ControllerScript = ControllerScript.new()
	for _step: int in 900:
		if _app.controller.awaiting() == moment:
			return true
		if not driver.act(_app.controller):
			return false
	return false


func _open_table() -> TableScreen:
	var table: TableScreen = _app.show_screen("table", true)
	await await_idle_frame()
	await await_idle_frame()
	return table


func _campaigns(table: TableScreen) -> TableCampaigns:
	return table.campaigns


func _check_tray_clear(table: TableScreen) -> void:
	CampaignTrayLayout.check_clear(self, table, Vector2(SCREEN))


## With Courier's Bag the tray holds three, and armed, its buttons stay clear too.
func test_three_held_leaflets_and_their_buttons_stay_clear() -> void:
	var loop: RunLoop = _app.controller.run_loop()
	loop.state.reforms.append("couriers_bag")
	_hold(["model_harvest", "anonymous_letter", "grain_loan"])
	assert_bool(_drive_to(RunController.AWAIT_PLAY)).is_true()
	var table: TableScreen = await _open_table()
	var tray: CampaignTray = _campaigns(table).tray
	assert_int(tray.campaign_count()).is_equal(3)
	for slot: int in 3:
		assert_bool(tray.leaflet(slot).visible).is_true()
	_check_tray_clear(table)
	tray.arm(2)
	assert_bool(tray.use.visible).is_true()
	_check_tray_clear(table)


func test_the_tray_shows_only_what_is_held() -> void:
	assert_bool(_drive_to(RunController.AWAIT_PLAY)).is_true()
	var table: TableScreen = await _open_table()
	var tray: CampaignTray = _campaigns(table).tray
	assert_bool(tray.visible).is_false()
	_hold(["grain_loan"])
	_campaigns(table).refresh()
	assert_bool(tray.visible).is_true()
	assert_bool(tray.show_empty).is_false()
	assert_bool(tray.leaflet(0).visible).is_true()
	assert_bool(tray.leaflet(1).visible).is_false()
