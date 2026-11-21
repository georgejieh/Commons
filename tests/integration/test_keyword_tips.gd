extends GdUnitTestSuite
## Keywords explain themselves on slips the pointer can move onto (KeywordTips): a slip
## outlives the pointer leaving its word, a word inside a slip opens the next slip, and
## no slip links to its own keyword or to one already open under it.

const FAR: Vector2 = Vector2(-500, -500)

var _text: KeywordText
var _tips: KeywordTips


func before_test() -> void:
	Settings.set_value("reduced_motion", true)
	_text = auto_free(KeywordText.new())
	_text.custom_minimum_size = Vector2(500, 0)
	add_child(_text)
	_text.position = Vector2(200, 200)
	_text.set_rule("Your plays gain 1 Zeal.")
	_tips = KeywordTips.of(self)
	# The test moves time and the pointer by hand.
	_tips.process_mode = Node.PROCESS_MODE_DISABLED


func after_test() -> void:
	_tips.tick(10.0, FAR)
	_tips.tick(10.0, FAR)
	Settings.set_value("reduced_motion", false)


## Rests the pointer on a word of text for long enough to open its slip, and stands it.
func _hover(text: KeywordText, id: String, at: Vector2) -> KeywordSlip:
	text.meta_hover_started.emit(id)
	_tips.tick(KeywordTips.DELAY + 0.01, at)
	await await_idle_frame()
	await await_idle_frame()
	_tips.tick(0.01, at)
	return _tips.slips().back()


func test_a_keyword_is_a_link_and_skips_what_it_is_told_to() -> void:
	var marked: String = Keywords.mark("Grain and Zeal.")
	assert_str(marked).contains("[url=grain]").contains("[url=zeal]")
	var skipped: String = Keywords.mark("Grain and Zeal.", ["grain"])
	assert_str(skipped).not_contains("[url=grain]").contains("Grain").contains("[url=zeal]")


func test_a_word_left_before_the_delay_opens_nothing() -> void:
	_text.meta_hover_started.emit("zeal")
	_tips.tick(KeywordTips.DELAY * 0.5, Vector2(300, 210))
	_text.meta_hover_ended.emit("zeal")
	_tips.tick(1.0, FAR)
	assert_array(_tips.slips()).is_empty()


func test_the_slip_stays_while_the_pointer_crosses_onto_it() -> void:
	var at: Vector2 = Vector2(300, 210)
	var slip: KeywordSlip = await _hover(_text, "zeal", at)
	assert_bool(slip.placed).is_true()
	assert_bool(get_tree().root.get_visible_rect().encloses(slip.get_global_rect())).is_true()
	assert_bool(slip.get_global_rect().has_point(at)).is_false()
	# The pointer leaves the word and is between word and slip for less than the grace.
	_text.meta_hover_ended.emit("zeal")
	_tips.tick(KeywordTips.GRACE * 0.6, at + Vector2(4, 8))
	assert_int(_tips.slips().size()).is_equal(1)
	# On the slip it stays for as long as the pointer does.
	var on_slip: Vector2 = slip.get_global_rect().get_center()
	for step: int in 20:
		_tips.tick(0.2, on_slip)
	assert_int(_tips.slips().size()).is_equal(1)
	# Away from both, it closes after the grace and not before.
	_tips.tick(KeywordTips.GRACE * 0.5, FAR)
	assert_int(_tips.slips().size()).is_equal(1)
	_tips.tick(KeywordTips.GRACE, FAR)
	assert_array(_tips.slips()).is_empty()


func test_a_word_inside_a_slip_opens_the_next_and_neither_links_back() -> void:
	var zeal: KeywordSlip = await _hover(_text, "zeal", Vector2(300, 210))
	assert_str(zeal.rule_text()).not_contains("[url=zeal]").contains("[url=grain]")
	_text.meta_hover_ended.emit("zeal")
	var on_zeal: Vector2 = zeal.get_global_rect().get_center()
	_tips.tick(0.05, on_zeal)
	var grain: KeywordSlip = await _hover(zeal.rule(), "grain", on_zeal)
	assert_int(_tips.slips().size()).is_equal(2)
	assert_str(grain.id).is_equal("grain")
	assert_str(grain.rule_text()).not_contains("[url=grain]").not_contains("[url=zeal]")
	# On the inner slip both stay; back on the outer one only the inner closes.
	zeal.rule().meta_hover_ended.emit("grain")
	var on_grain: Vector2 = grain.get_global_rect().get_center()
	for step: int in 10:
		_tips.tick(0.2, on_grain)
	assert_int(_tips.slips().size()).is_equal(2)
	var only_zeal: Vector2 = Vector2.ZERO
	var zeal_rect: Rect2 = zeal.get_global_rect()
	for corner: Vector2 in [zeal_rect.position, zeal_rect.end]:
		if not grain.get_global_rect().grow(KeywordTips.REACH).has_point(corner):
			only_zeal = corner.move_toward(zeal_rect.get_center(), 4.0)
	assert_vector(only_zeal).is_not_equal(Vector2.ZERO)
	_tips.tick(KeywordTips.GRACE + 0.05, only_zeal)
	assert_int(_tips.slips().size()).is_equal(1)
	assert_str(_tips.slips()[0].id).is_equal("zeal")


func test_no_keyword_links_to_itself_in_its_own_meaning() -> void:
	for id: String in Keywords.TERMS:
		var slip: KeywordSlip = auto_free(KeywordSlip.new())
		slip.explain(id, [id])
		assert_str(slip.rule_text()).override_failure_message(id).not_contains("[url=%s]" % id)
		assert_str(slip.rule_text()).override_failure_message(id).not_contains("[hint")


func test_a_slip_closes_when_its_text_goes() -> void:
	await _hover(_text, "zeal", Vector2(300, 210))
	assert_int(_tips.slips().size()).is_equal(1)
	_text.visible = false
	_tips.tick(0.01, Vector2(300, 210))
	assert_array(_tips.slips()).is_empty()


## The engine itself reports the pointer on a marked word: mouse motion over the text,
## not a signal sent by hand, asks for the slip. The text finds the word under the
## pointer from where the engine says the mouse is, so the motion goes in through Input,
## in the window's own pixels.
func test_real_pointer_motion_over_a_word_asks_for_its_slip() -> void:
	_text.set_rule("Zeal Zeal Zeal Zeal Zeal Zeal Zeal Zeal Zeal Zeal Zeal Zeal Zeal Zeal Zeal")
	await await_idle_frame()
	await await_idle_frame()
	var asked: Array[String] = []
	_text.meta_hover_started.connect(func(meta: Variant) -> void: asked.append(str(meta)))
	var area: Rect2 = _text.get_global_rect()
	for step: int in 12:
		var move: InputEventMouseMotion = InputEventMouseMotion.new()
		var at: Vector2 = area.position + Vector2(20.0 + step * 30.0, 12.0)
		move.position = get_tree().root.get_final_transform() * at
		move.global_position = move.position
		Input.parse_input_event(move)
		Input.flush_buffered_events()
		await await_idle_frame()
	assert_array(asked).contains(["zeal"])
