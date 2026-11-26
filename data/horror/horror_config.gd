class_name HorrorConfig
extends Resource
## Every dread layer and flicker, how fast weights ease, and each key asset's art by
## corruption stage (ADR 0018).

## Every dread layer.
@export var layers: Array[HorrorLayer] = []
## Per key asset, its art at each corruption stage.
@export var art: Array[ArtVariant] = []
## Every flicker.
@export var flickers: Array[FlickerDef] = []
## What the slow effects' weights look like on the table.
@export var effect_tuning: DreadEffects = DreadEffects.new()
## Seconds for a weight to ease all the way from 0 to 1.
@export var ease_seconds: float = 4.0
