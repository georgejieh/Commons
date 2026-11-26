class_name TableLight
extends Resource
## The one 2D light over the table. It sits where the lamp hangs and lights only
## the table surface and the card stock, through their normal maps.

## The light's color.
@export var color: Color = Color("ffd9a0")
## The light's strength.
@export_range(0.0, 2.0) var energy: float = 0.45
## How far above the table the light sits; lower gives longer relief shadows.
@export var height: float = 140.0
## The light's place as a share of the table's size.
@export var position: Vector2 = Vector2(0.5, 0.12)
## The light's reach as a share of the table's width.
@export var reach: float = 1.1
