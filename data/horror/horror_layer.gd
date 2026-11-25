class_name HorrorLayer
extends Resource
## One dread layer (P3B.12): what it reads, how strongly it answers, and what it changes
## on the board. Weights run 0 to 1. Everything here is decoration: no layer can touch a
## card, count, rank or score.

## A layer's texture swaps show once its weight reaches this.
const SWAP_AT: float = 0.5

## Which board input drives the layer: one of BoardState.INPUTS.
@export var input: String = ""
## Maps the input, 0 to 1, to the layer's weight, 0 to 1: points sorted by x, with
## straight lines between them.
@export var response: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(1, 1)])
## A second input whose answer multiplies the weight, or empty for none: a layer the
## corruption stage gates shows nothing on a clean profile, however high its meter.
@export var gate: String = ""
## Maps the gate's input, 0 to 1, to the share of the weight let through, as response does.
@export var gate_response: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(1, 1)])

## "target:parameter" to the value at weight 0 (x) and weight 1 (y). Targets are the
## table's shader materials: post, lamp, watchers, spotlight.
@export var shader_params: Dictionary[String, Vector2] = {}
## Set-dressing pieces shown at the layer's weight: chairs, poster, redaction, spotlight,
## gilt.
@export var dressing: Array[String] = []
## The slow effects the layer drives, by DreadEffects name: the eyes on the card backs,
## the hand's tremble, the names leaving the wall roster and speech turning to slogans.
@export var effects: Array[String] = []
## Slot name to the texture shown there once the layer's weight passes SWAP_AT. Slots
## are the table's swappable art, such as table_surface. Empty until the art pass.
@export var texture_swaps: Dictionary[String, Texture2D] = {}
## Music stems this layer fades (P3C.9); silent until the music exists.
@export var audio_stems: Array[String] = []


## The weight for an input from 0 to 1. No allocation.
func weight_for(value: float) -> float:
	return HorrorLayer.along(response, value)


## The share of the weight the gate lets through for its input from 0 to 1, or all of it
## when the layer has no gate.
func gate_for(value: float) -> float:
	return 1.0 if gate.is_empty() else HorrorLayer.along(gate_response, value)


## The value of a curve of points sorted by x at x = value, flat past either end.
static func along(points: PackedVector2Array, value: float) -> float:
	if points.is_empty():
		return 0.0
	if value <= points[0].x:
		return points[0].y
	for index: int in range(1, points.size()):
		var right: Vector2 = points[index]
		if value <= right.x:
			var left: Vector2 = points[index - 1]
			var span: float = maxf(0.0001, right.x - left.x)
			return lerpf(left.y, right.y, (value - left.x) / span)
	return points[-1].y
