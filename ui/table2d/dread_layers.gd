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

## The layers in use; tests may set another before setup().
var config: HorrorConfig = CONFIG
var board: BoardState

var _materials: Dictionary[String, ShaderMaterial] = {}
var _dressing: DreadDressing
var _seats: Array[SeatPanel] = []
## One entry per distinct material parameter.
var _param_material: Array[ShaderMaterial] = []
var _param_name: Array[StringName] = []
var _param_clean: PackedFloat32Array = []
var _param_value: PackedFloat32Array = []
## The lowest and highest value any layer asks for, so layers that push the same way
## never stack past the shader's range.
var _param_low: PackedFloat32Array = []
var _param_high: PackedFloat32Array = []
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
## Slot name to the TextureRect it swaps, its own texture, and the texture shown now.
var _slots: Dictionary[String, TextureRect] = {}
var _slot_clean: Dictionary[String, Texture2D] = {}


func setup(
	materials: Dictionary[String, ShaderMaterial],
	dressing: DreadDressing,
	seats: Array[SeatPanel],
	slots: Dictionary[String, TextureRect] = {}
) -> void:
	board = BoardState.new(config)
	_materials = materials
	_slots = slots
	for slot: String in slots:
		_slot_clean[slot] = ArtStages.base_of(Lighting.diffuse(slots[slot].texture))
		slots[slot].light_mask = Lighting.MASK
		slots[slot].texture = Lighting.lit(Lighting.diffuse(slots[slot].texture))
	_dressing = dressing
	_seats = seats
	_rng.seed = FLICKER_SEED
	_bind_params()
	_bind_dressing()
	_flicker_wait.resize(config.flickers.size())
	for index: int in config.flickers.size():
		_flicker_wait[index] = _cooldown(config.flickers[index])
	apply()
	set_process(true)


func _ready() -> void:
	# Nothing to drive until setup() binds the materials.
	set_process(false)


## The table's shader materials by the target names layers use.
static func table_materials(
	post: ShaderMaterial, atmosphere: TableAtmosphere, dressing: DreadDressing
) -> Dictionary[String, ShaderMaterial]:
	return {
		"post": post,
		"lamp": atmosphere.lamp_material(),
		"watchers": atmosphere.eyes_material(),
		"spotlight": dressing.spotlight_material,
	}


## New targets from the run, read at a round boundary. landlord overrides the state's
## seat when the table knows it sooner, as when a bid has just been won.
func refresh(state: RunState, settle_now: bool = false, landlord: Variant = null) -> void:
	var is_landlord: bool = state.landlord_seat == 0 if landlord == null else bool(landlord)
	board.set_inputs(state.famine, state.denunciation, is_landlord, corruption())
	_choose_music(is_landlord)
	if settle_now:
		board.settle()
	apply()


## Shows a board state at once, for tools and tests: meters 0 to 100.
func force(famine: int, denunciation: int, landlord: bool, stage: int = 0) -> void:
	board.set_inputs(famine, denunciation, landlord, stage)
	_choose_music(landlord)
	board.settle()
	apply()


## The hidden corruption stage (ADR 0018), from ArtStages.
static func corruption() -> int:
	return ArtStages.stage()


## Writes the current weights into every material and piece.
func apply() -> void:
	var intensity: float = float(Settings.value("horror_intensity"))
	for index: int in _param_value.size():
		_param_value[index] = _param_clean[index]
	for index: int in _effect_param.size():
		var weight: float = board.shown(_effect_layer[index], intensity)
		_param_value[_effect_param[index]] += _effect_delta[index] * weight
	for index: int in _param_value.size():
		var value: float = clampf(_param_value[index], _param_low[index], _param_high[index])
		_param_value[index] = value
		_param_material[index].set_shader_parameter(_param_name[index], value)
	for index: int in _piece_ids.size():
		var weight: float = 0.0
		for layer: int in _piece_layers[index]:
			weight = maxf(weight, board.shown(layer, intensity))
		_piece_weight[index] = weight
		_dressing.show_piece(_piece_ids[index], weight)
	_apply_swaps(intensity)
	Audio.music.follow(board, config.layers, intensity)
	Audio.voice.follow(board, config.layers.size(), intensity)
	if _materials.has("lamp"):
		var breathe: float = NO_FLASH_BREATHE if bool(Settings.value("no_flash")) else _breathe
		_materials["lamp"].set_shader_parameter("breathe", breathe)


## Puts every parameter back to its clean value, as when leaving the table.
func clear() -> void:
	for index: int in _param_clean.size():
		_param_material[index].set_shader_parameter(_param_name[index], _param_clean[index])
	Audio.music.relax()
	Audio.voice.reset()
	Audio.music.request(MusicPlayer.SCORE.village)


## Each slot shows its art for the board's corruption stage, unless a layer's swap has
## reached SWAP_AT; the last such layer wins. Assigning the same texture costs nothing.
func _apply_swaps(intensity: float) -> void:
	for slot: String in _slots:
		var shown: Texture2D = ArtStages.resolve(_slot_clean[slot], board.stage)
		for index: int in config.layers.size():
			var layer: HorrorLayer = config.layers[index]
			if (
				layer.texture_swaps.has(slot)
				and board.shown(index, intensity) >= HorrorLayer.SWAP_AT
			):
				shown = layer.texture_swaps[slot]
		if Lighting.diffuse(_slots[slot].texture) != shown:
			_slots[slot].texture = Lighting.lit(shown)


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
	for index: int in config.flickers.size():
		_flicker_wait[index] -= delta
		if _flicker_wait[index] > 0.0:
			continue
		var flicker: FlickerDef = config.flickers[index]
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
	for layer_index: int in config.layers.size():
		var layer: HorrorLayer = config.layers[layer_index]
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
				_param_low.append(range_values.x)
				_param_high.append(range_values.x)
			_param_low[param] = minf(_param_low[param], minf(range_values.x, range_values.y))
			_param_high[param] = maxf(_param_high[param], maxf(range_values.x, range_values.y))
			_effect_param.append(param)
			_effect_layer.append(layer_index)
			_effect_delta.append(range_values.y - range_values.x)


func _bind_dressing() -> void:
	for layer_index: int in config.layers.size():
		for piece: String in config.layers[layer_index].dressing:
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


## Picks the music cue for the board at a round boundary: the Famine layer's target,
## scaled by horror intensity, and the landlord seat (P3C.9).
func _choose_music(landlord: bool) -> void:
	var famine: float = 0.0
	for index: int in config.layers.size():
		if config.layers[index].input == "famine":
			famine = maxf(famine, board.targets[index])
	famine *= float(Settings.value("horror_intensity"))
	Audio.music.request(MusicPlayer.SCORE.cue_for(famine, landlord))
