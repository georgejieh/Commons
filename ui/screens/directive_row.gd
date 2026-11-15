class_name DirectiveRow
extends VBoxContainer
## The state store's Directives (ADR 0021), beside its Cadres: each a typed state
## document with its name, one line per hand type it raises giving the Rate now and after,
## and its price. Issuing one is acted out in ink: the document is sealed "Issued", each
## Rate ticks up to its new value, and the document is filed away. Every purchase goes
## through the run controller.

## Emitted when a Directive has been paid for, so the screen can count the coupons down.
signal spent
## Emitted once an issued document has been filed away, so the screen can refresh.
signal settled

const WIDTH: float = 540.0
const NAME_SIZE: int = 26
const LINE_SIZE: int = 18
const SEAL_WIDTH: float = 170.0
## Seconds the seal sits before the Rates tick, and the document takes to leave.
const SEAL_HOLD: float = 0.42
const LEAVE_TIME: float = 0.32
const LEAVE_RISE: float = 36.0
const LEAVE_SCALE: float = 0.85
## Seconds between one Rate line starting to tick and the next.
const TICK_STAGGER: float = 0.12

var _controller: RunController
var _desk: ShopDesk
## True while an issue is acted out: no second one, and the screen holds its rerolls.
var _busy: bool = false
## The screen's own purchase in progress, which holds this row too.
var _screen_busy: Callable = Callable()
var _seal: InkSeal = InkSeal.new()


func _init() -> void:
	add_theme_constant_override("separation", 16)


func setup(controller: RunController, desk: ShopDesk, screen_busy: Callable) -> void:
	_controller = controller
	_desk = desk
	_screen_busy = screen_busy
	_seal.prepare(tr("directive.issued"), ScreenKit.RED, SEAL_WIDTH)
	# Above the documents and out of the row's layout.
	_seal.top_level = true
	_seal.z_index = 2
	add_child(_seal)


func is_busy() -> bool:
	return _busy


## The seal pressed on an issued document, for tests and playtests.
func seal() -> InkSeal:
	return _seal


## Rebuilds the documents from the counter.
func show_offers() -> void:
	for child: Node in get_children():
		if child != _seal:
			remove_child(child)
			child.queue_free()
	var stock: Array[String] = _desk.directive_stock()
	for slot: int in stock.size():
		add_child(_document(slot, stock[slot]))


func _document(slot: int, directive_id: String) -> Control:
	var sheet: VBoxContainer = ScreenKit.card(Vector2(WIDTH, 0))
	sheet.add_theme_constant_override("separation", 6)
	if directive_id.is_empty():
		var issued: Label = ScreenKit.styled(tr("directive.issued"), CommonsTheme.HEADLINE)
		issued.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		issued.add_theme_color_override("font_color", ScreenKit.RED)
		sheet.add_child(issued)
		return ScreenKit.card_panel(sheet)
	var heading: VBoxContainer = VBoxContainer.new()
	heading.add_theme_constant_override("separation", 0)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(ScreenKit.eyebrow(tr("directive.eyebrow")))
	var name: Label = ScreenKit.label(_controller.directive_name(directive_id), NAME_SIZE)
	name.add_theme_font_override("font", ScreenKit.DISPLAY_BOLD)
	name.autowrap_mode = TextServer.AUTOWRAP_OFF
	heading.add_child(name)
	var buy: Button = ScreenKit.button(
		tr("store.buy").format({"price": _desk.directive_price(slot)}), CommonsTheme.COUPON
	)
	buy.custom_minimum_size = Vector2.ZERO
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy.disabled = not _desk.can_buy_directive(slot)
	sheet.add_child(ScreenKit.row([heading, buy], 12))
	sheet.add_child(HSeparator.new())
	var lines: Array[Label] = []
	for type: int in _controller.directive_types(directive_id):
		var line: Label = ScreenKit.label(_rate_line(type), LINE_SIZE)
		line.add_theme_font_override("font", ScreenKit.TYPEWRITER)
		line.autowrap_mode = TextServer.AUTOWRAP_OFF
		sheet.add_child(line)
		lines.append(line)
	var panel: Control = ScreenKit.card_panel(sheet)
	var tip: String = (
		"%s\n%s"
		% [
			_controller.directive_name(directive_id),
			Keywords.wrapped(_controller.directive_text(directive_id)),
		]
	)
	panel.tooltip_text = tip
	buy.tooltip_text = tip
	buy.pressed.connect(_issue.bind(slot, directive_id, panel, lines))
	return panel


## "Pair: Rate 3 to 8", or the Rate alone once the type is at the top level.
func _rate_line(type: int) -> String:
	var level: int = _controller.hand_level(type)
	var rate: int = _controller.hand_rate(type, level)
	if level >= _controller.max_hand_level():
		return tr("directive.rate.top").format({"type": _type_name(type), "rate": rate})
	var next: int = _controller.hand_rate(type, level + 1)
	return tr("directive.rate").format({"type": _type_name(type), "from": rate, "to": next})


static func _type_name(type: int) -> String:
	var key: String = String(Pattern.Type.keys()[type]).to_lower()
	return TranslationServer.translate("pattern." + key)


## Issues the Directive and acts it out: sealed, each Rate ticked from what it was to what
## it is now, then filed away. Reduced motion skips to the result.
func _issue(slot: int, directive_id: String, panel: Control, lines: Array[Label]) -> void:
	if _busy or (_screen_busy.is_valid() and _screen_busy.call()):
		return
	var types: Array[int] = _controller.directive_types(directive_id)
	var before: Array[int] = []
	for type: int in types:
		before.append(_controller.hand_rate(type, _controller.hand_level(type)))
	if _controller.directive(slot) != RunController.OK:
		show_offers()
		return
	Audio.play(AudioEvents.STORE_BUY)
	spent.emit()
	if UiMotion.reduced():
		settled.emit()
		return
	_busy = true
	_seal.global_position = panel.global_position + panel.size / 2.0 - _seal.size / 2.0
	_seal.press()
	panel.pivot_offset = panel.size / 2.0
	var tween: Tween = panel.create_tween()
	tween.tween_interval(SEAL_HOLD)
	for index: int in types.size():
		var type: int = types[index]
		var after: int = _controller.hand_rate(type, _controller.hand_level(type))
		var line: Label = lines[index]
		var from: int = before[index]
		var shown: Callable = _ticked.bind(type)
		tween.tween_callback(func() -> void: UiMotion.count(line, from, after, shown))
		tween.tween_interval(TICK_STAGGER)
	tween.tween_interval(UiMotion.PRESETS.count_time)
	tween.tween_callback(_seal.hide)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "modulate:a", 0.0, LEAVE_TIME)
	tween.parallel().tween_property(panel, "position:y", panel.position.y - LEAVE_RISE, LEAVE_TIME)
	tween.parallel().tween_property(panel, "scale", Vector2.ONE * LEAVE_SCALE, LEAVE_TIME)
	tween.tween_callback(_filed)


## A Rate line while it ticks: the Rate alone, as the type now stands.
func _ticked(value: float, type: int) -> String:
	var key: String = "directive.rate.now"
	if _controller.hand_level(type) >= _controller.max_hand_level():
		key = "directive.rate.top"
	return tr(key).format({"type": _type_name(type), "rate": roundi(value)})


func _filed() -> void:
	_busy = false
	settled.emit()
