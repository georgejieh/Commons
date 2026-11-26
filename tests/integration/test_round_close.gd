extends GdUnitTestSuite
## A finished round plays out and is put away before the next hand is dealt (P5.2a). The
## owner saw the next hand dealt the moment a round ended: the run deals it as soon as the
## round is settled, and the table read the player's hand from the run while the round's
## end was still being shown.

const SEED: int = 3
## Seconds the walk through a round's end may take at most.
const WAIT_SECONDS: float = 12.0

var _app: DemoApp


func before_test() -> void:
	AppKit.fresh_saves(self)
	Settings.set_value("reduced_motion", false)
	_app = AppKit.make(self)
	_app.new_run(SEED)


func after_test() -> void:
	Settings.set_value("reduced_motion", false)
	Saves.run_service().delete()


func test_closing_comes_once_between_a_rounds_end_and_the_next_deal() -> void:
	var player: EventPlayer = auto_free(EventPlayer.new())
	add_child(player)
	player.step = 0.01
	var seen: Array[String] = []
	player.closing.connect(func() -> void: seen.append("closing"))
	player.played.connect(func(event: RunEvent) -> void: seen.append(_name(event)))
	# A Set's first deal and a redeal follow no round's end, so nothing is put away.
	player.push(RunEvent.new(RunEvent.Type.DEALT, Seats.NONE, 0))
	player.push(RunEvent.new(RunEvent.Type.REDEALT))
	player.push(RunEvent.new(RunEvent.Type.DEALT, Seats.NONE, 0))
	player.push(RunEvent.wrap(RoundEvent.new(RoundEvent.Type.ROUND_ENDED, 1)))
	player.push(RunEvent.new(RunEvent.Type.SHARE_PAID, 0, 10))
	assert_bool(player.deal_waiting()).is_true()
	player.push(RunEvent.new(RunEvent.Type.DEALT, Seats.NONE, 1))
	await _until(player.is_idle)
	assert_array(seen).is_equal(
		["DEALT", "REDEALT", "DEALT", "ROUND_ENDED", "SHARE_PAID", "closing", "DEALT"]
	)
	assert_bool(player.deal_waiting()).is_false()


## The player's round-ending play leaves the fan without the next hand showing, the round's
## end stays in view for its beat, its trick is swept off, and only then is the hand dealt.
func test_the_next_hand_waits_until_the_round_is_put_away() -> void:
	var table: TableScreen = await _open_table()
	var player: EventPlayer = table.get("_player")
	var pile: TrickPile = table.get("_pile")
	var hand_view: HandView = table.get("_hand_view")
	var card: CardInstance = _app.controller.table.player_cards()[0]
	var marks: Dictionary = {}
	player.closing.connect(func() -> void: marks["closing"] = _now())
	player.played.connect(_on_played.bind(marks, hand_view, pile, card.id()))
	for event: RunEvent in _round_end(card):
		player.push(event)
	await _until(func() -> bool: return marks.has("dealt"))
	# The run already holds the next hand, but the fan never showed it before the deal.
	assert_bool(marks.get("shown_after_play", true)).is_false()
	assert_bool(marks.has("closing")).is_true()
	var read: float = UiMotion.PRESETS.round_close_steps * player.step
	var waited: float = float(marks["dealt"]) - float(marks["closing"])
	assert_float(waited).is_greater_equal(read)
	assert_int(int(marks["pile_at_deal"])).is_equal(0)
	assert_bool(marks["slip_at_deal"]).is_false()


## Reduced motion keeps every fact: the round's end is still read before the deal.
func test_reduced_motion_still_reads_the_round_before_the_deal() -> void:
	Settings.set_value("reduced_motion", true)
	var table: TableScreen = await _open_table()
	var player: EventPlayer = table.get("_player")
	var card: CardInstance = _app.controller.table.player_cards()[0]
	var marks: Dictionary = {}
	player.closing.connect(func() -> void: marks["closing"] = _now())
	player.played.connect(
		func(event: RunEvent) -> void:
			if event.type == RunEvent.Type.DEALT:
				marks["dealt"] = _now()
	)
	for event: RunEvent in _round_end(card):
		player.push(event)
	await _until(func() -> bool: return marks.has("dealt"))
	var read: float = UiMotion.PRESETS.round_close_steps * player.step
	assert_float(float(marks["dealt"]) - float(marks["closing"])).is_greater_equal(read)


func _on_played(
	event: RunEvent, marks: Dictionary, hand_view: HandView, pile: TrickPile, card_id: int
) -> void:
	if event.type == RunEvent.Type.ROUND and event.round_event.type == RoundEvent.Type.PLAYED:
		marks["shown_after_play"] = _shows(hand_view, card_id)
	elif event.type == RunEvent.Type.DEALT:
		marks["dealt"] = _now()
		var moments: TableMoments = pile.get_parent().get("_moments")
		marks["pile_at_deal"] = pile.card_count()
		marks["slip_at_deal"] = moments.slip.visible


## The player's last card, the round's end, a share paid, and the next deal, as the run
## would queue them once the round is settled.
func _round_end(card: CardInstance) -> Array[RunEvent]:
	var rank: int = card.base_rank()
	var single: Pattern = Pattern.new(Pattern.Type.SINGLE, rank, 1, 1, PackedByteArray(), rank)
	var ids: Array[int] = [card.id()]
	var play: RoundEvent = RoundEvent.new(RoundEvent.Type.PLAYED, 0, ids, single)
	play.cards = [card]
	var events: Array[RunEvent] = [
		RunEvent.wrap(play),
		RunEvent.wrap(RoundEvent.new(RoundEvent.Type.ROUND_ENDED, 0)),
		RunEvent.new(RunEvent.Type.NEED_DECLARED, 1, 10),
		RunEvent.new(RunEvent.Type.SHARE_PAID, 1, 40),
		RunEvent.new(RunEvent.Type.DEALT, Seats.NONE, 1),
	]
	return events


func _open_table() -> TableScreen:
	var table: TableScreen = _app.show_screen("table", true)
	await await_idle_frame()
	var player: EventPlayer = table.get("_player")
	await _until(player.is_idle)
	return table


## True when the fan shows this card face up.
func _shows(hand_view: HandView, card_id: int) -> bool:
	for view: CardView in hand_view.views():
		if view.card_id == card_id and view.visible and view.modulate.a > 0.0:
			return true
	return false


func _until(done: Callable) -> void:
	var waited: float = 0.0
	while not bool(done.call()) and waited < WAIT_SECONDS:
		await get_tree().process_frame
		waited += get_process_delta_time()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _name(event: RunEvent) -> String:
	if event.round_event != null:
		return RoundEvent.Type.keys()[event.round_event.type]
	return RunEvent.Type.keys()[event.type]
