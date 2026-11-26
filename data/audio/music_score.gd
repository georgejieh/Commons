class_name MusicScore
extends Resource
## Which cue plays for the board, and how the dread layers thin it. Stems thin the
## music as a layer rises; slowing and long silences need their own Famine cues, because
## muting stems can't produce them. Any layer stem name the cue doesn't have is an
## ambience bed (data/audio/ambience_score.tres), which AmbiencePlayer plays.

## Every cue.
@export var cues: Array[MusicCue] = []
## The ID of the cue that plays on a village board.
@export var village: String = "village_master"
## The ID of the cue that plays while the player holds the landlord seat.
@export var landlord: String = "landlord_master"
## The ID of the slower cue that takes over at famine_mid_at.
@export var famine_mid: String = "famine_mid"
## The ID of the slowest cue, which takes over at famine_high_at.
@export var famine_high: String = "famine_high"
## The Famine layer's weight, from 0 to 1, at which the middle cue takes over.
@export var famine_mid_at: float = 0.5
## The Famine layer's weight, from 0 to 1, at which the slowest cue takes over.
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
