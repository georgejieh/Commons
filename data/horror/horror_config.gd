class_name HorrorConfig
extends Resource
## Every dread layer and flicker, and how fast weights ease (P3B.12).

@export var layers: Array[HorrorLayer] = []
@export var flickers: Array[FlickerDef] = []
## Seconds for a weight to ease all the way from 0 to 1.
@export var ease_seconds: float = 4.0
