class_name ArtVariant
extends Resource
## One key asset's look at each corruption stage (ADR 0018): the art itself changes
## over a profile, from near-normal propaganda at stage 0 to full cosmic horror at
## stage 9. An empty entry uses the nearest earlier stage's art, then the base.

## The asset as the game references it, such as art/backdrops/table_surface.png.
@export var base: Texture2D
## Art by corruption stage, 0 to 9.
@export var stages: Array[Texture2D] = []


## The art for a stage: that stage's, else the nearest earlier one's, else the base.
func at(stage: int) -> Texture2D:
	for index: int in range(mini(stage, stages.size() - 1), -1, -1):
		if stages[index] != null:
			return stages[index]
	return base
