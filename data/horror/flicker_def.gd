class_name FlickerDef
extends Resource
## A brief flicker on the board, such as a portrait blinking or a chair that
## was not there. It fires only while its layer is past min_weight, then waits a
## cooldown before it can fire again. The no-flash setting turns every flicker off.

## What flickers: "portrait_blink" blinks a villager's portrait, "extra_chair" flashes a
## chair that was not there.
@export var kind: String = ""
## Index of the layer in HorrorConfig.layers that gates it.
@export var layer: int = 0
## The layer's weight, from 0 to 1, it must be past for the flicker to fire.
@export var min_weight: float = 0.5
## Seconds between flickers: a random value from x to y.
@export var cooldown: Vector2 = Vector2(20.0, 40.0)
## Seconds the flicker lasts.
@export var duration: float = 0.12
