class_name RoomPreview
extends Control
## The room for a moment as one meter's high band leaves it (ADR 0026): the real board,
## its table, lamp, watchers and dressing under the dread layers, over the whole screen,
## given that meter at its high band for a few seconds with the meter's name large on a
## sheet of paper, then eased back to the true state and let go. It changes only what the
## board shows, never a meter.

signal done

const RAIL_EDGE: Color = Color("3e2a19")
const CAPTION_SIZE: int = 72
## The caption's sheet: its top edge, and the paper's margin round the name.
const CAPTION_TOP: float = 96.0
const CAPTION_PADDING: int = 28
## Seconds the board takes to come back to the true state before the room goes.
const RETURN_SECONDS: float = 0.5
const FADE_SECONDS: float = 0.25

var _surface: TextureRect = ScreenKit.cover(ScreenKit.ART.table_surface)
var _atmosphere: TableAtmosphere = TableAtmosphere.new()
var _dressing: DreadDressing = DreadDressing.new()
var _dread: DreadLayers = DreadLayers.new()
var _caption: Label = Label.new()
var _sheet: PanelContainer = PanelContainer.new()
var _meter: String = ""
var _set_up: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var rail: ColorRect = ColorRect.new()
	rail.color = RAIL_EDGE
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for backdrop: Control in [rail, _surface, _atmosphere]:
		add_child(backdrop)
		backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_dressing)
	add_child(_dread)
	_caption.theme_type_variation = CommonsTheme.HEADLINE
	_caption.add_theme_font_size_override("font_size", CAPTION_SIZE)
	_caption.add_theme_color_override("font_color", ScreenKit.INK)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sheet.add_theme_stylebox_override("panel", ScreenKit.paper_style(CAPTION_PADDING))
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.add_child(_caption)
	add_child(_sheet)
	visible = false


## Shows the room with meter at value for seconds, from the true famine and denunciation.
func play(post: ShaderMaterial, meter: String, value: int, truth: Vector2i, seconds: float) -> void:
	if not _set_up:
		_set_up = true
		var materials: Dictionary[String, ShaderMaterial] = DreadLayers.table_materials(
			post, _atmosphere, _dressing
		)
		var panels: Array[SeatPanel] = []
		var slots: Dictionary[String, TextureRect] = {"table_surface": _surface}
		_dread.setup(materials, _dressing, panels, slots)
	_meter = meter
	_caption.text = tr("meter." + meter)
	visible = true
	_place_sheet()
	modulate.a = 1.0
	var famine: int = value if meter == "famine" else truth.x
	var denunciation: int = value if meter == "denunciation" else truth.y
	_dread.set_process(true)
	_dread.force(famine, denunciation, false)
	var tween: Tween = create_tween()
	tween.tween_interval(seconds)
	tween.tween_callback(_return.bind(truth))
	tween.tween_interval(0.0 if UiMotion.reduced() else RETURN_SECONDS)
	if not UiMotion.reduced():
		tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
	tween.tween_callback(_finish)


## The meter the room shows now, or "" while it is not shown.
func meter() -> String:
	return _meter if visible else ""


func caption() -> String:
	return _caption.text


## Where the caption's sheet stands on screen, for the slip that goes under it.
func caption_rect() -> Rect2:
	return _sheet.get_global_rect()


func _place_sheet() -> void:
	_sheet.reset_size()
	var wide: float = get_viewport_rect().size.x
	_sheet.global_position = Vector2((wide - _sheet.size.x) / 2.0, CAPTION_TOP)


## The weight the board shows now for a layer, for tests.
func layer_weight(index: int) -> float:
	return _dread.board.weights[index] if _dread.board != null else 0.0


func _return(truth: Vector2i) -> void:
	_dread.board.set_inputs(truth.x, truth.y, false, ArtStages.stage())
	if UiMotion.reduced():
		_dread.board.settle()
	_dread.apply()


func _finish() -> void:
	# Stopped first, so no frame writes the board back after it is cleared.
	_dread.set_process(false)
	_dread.clear()
	visible = false
	_meter = ""
	done.emit()
