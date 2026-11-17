class_name SecondBook
extends RefCounted
## The second book (ADR 0022): a masked copy of the figures that matter, taken after every
## command the controller handles and after every start, load, resume and replay, and
## compared before the next. Masked means the value is never held in the clear: each
## figure is kept XORed with its own random key, drawn fresh for every book, so scanning
## memory for the figure never finds the copy. The book holds one loop as it stood: when
## the loop is another one, or its record moved on without the controller (a tool driving
## the loop directly), there is nothing to compare and the book is only sealed again.

const FIGURES: Array[String] = RunCorrections.FIGURES

var _keys: PackedInt64Array = PackedInt64Array()
var _masked: PackedInt64Array = PackedInt64Array()
var _sealed: bool = false
var _loop_id: int = 0
var _run_id: String = ""
var _commands: int = 0
var _checkpoint: Dictionary = {}


func _init() -> void:
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.randomize()
	for _figure: String in FIGURES:
		_keys.append((random.randi() << 32) ^ random.randi())
	_masked.resize(FIGURES.size())


## Copies the loop's figures, masked, as they stand now.
func seal(loop: RunLoop) -> void:
	var values: PackedInt64Array = _values(loop.state)
	for index: int in FIGURES.size():
		_masked[index] = values[index] ^ _keys[index]
	_sealed = true
	_loop_id = loop.get_instance_id()
	_run_id = loop.state.identity.id
	_commands = loop.record.commands.size()
	_checkpoint = loop.record.checkpoint


## Forgets the loop, as when the run is let go.
func clear() -> void:
	_sealed = false
	_checkpoint = {}


## True when the book holds this loop as the controller last left it: the same loop and
## run, with no command or checkpoint since.
func holds(loop: RunLoop) -> bool:
	return (
		_sealed
		and _loop_id == loop.get_instance_id()
		and _run_id == loop.state.identity.id
		and _commands == loop.record.commands.size()
		and is_same(_checkpoint, loop.record.checkpoint)
	)


## Each figure that differs from the book, by name, as the state holds it now: whole
## figures as ints, progress as a float.
func differences(state: RunState) -> Dictionary:
	var found: Dictionary = {}
	var values: PackedInt64Array = _values(state)
	for index: int in FIGURES.size():
		if (values[index] ^ _keys[index]) == _masked[index]:
			continue
		var figure: String = FIGURES[index]
		found[figure] = _figure(state, figure)
	return found


## Puts the book's figures back into the state.
func restore(state: RunState) -> void:
	for index: int in FIGURES.size():
		var value: int = _masked[index] ^ _keys[index]
		match FIGURES[index]:
			RunCorrections.COUPONS:
				state.coupons = value
			RunCorrections.PROGRESS:
				state.set_progress = _float_of(value)
			RunCorrections.FAMINE:
				state.famine = value
			RunCorrections.DENUNCIATION:
				state.denunciation = value
			RunCorrections.RESENTMENT:
				state.resentment = value
			RunCorrections.NORM:
				state.norm_steps = value


func _values(state: RunState) -> PackedInt64Array:
	var values: PackedInt64Array = PackedInt64Array()
	for figure: String in FIGURES:
		if figure == RunCorrections.PROGRESS:
			values.append(PackedFloat64Array([state.set_progress]).to_byte_array().decode_s64(0))
		else:
			values.append(int(_figure(state, figure)))
	return values


static func _figure(state: RunState, figure: String) -> Variant:
	match figure:
		RunCorrections.COUPONS:
			return state.coupons
		RunCorrections.PROGRESS:
			return state.set_progress
		RunCorrections.FAMINE:
			return state.famine
		RunCorrections.DENUNCIATION:
			return state.denunciation
		RunCorrections.RESENTMENT:
			return state.resentment
	return state.norm_steps


static func _float_of(bits: int) -> float:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(8)
	bytes.encode_s64(0, bits)
	return bytes.decode_double(0)
