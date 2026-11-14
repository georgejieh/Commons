extends GdUnitTestSuite
## The component theme and interface motion: every button kind has every state, focus
## shows a ring, and motion settles where it started, or skips under reduced motion.

const KINDS: Array[String] = [
	CommonsTheme.PRIMARY, CommonsTheme.SECONDARY, CommonsTheme.COUPON, CommonsTheme.GHOST
]
const STATES: Array[String] = ["normal", "hover", "pressed", "disabled", "focus"]


func test_every_button_kind_has_every_state() -> void:
	var theme: Theme = CommonsTheme.build()
	for kind: String in KINDS:
		for state: String in STATES:
			(
				assert_bool(theme.has_stylebox(state, kind))
				. override_failure_message("%s %s" % [kind, state])
				. is_true()
			)


func test_a_pressed_button_sinks_toward_its_edge() -> void:
	var theme: Theme = CommonsTheme.build()
	var resting: StyleBoxTexture = theme.get_stylebox("normal", CommonsTheme.PRIMARY)
	var pressed: StyleBoxTexture = theme.get_stylebox("pressed", CommonsTheme.PRIMARY)
	# A ticket keeps its size when pressed: the label sinks and the stock darkens.
	assert_float(pressed.content_margin_top).is_greater(resting.content_margin_top)
	var height: float = resting.content_margin_top + resting.content_margin_bottom
	assert_float(pressed.content_margin_top + pressed.content_margin_bottom).is_equal(height)
	assert_float(pressed.modulate_color.v).is_less(resting.modulate_color.v)


func test_focus_is_a_visible_ring() -> void:
	var ring: StyleBoxFlat = CommonsTheme.build().get_stylebox("focus", CommonsTheme.PRIMARY)
	assert_bool(ring.draw_center).is_false()
	assert_int(ring.border_width_left).is_greater(0)


func test_an_entrance_settles_at_full_size_and_opacity() -> void:
	var was: bool = bool(Settings.value("reduced_motion"))
	Settings.set_value("reduced_motion", false)
	var piece: Control = auto_free(Control.new())
	add_child(piece)
	var pieces: Array[Control] = [piece]
	UiMotion.enter(pieces)
	assert_float(piece.modulate.a).is_less(1.0)
	await await_millis(int((UiMotion.PRESETS.enter_time + 0.2) * 1000.0))
	assert_float(piece.modulate.a).is_equal_approx(1.0, 0.01)
	assert_vector(piece.scale).is_equal_approx(Vector2.ONE, Vector2(0.01, 0.01))
	Settings.set_value("reduced_motion", was)


func test_reduced_motion_skips_entrances_and_stamps() -> void:
	var was: bool = bool(Settings.value("reduced_motion"))
	Settings.set_value("reduced_motion", true)
	var piece: Control = auto_free(Control.new())
	add_child(piece)
	var pieces: Array[Control] = [piece]
	UiMotion.enter(pieces)
	UiMotion.stamp(piece)
	assert_float(piece.modulate.a).is_equal(1.0)
	assert_vector(piece.scale).is_equal(Vector2.ONE)
	Settings.set_value("reduced_motion", was)


func test_a_count_lands_on_its_value() -> void:
	var was: bool = bool(Settings.value("reduced_motion"))
	Settings.set_value("reduced_motion", false)
	var label: Label = auto_free(Label.new())
	add_child(label)
	UiMotion.count(label, 0.0, 42.0, func(value: float) -> String: return str(roundi(value)))
	await await_millis(int((UiMotion.PRESETS.count_time + 0.2) * 1000.0))
	assert_str(label.text).is_equal("42")
	Settings.set_value("reduced_motion", was)
