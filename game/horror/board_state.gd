class_name BoardState
extends RefCounted
## The board's dread (P3B.12): turns cached meter, class and corruption values into a
## weight from 0 to 1 for each HorrorLayer, eased over a few seconds. It reads values it
## is given and owns nothing else, so it can never change a card, count, rank or score.
## Targets change only when set_inputs() is called, which the table does at round
## boundaries; step() then eases toward them with no allocation.

## The values a layer can read. Struggle is the lower meter, so it rises only when both
## are high.
const INPUTS: Array[String] = ["famine", "denunciation", "struggle", "landlord", "corruption"]
## ADR 0018: ten stages of hidden corruption, 0 to 9.
const CORRUPTION_STAGES: int = 10
const METER_MAX: float = 100.0
## The Plan's seven board states, as Famine, Denunciation and landlord (1) or not (0).
const BOARD_STATES: Dictionary[String, Vector3] = {
	"both_low": Vector3(10, 10, 0),
	"famine_mid": Vector3(55, 10, 0),
	"famine_high": Vector3(90, 10, 0),
	"denunciation_mid": Vector3(10, 55, 0),
	"denunciation_high": Vector3(10, 90, 0),
	"both_high": Vector3(90, 90, 0),
	"landlord": Vector3(10, 10, 1),
}

## The corruption stage the targets were set for, 0 to 9.
var stage: int = 0
var weights: PackedFloat32Array = []
var targets: PackedFloat32Array = []

var _config: HorrorConfig


func _init(config: HorrorConfig) -> void:
	_config = config
	weights.resize(config.layers.size())
	targets.resize(config.layers.size())


## New targets from the meters (0 to 100), the player's class and the corruption stage.
func set_inputs(famine: int, denunciation: int, landlord: bool, corruption_stage: int) -> void:
	stage = clampi(corruption_stage, 0, CORRUPTION_STAGES - 1)
	for index: int in _config.layers.size():
		var layer: HorrorLayer = _config.layers[index]
		var value: float = input_value(
			layer.input, famine, denunciation, landlord, corruption_stage
		)
		targets[index] = clampf(layer.weight_for(value), 0.0, 1.0)


## Eases every weight toward its target; a full swing takes ease_seconds.
func step(delta: float) -> void:
	var rate: float = delta / maxf(0.001, _config.ease_seconds)
	for index: int in weights.size():
		weights[index] = move_toward(weights[index], targets[index], rate)


## Jumps every weight to its target, for opening the table mid-run and for tests.
func settle() -> void:
	for index: int in weights.size():
		weights[index] = targets[index]


## The weight to show for a layer, scaled by the horror-intensity setting.
func shown(index: int, intensity: float) -> float:
	return weights[index] * clampf(intensity, 0.0, 1.0)


static func input_value(
	input: String, famine: int, denunciation: int, landlord: bool, corruption_stage: int
) -> float:
	match input:
		"famine":
			return famine / METER_MAX
		"denunciation":
			return denunciation / METER_MAX
		"struggle":
			return mini(famine, denunciation) / METER_MAX
		"landlord":
			return 1.0 if landlord else 0.0
		"corruption":
			return clampi(corruption_stage, 0, CORRUPTION_STAGES - 1) / float(CORRUPTION_STAGES - 1)
	return 0.0
