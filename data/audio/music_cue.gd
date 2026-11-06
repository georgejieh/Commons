class_name MusicCue
extends Resource
## One music cue (P3C.9): a loop made of stems that share one timeline, so the game can
## fade instruments without losing sync. A cue with no stems is silent.

@export var id: String = ""
## Stem names in the same order as stems: melody, counter, harmony, bass, percussion.
@export var stem_names: Array[String] = []
@export var stems: Array[AudioStream] = []
## Measured from the audio, not the prompt. Cue changes land on a bar line.
@export var bpm: float = 84.0
@export var beats_per_bar: int = 4
## Seconds from the start of the file to the first downbeat, measured from the audio.
## Stems keep their leading silence, so bars count from here. The loop must also start
## and end on bar lines from this point.
@export var downbeat: float = 0.0


func has_audio() -> bool:
	return not stems.is_empty()


## Seconds per bar.
func bar_seconds() -> float:
	return 60.0 / maxf(bpm, 1.0) * beats_per_bar
