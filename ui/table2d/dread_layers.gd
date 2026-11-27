class_name DreadLayers
extends Node
## Puts the board's dread on screen. A BoardState eases one weight per HorrorLayer; each
## frame this writes those weights, scaled by the horror-intensity setting, into the
## table's shader materials and set dressing, with no allocation. Brief flickers run on
## cooldowns and never under no-flash. The slow effects of Famine and Denunciation take
## their weights here too: the eyes on the card backs (BackEyes), the hand's tremble
## (HandTremble), the roster's names (WallRoster) and the slogans TableSpeech asks for. It
## reads cached run values only and touches nothing the player reads: cards, counts, ranks
## and scores are drawn by other nodes it never changes.

## Emitted when a flicker fires, with its kind.
signal flickered(kind: FlickerDef.Kind)

## The horror data the layers and the flickers come from, unless a test sets another.
const CONFIG: HorrorConfig = preload("res://data/horror/horror_config.tres")
## Fixed, so flickers come at the same moments for the same play; never global random.
const FLICKER_SEED: int = 9187
## The no-flash setting, which stops every flicker and the lamp's flutter (ADR 0035).
const NO_FLASH_SETTING: String = "no_flash"
## The lamp's flutter while no-flash is on: none.
const NO_FLASH_BREATHE: float = 0.0
## The lamp shader's own flutter, which no-flash turns off.
const DEFAULT_BREATHE: float = 0.05

## The layers in use; tests may set another before setup().
var config: HorrorConfig = CONFIG
## The board's dread, eased one weight per layer; made by setup().
var board: BoardState

## The tremble of the player's hand.
var tremble: HandTremble = null
## The shader materials the layers drive, by slot.
var materials: Dictionary[String, ShaderMaterial] = {}
## The set dressing drawn over the room.
var room_dressing: DreadDressing
var _seats: Array[SeatPanel] = []
## One entry per distinct material parameter.
var _param_material: Array[ShaderMaterial] = []
var _param_name: Array[StringName] = []
var _param_clean: PackedFloat32Array = []
var _param_value: PackedFloat32Array = []
## The value last written to each parameter, so a frame writes only what changed; NAN
## until the first write.
var _param_written: PackedFloat32Array = []
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
## Per slow effect, in DreadEffects.NAMES order, its weight this frame and its layers.
var _effect_weight: PackedFloat32Array = []
var _effect_layers: Array[PackedInt32Array] = []
var _flicker_wait: PackedFloat32Array = []
var _flicker_seat: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _breathe: float = DEFAULT_BREATHE
var _breathe_written: float = NAN
## Slot name to the TextureRect it swaps, its own texture, and the texture shown now.
var _slots: Dictionary[String, TextureRect] = {}
var _slot_clean: Dictionary[String, Texture2D] = {}


## Binds the layers to the table's shader materials, the set dressing, the seats, the art slots and
## the hand, and starts driving them.
func setup(
	slot_materials: Dictionary[String, ShaderMaterial],
	dressing: DreadDressing,
	seats: Array[SeatPanel],
	slots: Dictionary[String, TextureRect] = {},
	hand: HandView = null
) -> void:
	board = BoardState.new(config)
	tremble = null if hand == null else HandTremble.new(hand, config.effect_tuning)
	materials = slot_materials
	_slots = slots
	for slot: String in slots:
		_slot_clean[slot] = ArtStages.base_of(Lighting.diffuse(slots[slot].texture))
		slots[slot].light_mask = Lighting.MASK
		slots[slot].texture = Lighting.lit(Lighting.diffuse(slots[slot].texture))
	room_dressing = dressing
	_seats = seats
	_rng.seed = FLICKER_SEED
	_bind_params()
	_bind_dressing()
	_bind_effects()
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


## New targets from the run, read at a round boundary. landlord is the landlord's seat when
## the table knows it sooner than the state, as when a bid has just been won, else NONE.
func refresh(state: RunView, settle_now: bool = false, landlord: int = Seats.NONE) -> void:
	var seat: int = state.landlord_seat() if landlord == Seats.NONE else landlord
	var is_landlord: bool = seat == Seats.PLAYER
	# A meter not shown as it is gives the room no dread (ADR 0022).
	var famine: int = ShownFigures.board(state, RunCorrections.FAMINE, state.famine())
	var denunciation: int = ShownFigures.board(
		state, RunCorrections.DENUNCIATION, state.denunciation()
	)
	board.set_inputs(famine, denunciation, is_landlord, ArtStages.stage())
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


## Writes the current weights into every material and piece.
func apply() -> void:
	_write(DreadLayers.horror_intensity(), bool(Settings.value(NO_FLASH_SETTING)))


## Counts down each flicker and fires those that are ready and allowed.
func tick_flickers(delta: float) -> void:
	_tick(delta, DreadLayers.horror_intensity(), bool(Settings.value(NO_FLASH_SETTING)))


## The horror-intensity setting, which scales every layer.
static func horror_intensity() -> float:
	return float(Settings.value(ArtStages.INTENSITY_KEY))


## Writes the weights at intensity. A shader parameter is set only when its value changed.
func _write(intensity: float, no_flash: bool) -> void:
	for index: int in _param_value.size():
		_param_value[index] = _param_clean[index]
	for index: int in _effect_param.size():
		var weight: float = board.shown(_effect_layer[index], intensity)
		_param_value[_effect_param[index]] += _effect_delta[index] * weight
	for index: int in _param_value.size():
		var value: float = clampf(_param_value[index], _param_low[index], _param_high[index])
		_param_value[index] = value
		if value != _param_written[index]:
			_param_written[index] = value
			_param_material[index].set_shader_parameter(_param_name[index], value)
	for index: int in _piece_ids.size():
		var weight: float = 0.0
		for layer: int in _piece_layers[index]:
			weight = maxf(weight, board.shown(layer, intensity))
		_piece_weight[index] = weight
		room_dressing.show_piece(_piece_ids[index], weight)
	for index: int in _effect_layers.size():
		var weight: float = 0.0
		for layer: int in _effect_layers[index]:
			weight = maxf(weight, board.shown(layer, intensity))
		_effect_weight[index] = weight
	BackEyes.show_weight(effect_weight(DreadEffects.EYES), get_tree() if is_inside_tree() else null)
	room_dressing.roster().show_weight(effect_weight(DreadEffects.ROSTER), config.effect_tuning)
	_apply_swaps(intensity)
	Audio.music.follow(board, config.layers, intensity)
	Audio.voice.follow(board, config.layers, intensity)
	Audio.ambience.follow(board, config.layers, intensity)
	var breathe: float = NO_FLASH_BREATHE if no_flash else _breathe
	if materials.has("lamp") and breathe != _breathe_written:
		_breathe_written = breathe
		materials["lamp"].set_shader_parameter("breathe", breathe)


## Puts every parameter back to its clean value, as when leaving the table.
func clear() -> void:
	for index: int in _param_clean.size():
		_param_material[index].set_shader_parameter(_param_name[index], _param_clean[index])
		_param_written[index] = _param_clean[index]
	BackEyes.show_weight(0.0, null)
	if tremble != null:
		tremble.still()
	Audio.music.relax()
	Audio.voice.reset()
	Audio.ambience.silence()
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


## The weight a slow effect (a DreadEffects name) shows this frame, intensity included.
func effect_weight(effect: String) -> float:
	var index: int = DreadEffects.NAMES.find(effect)
	return _effect_weight[index] if index >= 0 and index < _effect_weight.size() else 0.0


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


## The value a "target:parameter" holds with no dread shown, the first of its range, or
## NAN for a key no layer has; for tests.
func param_clean(key: String) -> float:
	for index: int in _param_name.size():
		if _key(index) == key:
			return _param_clean[index]
	return NAN


func _process(delta: float) -> void:
	board.step(delta)
	var intensity: float = DreadLayers.horror_intensity()
	var no_flash: bool = bool(Settings.value(NO_FLASH_SETTING))
	_write(intensity, no_flash)
	_tick(delta, intensity, no_flash)
	if tremble != null:
		tremble.step(delta, effect_weight(DreadEffects.TREMBLE))


func _tick(delta: float, intensity: float, no_flash: bool) -> void:
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
		FlickerDef.Kind.PORTRAIT_BLINK:
			if not _seats.is_empty():
				_flicker_seat = (_flicker_seat + 1) % _seats.size()
				_seats[_flicker_seat].blink(flicker.duration)
		FlickerDef.Kind.EXTRA_CHAIR:
			room_dressing.flash_piece("extra_chair", flicker.duration)
	flickered.emit(flicker.kind)


func _cooldown(flicker: FlickerDef) -> float:
	return _rng.randf_range(flicker.cooldown.x, flicker.cooldown.y)


func _bind_params() -> void:
	var keys: Array[String] = []
	for layer_index: int in config.layers.size():
		var layer: HorrorLayer = config.layers[layer_index]
		for key: String in layer.shader_params:
			var target: String = key.get_slice(":", 0)
			if not materials.has(target):
				continue
			var range_values: Vector2 = layer.shader_params[key]
			var param: int = keys.find(key)
			if param < 0:
				param = keys.size()
				keys.append(key)
				_param_material.append(materials[target])
				_param_name.append(StringName(key.get_slice(":", 1)))
				_param_clean.append(range_values.x)
				_param_value.append(range_values.x)
				_param_written.append(NAN)
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


func _bind_effects() -> void:
	_effect_weight.resize(DreadEffects.NAMES.size())
	_effect_layers.resize(DreadEffects.NAMES.size())
	for index: int in DreadEffects.NAMES.size():
		var layers: PackedInt32Array = PackedInt32Array()
		for layer_index: int in config.layers.size():
			if config.layers[layer_index].effects.has(DreadEffects.NAMES[index]):
				layers.append(layer_index)
		_effect_layers[index] = layers


func _key(index: int) -> String:
	for target: String in materials:
		if materials[target] == _param_material[index]:
			return "%s:%s" % [target, _param_name[index]]
	return ""


## Picks the music cue for the board at a round boundary: the Famine layer's target,
## scaled by horror intensity, and the landlord seat.
func _choose_music(landlord: bool) -> void:
	var famine: float = 0.0
	for index: int in config.layers.size():
		if config.layers[index].input == RunCorrections.FAMINE:
			famine = maxf(famine, board.targets[index])
	famine *= DreadLayers.horror_intensity()
	Audio.music.request(MusicPlayer.SCORE.cue_for(famine, landlord))
