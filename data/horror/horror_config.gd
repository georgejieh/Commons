class_name HorrorConfig
extends Resource
## Every dread layer and flicker, how fast weights ease, and each key asset's art by
## corruption stage (P3B.12, ADR 0018).

@export var layers: Array[HorrorLayer] = []
## Per key asset, its art at each corruption stage. Empty until the art pass (P3C).
@export var art: Array[ArtVariant] = []
@export var flickers: Array[FlickerDef] = []
## Seconds for a weight to ease all the way from 0 to 1.
@export var ease_seconds: float = 4.0
