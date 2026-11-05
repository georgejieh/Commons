class_name DreadLayers
extends Node
## Puts the board's dread on screen (P3B.12). A BoardState eases one weight per
## HorrorLayer; each frame this writes those weights, scaled by the horror-intensity
## setting, into the table's shader materials and set dressing, with no allocation.
## Brief flickers run on cooldowns and never under no-flash. It reads cached run values
## only and touches nothing the player reads: cards, counts, ranks and scores are
## drawn by other nodes it never changes.

signal flickered(kind: String)

const CONFIG: HorrorConfig = preload("res://data/horror/horror_config.tres")
## Fixed, so flickers come at the same moments for the same play; never global random.
const FLICKER_SEED: int = 9187
const NO_FLASH_BREATHE: float = 0.0
## The lamp shader's own flutter, which no-flash turns off.
const DEFAULT_BREATHE: float = 0.05

var board: BoardState = BoardState.new(CONFIG)

var _materials: Dictionary[String, ShaderMaterial] = {}
var _dressing: DreadDressing
var _seats: Array[SeatPanel] = []
## One entry per distinct material parameter.
var _param_material: Array[ShaderMaterial] = []
var _param_name: Array[StringName] = []
var _param_clean: PackedFloat32Array = []
var _param_value: PackedFloat32Array = []
## One entry per layer's effect on a parameter.
var _effect_param: PackedInt32Array = []
var _effect_layer: PackedInt32Array = []
var _effect_delta: PackedFloat32Array = []
## Per dressing piece, its weight this frame.
var _piece_ids: Array[String] = []
var _piece_weight: PackedFloat32Array = []
var _piece_layers: Array[PackedInt32Array] = []
var _flicker_wait: PackedFloat32Array = []
var _flicker_seat: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _breathe: float = DEFAULT_BREATHE


func setup(
	materials: Dictionary[String, ShaderMaterial], dressing: DreadDressing, seats: Array[SeatPanel]
) -> void:
	_materials = materials
	_dressing = dressing
	_seats = seats
	_rng.seed = FLICKER_SEED
	_bind_params()
	_bind_dressing()
	_flicker_wait.resize(CONFIG.flickers.size())
	for index: int in CONFIG.flickers.size():
		_flicker_wait[index] = _cooldown(CONFIG.flickers[index])
	apply()
	set_process(true)


func _ready() -> void:
	# Nothing to drive until setup() binds the materials.
	set_process(false)


## New targets from the run, read at a round boundary.
func refresh(state: RunState, settle_now: bool = false) -> void:
	board.set_inputs(state.famine, state.denunciation, state.landlord_seat == 0, corruption())
	if settle_now:
		board.settle()
	apply()


## Shows a board state at once, for tools and tests: meters 0 to 100.
func force(famine: int, denunciation: int, landlord: bool, stage: int = 0) -> void:
	board.set_inputs(famine, denunciation, landlord, stage)
	board.settle()
	apply()


## The hidden corruption stage. It stays 0 until the profile save holds it (ADR 0018);
## a development build can set it with --corruption-stage N to check each stage.
static func corruption() -> int:
	if not OS.is_debug_build():
		return 0
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var at: int = args.find("--corruption-stage")
	if at >= 0 and at + 1 < args.size():
		return clampi(args[at + 1].to_int(), 0, BoardState.CORRUPTION_STAGES - 1)
	return 0


## Writes the current weights into every material and piece.
func apply() -> void:
	var intensity: float = float(Settings.value("horror_intensity"))
	for index: int in _param_value.size():
		_param_value[index] = _param_clean[index]
	for index: int in _effect_param.size():
		var weight: float = board.shown(_effect_layer[index], intensity)
		_param_value[_effect_param[index]] += _effect_delta[index] * weight
	for index: int in _param_value.size():
		_param_material[index].set_shader_parameter(_param_name[index], _param_value[index])
	for index: int in _piece_ids.size():
		var weight: float = 0.0
		for layer: int in _piece_layers[index]:
			weight = maxf(weight, board.shown(layer, intensity))
		_piece_weight[index] = weight
		_dressing.show_piece(_piece_ids[index], weight)
	if _materials.has("lamp"):
		var breathe: float = NO_FLASH_BREATHE if bool(Settings.value("no_flash")) else _breathe
		_materials["lamp"].set_shader_parameter("breathe", breathe)


## Puts every parameter back to its clean value, as when leaving the table.
func clear() -> void:
	for index: int in _param_clean.size():
		_param_material[index].set_shader_parameter(_param_name[index], _param_clean[index])


## The weight a dressing piece shows this frame, for tests.
func piece_weight(piece: String) -> float:
	var index: int = _piece_ids.find(piece)
	return _piece_weight[index] if index >= 0 else 0.0


## The value written to a "target:parameter" this frame, for tests.
func param_value(key: String) -> float:
	for index: int in _param_name.size():
		if _key(index) == key:
			return _param_value[index]
	return NAN


func param_clean(key: String) -> float:
	for index: int in _param_name.size():
		if _key(index) == key:
			return _param_clean[index]
	return NAN


func _process(delta: float) -> void:
	board.step(delta)
	apply()
	tick_flickers(delta)


## Counts down each flicker and fires those that are ready and allowed.
func tick_flickers(delta: float) -> void:
	var no_flash: bool = bool(Settings.value("no_flash"))
	var intensity: float = float(Settings.value("horror_intensity"))
	for index: int in CONFIG.flickers.size():
		_flicker_wait[index] -= delta
		if _flicker_wait[index] > 0.0:
			continue
		var flicker: FlickerDef = CONFIG.flickers[index]
		_flicker_wait[index] = _cooldown(flicker)
		if no_flash or board.shown(flicker.layer, intensity) < flicker.min_weight:
			continue
		_fire(flicker)


func _fire(flicker: FlickerDef) -> void:
	match flicker.kind:
		"portrait_blink":
			if not _seats.is_empty():
				_flicker_seat = (_flicker_seat + 1) % _seats.size()
				_seats[_flicker_seat].blink(flicker.duration)
		"extra_chair":
			_dressing.flash_piece("extra_chair", flicker.duration)
	flickered.emit(flicker.kind)


func _cooldown(flicker: FlickerDef) -> float:
	return _rng.randf_range(flicker.cooldown.x, flicker.cooldown.y)


func _bind_params() -> void:
	var keys: Array[String] = []
	for layer_index: int in CONFIG.layers.size():
		var layer: HorrorLayer = CONFIG.layers[layer_index]
		for key: String in layer.shader_params:
			var target: String = key.get_slice(":", 0)
			if not _materials.has(target):
				continue
			var range_values: Vector2 = layer.shader_params[key]
			var param: int = keys.find(key)
			if param < 0:
				param = keys.size()
				keys.append(key)
				_param_material.append(_materials[target])
				_param_name.append(StringName(key.get_slice(":", 1)))
				_param_clean.append(range_values.x)
				_param_value.append(range_values.x)
			_effect_param.append(param)
			_effect_layer.append(layer_index)
			_effect_delta.append(range_values.y - range_values.x)


func _bind_dressing() -> void:
	for layer_index: int in CONFIG.layers.size():
		for piece: String in CONFIG.layers[layer_index].dressing:
			var index: int = _piece_ids.find(piece)
			if index < 0:
				index = _piece_ids.size()
				_piece_ids.append(piece)
				_piece_weight.append(0.0)
				_piece_layers.append(PackedInt32Array())
			# Packed arrays copy on read, so append to a local and store it back.
			var layers: PackedInt32Array = _piece_layers[index]
			layers.append(layer_index)
			_piece_layers[index] = layers


func _key(index: int) -> String:
	for target: String in _materials:
		if _materials[target] == _param_material[index]:
			return "%s:%s" % [target, _param_name[index]]
	return ""
