class_name CardBackDef
extends Resource
## One card back design (ADR 0025, "Card designs"): a cosmetic choice in Settings that
## changes nothing about play. Its inks colour the code-drawn back on moving cards, and its
## art is the picture on the seat panels, through the art's corruption stages.

## The ID the setting names it by.
@export var id: String = ""
## The string key of its name.
@export var name_key: String = ""
## Finished runs before it can be chosen.
@export var finished_runs: int = 0
## The seat panels' picture, the base its stage variants hang from; empty until its art
## exists.
@export var art: Texture2D
## True while it waits for its art: it shows as a locked sheet, never as a choice.
@export var art_pending: bool = false
## The paper of the code-drawn back.
@export var paper: Color = Color("ecd7a2")
## The border of the code-drawn back.
@export var border: Color = Color("b02a17")
## The printed lattice of the code-drawn back.
@export var lattice: Color = Color("b02a17")
