class_name SeatSpeech
extends Label
## A villager's last words on their sheet. A line types out in step with the villager's
## voice, and a click shows the rest at once. It keeps the room of two lines of its type,
## said or not, so the sheet never changes height; a line that would need a third is set
## smaller, down to the Standard size (ADR 0034).

## The player skipped the line typing out, so its voice should stop.
signal skipped
## The line typing out finished or was skipped.
signal finished

## The type and the lines of room it keeps: at least 54 px, times the text size's factor,
## and never less than two lines of the type really stand.
const SIZE: int = 20
const LINES: int = 2
const ROOM: Vector2 = Vector2(200, 54)

## When each character of the current line shows, and how long it has been typing.
var _reveal: PackedFloat32Array = PackedFloat32Array()
var _typed: float = 0.0


func _init() -> void:
	add_theme_font_size_override("font_size", TextSize.px(SIZE))
	add_theme_color_override("font_color", ScreenKit.INK)
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Two lines of room, said or not; _ready makes it as tall as two lines really stand.
	custom_minimum_size = Vector2(ROOM.x, ceilf(ROOM.y * TextSize.factor()))
	max_lines_visible = LINES
	visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_input)


## A line that has said nothing is not typing, and the room stands as tall as two lines
## of the type, so a line that wraps to a second never makes the sheet taller.
func _ready() -> void:
	set_process(false)
	var line: float = get_theme_font("font").get_height(TextSize.px(SIZE))
	var gaps: float = get_theme_constant("line_spacing") * (LINES - 1)
	custom_minimum_size.y = maxf(custom_minimum_size.y, ceilf(line * LINES + gaps))


func _process(delta: float) -> void:
	_typed += delta
	var shown: int = maxi(0, visible_characters)
	while shown < _reveal.size() and _reveal[shown] <= _typed:
		shown += 1
	if shown >= _reveal.size():
		_finish()
	else:
		visible_characters = shown


## Shows a line. With reveal times from the voice plan it types out, one character at
## each time; without, it shows at once.
func say(line: String, reveal: PackedFloat32Array = PackedFloat32Array()) -> void:
	text = line
	_fit(line)
	_reveal = reveal
	_typed = 0.0
	visible_characters = -1 if reveal.is_empty() else 0
	set_process(not reveal.is_empty())


## Shows the rest of a line still typing out. True if one was.
func skip() -> bool:
	if not is_typing():
		return false
	_finish()
	skipped.emit()
	return true


func is_typing() -> bool:
	return is_processing()


## Characters of the current line shown so far.
func shown_characters() -> int:
	return text.length() if visible_characters < 0 else visible_characters


## The line at the text size, smaller where it would need more lines than the room has.
func _fit(line: String) -> void:
	var font: Font = get_theme_font("font")
	var wide: float = maxf(size.x, custom_minimum_size.x)
	var fits: Callable = func(font_size: int) -> bool:
		var tall: float = (
			font.get_multiline_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, wide, font_size).y
		)
		return roundi(tall / font.get_height(font_size)) <= LINES
	add_theme_font_size_override("font_size", TextSize.fit(SIZE, SIZE, fits))


func _finish() -> void:
	visible_characters = -1
	set_process(false)
	finished.emit()


func _on_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		if skip():
			accept_event()
