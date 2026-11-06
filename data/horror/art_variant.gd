class_name ArtVariant
extends Resource
## One key asset's look at each corruption stage (ADR 0018): the art itself changes
## over a profile, from near-normal propaganda at stage 0 to full cosmic horror at
## stage 9. Stage art is held as file paths, so only the stage on screen is loaded and
## the rest never take texture memory. An empty entry uses the nearest earlier stage's
## art, then the base.

## The asset as the game references it, such as art/backdrops/table_surface.png.
@export var base: Texture2D
## Art files by corruption stage, 0 to 9; "" means no art of its own for that stage.
@export var stage_paths: Array[String] = []


## The file for a stage: that stage's, else the nearest earlier one's, else "" for the
## base.
func path_at(stage: int) -> String:
	for index: int in range(mini(stage, stage_paths.size() - 1), -1, -1):
		if not stage_paths[index].is_empty():
			return stage_paths[index]
	return ""


func has_path(path: String) -> bool:
	return not path.is_empty() and stage_paths.has(path)
