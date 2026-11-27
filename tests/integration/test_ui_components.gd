extends GdUnitTestSuite
## The component theme and interface motion: every button kind has every state, focus
## shows a ring, and motion settles where it started, or skips under reduced motion.

const KINDS: Array[String] = [
	CommonsTheme.PRIMARY, CommonsTheme.SECONDARY, CommonsTheme.COUPON, CommonsTheme.GHOST
]
const STATES: Array[String] = ["normal", "hover", "pressed", "disabled", "focus"]


func after_test() -> void:
	Settings.set_value("reduced_motion", SettingsStore.DEFAULTS.get("reduced_motion"))


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
	await TestWait.until(self, _entered.bind([piece] as Array[Control]), "the entrance to settle")
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
	await TestWait.until(self, func() -> bool: return label.text == "42", "the count to land on 42")
	Settings.set_value("reduced_motion", was)


## A page of many pieces closes its gaps up: the last piece waits its turn and is still
## in by enter_within.
func test_a_long_page_is_in_by_enter_within() -> void:
	var was: bool = bool(Settings.value("reduced_motion"))
	Settings.set_value("reduced_motion", false)
	var pieces: Array[Control] = []
	for _piece: int in 30:
		var piece: Control = auto_free(Control.new())
		add_child(piece)
		pieces.append(piece)
	UiMotion.enter(pieces)
	var presets: MotionPresets = UiMotion.PRESETS
	# Timed: the page half an entrance in is the moment looked at.
	await await_millis(int(presets.enter_time * 500.0))
	assert_float(pieces[0].modulate.a).is_greater(0.0)
	assert_float(pieces[29].modulate.a).is_equal(0.0)
	var within: float = presets.enter_within - presets.enter_time * 0.5 + 0.25
	await TestWait.until(self, _entered.bind(pieces), "the whole page to enter", within)
	Settings.set_value("reduced_motion", was)


## A page asks for its pieces' entrances before its Containers have given them a size.
## The pivot follows the size, so a piece settles about its middle and not its corner.
func test_an_entrance_settles_about_the_middle_of_a_piece_sized_later() -> void:
	var was: bool = bool(Settings.value("reduced_motion"))
	Settings.set_value("reduced_motion", false)
	var column: VBoxContainer = auto_free(VBoxContainer.new())
	column.size = Vector2(600, 400)
	var piece: Control = Control.new()
	piece.custom_minimum_size = Vector2(0, 120)
	column.add_child(piece)
	UiMotion.enter_at(piece, 0.0)
	assert_vector(piece.pivot_offset).is_equal(piece.size / 2.0)
	add_child(column)
	await await_idle_frame()
	await await_idle_frame()
	assert_float(piece.size.y).is_equal(120.0)
	assert_float(piece.size.x).is_greater(100.0)
	assert_vector(piece.pivot_offset).is_equal(piece.size / 2.0)
	piece.custom_minimum_size = Vector2(0, 200)
	await await_idle_frame()
	await await_idle_frame()
	assert_float(piece.size.y).is_equal(200.0)
	assert_vector(piece.pivot_offset).is_equal(piece.size / 2.0)
	Settings.set_value("reduced_motion", was)


## Oswald's digits differ in width, so a rolling number keeps room for its widest and
## nothing beside it moves while it rolls. With motion off the room is the same.
func test_a_rolling_number_keeps_one_width() -> void:
	var was: bool = bool(Settings.value("reduced_motion"))
	Settings.set_value("reduced_motion", false)
	var row: HBoxContainer = auto_free(HBoxContainer.new())
	add_child(row)
	var number: Label = ScreenKit.styled("", CommonsTheme.TITLE)
	var beside: Label = ScreenKit.styled("beside", CommonsTheme.TITLE)
	row.add_child(number)
	row.add_child(beside)
	var shown: Callable = func(value: float) -> String: return str(roundi(value))
	# The face does have digits of different widths, or this test proves nothing.
	var spare: float = UiMotion.widest(number, "1") - _plain_width(number, "1")
	assert_float(spare).is_greater(1.0)
	UiMotion.count(number, 111.0, 808.0, shown)
	await await_idle_frame()
	await await_idle_frame()
	var room: float = number.size.x
	var at: float = beside.position.x
	assert_float(room).is_greater_equal(UiMotion.widest(number, "808"))
	for _frame: int in 12:
		await await_idle_frame()
		assert_float(number.size.x).is_equal(room)
		assert_float(beside.position.x).is_equal(at)
	await TestWait.until(self, func() -> bool: return number.text == "808", "the roll to land")
	assert_float(beside.position.x).is_equal(at)
	# A roll down to a shorter number gives the room back when it lands.
	UiMotion.count(number, 808.0, 7.0, shown)
	var gave_back: Callable = func() -> bool:
		return number.custom_minimum_size.x == UiMotion.widest(number, "7")
	await TestWait.until(self, gave_back, "the room to come back as the roll lands")
	assert_str(number.text).is_equal("7")
	Settings.set_value("reduced_motion", true)
	var still: Label = ScreenKit.styled("", CommonsTheme.TITLE)
	row.add_child(still)
	UiMotion.count(still, 111.0, 808.0, shown)
	assert_float(still.custom_minimum_size.x).is_equal(UiMotion.widest(still, "808"))
	Settings.set_value("reduced_motion", was)


func _plain_width(label: Label, text: String) -> float:
	var font: Font = label.get_theme_font("font")
	var px: int = label.get_theme_font_size("font_size")
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x


## A control that lifts on hover keeps its scale through an entrance, which only fades
## it, and a quiet piece only fades too.
func test_an_entrance_only_fades_a_lifted_button_and_a_quiet_piece() -> void:
	var was: bool = bool(Settings.value("reduced_motion"))
	Settings.set_value("reduced_motion", false)
	var button: Button = auto_free(ScreenKit.button("Go"))
	add_child(button)
	var quiet: Control = auto_free(Control.new())
	add_child(quiet)
	button.grab_focus()
	UiMotion.enter_at(button, 0.0)
	UiMotion.enter_at(quiet, 0.0, true)
	assert_float(button.modulate.a).is_equal(0.0)
	assert_vector(quiet.scale).is_equal(Vector2.ONE)
	assert_float(button.scale.x).is_greater_equal(1.0)
	var lifted: Vector2 = Vector2.ONE * UiMotion.PRESETS.hover_scale
	var entered: Callable = func() -> bool:
		var opaque: bool = button.modulate.a >= 0.99 and quiet.modulate.a >= 0.99
		return opaque and button.scale.is_equal_approx(lifted)
	await TestWait.until(self, entered, "both to enter, the focused button lifted")
	Settings.set_value("reduced_motion", was)


## True once every piece stands at full opacity and its own size.
func _entered(pieces: Array[Control]) -> bool:
	var settled: Callable = func(piece: Control) -> bool:
		return piece.modulate.a >= 0.99 and piece.scale.distance_to(Vector2.ONE) <= 0.01
	return pieces.all(settled)
