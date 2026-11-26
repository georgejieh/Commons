class_name CampaignLeaflet
extends TipHost
## One held Campaign as a paper leaflet (ADR 0021): its kind on a printed band, its name
## set in dark type over the grime, aged like all village paper. Hover shows its rule. A
## leaflet that cannot be used now stays at full strength and says so in a red line at
## its foot, and its slip says why. Armed, it lifts and its edge turns gold; under the
## keyboard or gamepad cursor it carries the focus ring.

signal chosen(slot: int)

const SIZE: Vector2 = Vector2(118, 150)
## A shop's shelf has less height: its leaflets are this much smaller.
const COMPACT: float = 0.8
const NAME_SIZE: int = 19
## The smallest a name is ever set, compact or not, so it reads on a 1080 screen.
const LEAST_NAME: int = 16
## A compact leaflet's name may shrink this far to fit its longest word.
const LEAST_COMPACT_NAME: int = 13
## The name's side margins, full and compact.
const SIDE: float = 6.0
const SIDE_COMPACT: float = 4.0
const KIND_SIZE: int = 12
## The red line at a leaflet's foot, no smaller than the game's least readable size.
const STATUS_SIZE: int = 16
## A paper-coloured halo round the type, so stains never cross a letter.
const HALO: int = 4
const LIFT: float = 14.0
const RING: float = 3.0

var slot: int = -1
var campaign_id: String = ""
## Why it cannot be used now, as a refusal reason, or 0 when it can.
var reason: int = 0
var armed: bool = false
var cursor: bool = false

var _private: bool = false
var _eyebrow: Label = Label.new()
var _name: Label = Label.new()
var _compact: bool = false
var _status: Label = Label.new()


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	pivot_offset = SIZE / 2.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var margins: StyleBoxEmpty = StyleBoxEmpty.new()
	margins.content_margin_left = SIDE
	margins.content_margin_right = SIDE
	margins.content_margin_top = 18
	margins.content_margin_bottom = 10
	add_theme_stylebox_override("panel", margins)
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4)
	_eyebrow.theme_type_variation = CommonsTheme.EYEBROW
	_eyebrow.add_theme_font_size_override("font_size", TextSize.px(KIND_SIZE))
	_eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.add_theme_font_override("font", ScreenKit.DISPLAY_BOLD)
	_name.add_theme_font_size_override("font_size", TextSize.px(NAME_SIZE))
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# A fixed width, so the wrapped name never makes the leaflet grow.
	_name.custom_minimum_size = Vector2(SIZE.x - SIDE * 2.0, 0)
	_status.add_theme_font_override("font", ScreenKit.DISPLAY_BOLD)
	_status.add_theme_font_size_override("font_size", TextSize.px(STATUS_SIZE))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.text = tr("campaign.not_now")
	_status.visible = false
	for label: Label in [_eyebrow, _name, _status]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_constant_override("outline_size", HALO)
		column.add_child(label)
	add_child(column)


## Shows a Campaign: its name and kind, its rule, and why it cannot be used now when
## reason_text is not empty.
func show_campaign(
	at_slot: int, held_id: String, title: String, rule: String, private: bool
) -> void:
	slot = at_slot
	campaign_id = held_id
	_private = private
	_eyebrow.text = tr("campaign.eyebrow.private" if private else "campaign.eyebrow.collective")
	_eyebrow.text = _eyebrow.text.to_upper()
	_fit_name(title)
	var paper: Color = CampaignPaper.paper(BowlGrime.wear())
	for label: Label in [_eyebrow, _name, _status]:
		label.add_theme_color_override("font_color", ScreenKit.INK)
		label.add_theme_color_override("font_outline_color", paper)
	_status.add_theme_color_override("font_color", ScreenKit.RED)
	set_tip(title, rule)
	queue_redraw()


## Marks the leaflet with the reason it cannot be used, or clears it when reason is 0.
## It stays at full strength either way.
func set_reason(refusal: int, why: String) -> void:
	reason = refusal
	_status.visible = refusal != 0
	var rule: String = tip_rule()
	var base: String = rule.split("\n\n")[0]
	set_tip(_name.text, base if refusal == 0 else "%s\n\n%s" % [base, why])


## Sets the leaflet's size, full or compact, with its type to match.
func set_compact(on: bool) -> void:
	var extent: Vector2 = leaf_size(on)
	custom_minimum_size = extent
	# The cached minimum is the old size until it is refreshed, and size never goes below it.
	update_minimum_size()
	size = extent
	pivot_offset = extent / 2.0
	_compact = on
	_name.custom_minimum_size = Vector2(extent.x - (SIDE_COMPACT if on else SIDE) * 2.0, 0)
	_fit_name(_name.text)
	var margins: StyleBoxEmpty = get_theme_stylebox("panel") as StyleBoxEmpty
	if margins != null:
		margins.content_margin_top = 14 if on else 18
		margins.content_margin_left = SIDE_COMPACT if on else SIDE
		margins.content_margin_right = SIDE_COMPACT if on else SIDE
	queue_redraw()


## The name at its size, smaller only as far as its longest word needs to fit, so a line
## breaks only between words.
func _fit_name(title: String) -> void:
	var base: int = maxi(roundi(NAME_SIZE * (COMPACT if _compact else 1.0)), LEAST_NAME)
	var least: int = LEAST_COMPACT_NAME if _compact else LEAST_NAME
	var wide: float = _name.custom_minimum_size.x
	NameFit.apply(_name, title, wide, TextSize.px(base), TextSize.least(least))


## The name as set, for tests.
func name_label() -> Label:
	return _name


static func leaf_size(compact: bool) -> Vector2:
	return (SIZE * COMPACT).round() if compact else SIZE


func set_armed(on: bool) -> void:
	armed = on
	queue_redraw()


func set_cursor(on: bool) -> void:
	cursor = on
	queue_redraw()


## True while its red line says it cannot be used now.
func says_not_now() -> bool:
	return _status.visible


func is_private() -> bool:
	return _private


func shown_name() -> String:
	return _name.text


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		chosen.emit(slot)
		accept_event()


func _draw() -> void:
	var worn: float = BowlGrime.wear()
	CampaignPaper.leaflet(self, Rect2(Vector2.ZERO, size), _private, worn, slot + 1)
	if armed or cursor:
		var edge: Color = CampaignPaper.ink(ScreenKit.HINT, worn * 0.5)
		draw_rect(Rect2(Vector2.ZERO, size).grow(RING), edge, false, RING)
