class_name HorrorLayer
extends Resource
## One dread layer (P3B.12): what it reads, how strongly it answers, and what it changes
## on the board. Weights run 0 to 1. Everything here is decoration: no layer can touch a
## card, count, rank or score.

## Which board input drives the layer: one of BoardState.INPUTS.
@export var input: String = ""
## Maps the input, 0 to 1, to the layer's weight, 0 to 1: points sorted by x, with
## straight lines between them.
@export var response: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(1, 1)])

## "target:parameter" to the value at weight 0 (x) and weight 1 (y). Targets are the
## table's shader materials: post, lamp, watchers, spotlight.
@export var shader_params: Dictionary[String, Vector2] = {}
## Set-dressing pieces shown at the layer's weight: chairs, poster, redaction, spotlight,
## gilt.
@export var dressing: Array[String] = []
## Music stems this layer fades (P3C.9); silent until the music exists.
@export var audio_stems: Array[String] = []


## The weight for an input from 0 to 1. No allocation.
func weight_for(value: float) -> float:
	if response.is_empty():
		return 0.0
	if value <= response[0].x:
		return response[0].y
	for index: int in range(1, response.size()):
		var right: Vector2 = response[index]
		if value <= right.x:
			var left: Vector2 = response[index - 1]
			var span: float = maxf(0.0001, right.x - left.x)
			return lerpf(left.y, right.y, (value - left.x) / span)
	return response[-1].y
