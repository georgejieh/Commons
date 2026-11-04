extends GdUnitTestSuite
## The hand model's Play state and reason for valid, invalid and unbeatable selections,
## and a preview score that equals what the play then scores.

const SEED: int = 3801

var _controller: RunController
var _hand: HandModel


func before_test() -> void:
	_controller = auto_free(RunController.new())
	_controller.start_run(SEED, RunScript.bots())
	_hand = HandModel.new(_controller)


func test_an_empty_selection_cannot_play() -> void:
	_to_player_play(false)
	_hand.refresh()
	assert_bool(_hand.can_play()).is_false()
	assert_str(_hand.label_key()).is_equal(HandModel.KEY_SELECT)


func test_cards_that_form_no_pattern_cannot_play() -> void:
	_to_player_play(false)
	_hand.refresh()
	var pair: Array[int] = _two_ranks_apart()
	for card_id: int in pair:
		_hand.toggle(card_id)
	assert_bool(_hand.can_play()).is_false()
	var key: String = _hand.label_key()
	assert_str(key).starts_with(HandModel.KEY_INVALID_PREFIX)
	assert_str(key).is_not_equal(HandModel.KEY_DOES_NOT_BEAT)
	assert_str(tr(key)).is_not_equal(key)
	assert_float(_hand.projected_score()).is_equal(0.0)


func test_a_pattern_that_does_not_beat_cannot_play() -> void:
	var low: int = _to_unbeatable_single()
	_hand.toggle(low)
	assert_bool(_hand.can_play()).is_false()
	assert_str(_hand.label_key()).is_equal(HandModel.KEY_DOES_NOT_BEAT)
	assert_float(_hand.projected_score()).is_greater(0.0)


func test_a_legal_selection_plays_and_scores_its_preview() -> void:
	_to_player_play(false)
	_hand.refresh()
	var move: Pattern = _controller.legal_moves()[0]
	for card_id: int in _controller.card_ids_for(move):
		_hand.toggle(card_id)
	assert_bool(_hand.can_play()).is_true()
	assert_str(_hand.label_key()).starts_with(HandModel.KEY_PATTERN_PREFIX)
	assert_str(tr(_hand.label_key())).is_not_equal(_hand.label_key())
	var preview: float = _hand.projected_score()
	var scored: Array[float] = []
	_controller.event_emitted.connect(
		func(event: RunEvent) -> void:
			if event.type == RunEvent.Type.PLAY_SCORED and event.seat == RunLoop.PLAYER:
				scored.append(event.amount)
	)
	assert_int(_controller.play(_hand.selected_ids())).is_equal(RunLoop.Reason.OK)
	assert_float(scored[0]).is_equal(preview)


func test_hints_cover_every_legal_move() -> void:
	_to_player_play(false)
	_hand.refresh()
	var hinted: Array[int] = _hand.hint_ids()
	for move: Pattern in _controller.legal_moves():
		for card_id: int in _controller.card_ids_for(move):
			assert_array(hinted).contains([card_id])


func test_selection_drops_cards_no_longer_held() -> void:
	_to_player_play(false)
	_hand.refresh()
	var move: Pattern = _controller.legal_moves()[0]
	var ids: Array[int] = _controller.card_ids_for(move)
	for card_id: int in ids:
		_hand.toggle(card_id)
	_controller.play(ids)
	_hand.refresh()
	assert_array(_hand.selected_ids()).is_empty()


## Plays the player's turns by script until the player must play, following a play when
## following is true.
func _to_player_play(following: bool) -> void:
	var script: ControllerScript = ControllerScript.new()
	for _turn: int in 400:
		if _controller.awaiting() == RunLoop.Awaiting.PLAYER_PLAY:
			var view: SeatView = _controller.seat_view()
			if (view.public.current_play != null) == following:
				return
		if not script.act(_controller):
			_controller.finish_set()
	assert_bool(false).override_failure_message("never reached the player's turn").is_true()


## Follows a single with a lower single the player holds. Returns its card ID.
func _to_unbeatable_single() -> int:
	var script: ControllerScript = ControllerScript.new()
	for _turn: int in 2000:
		_to_player_play(true)
		var current: Pattern = _controller.seat_view().public.current_play
		if current.type == Pattern.Type.SINGLE:
			for card: CardInstance in _controller.player_cards():
				if card.base_rank() < current.main_rank:
					_hand.refresh()
					return card.id()
		script.act(_controller)
	assert_bool(false).override_failure_message("never faced a beatable single").is_true()
	return -1


func _two_ranks_apart() -> Array[int]:
	var cards: Array[CardInstance] = _hand.cards()
	for other: CardInstance in cards:
		if absi(other.base_rank() - cards[0].base_rank()) >= 2:
			return [cards[0].id(), other.id()]
	return []


## A selection that no longer reads, such as cards just played, waits instead of naming
## a key the table lacks.
func test_a_stale_selection_waits() -> void:
	_to_player_play(false)
	_hand.refresh()
	var ids: Array[int] = _controller.card_ids_for(_controller.legal_moves()[0])
	for card_id: int in ids:
		_hand.toggle(card_id)
	_controller.play(ids)
	_hand.toggle(ids[0])
	_hand.toggle(ids[0])
	assert_str(_hand.label_key()).is_equal(HandModel.KEY_WAIT)
