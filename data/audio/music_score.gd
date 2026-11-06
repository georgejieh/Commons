class_name MusicScore
extends Resource
## Which cue plays for the board, and how the dread layers thin it (P3C.9). Stems thin the
## music as a layer rises; slowing and long silences need their own Famine cues, because
## muting stems can't produce them. Any layer stem name the cue doesn't have (whispers,
## clock, crowd, chatter, room_tone) is a sound effect and is left to the effects layer.

@export var cues: Array[MusicCue] = []
@export var village: String = "village_master"
@export var landlord: String = "landlord_master"
@export var famine_mid: String = "famine_mid"
@export var famine_high: String = "famine_high"
## Famine layer weights at which the slower cues take over.
@export var famine_mid_at: float = 0.5
@export var famine_high_at: float = 0.85
## Seconds a stem takes to fade fully in or out.
@export var fade_seconds: float = 3.0


func cue(cue_id: String) -> MusicCue:
	for each: MusicCue in cues:
		if each.id == cue_id:
			return each
	return null


## The cue for the board: a high meter sets how much plays, and the landlord seat sets
## the arrangement only while Famine is below mid.
func cue_for(famine_weight: float, landlord_seat: bool) -> String:
	if famine_weight >= famine_high_at:
		return famine_high
	if famine_weight >= famine_mid_at:
		return famine_mid
	return landlord if landlord_seat else village
