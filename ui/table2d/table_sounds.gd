class_name TableSounds
extends RefCounted
## Chooses the table's sound effects for each event: the event's own sound, a
## round won or lost from the player's side, a meter rising past a mark, and the
## ambience's hush when the player plays. A meter not shown as it is (ADR 0022) moves
## in silence: no sound gives it away.


## Plays the sound for event; landlord is the seat holding the land, and controller gives the run a
## meter's change is read against.
static func play(event: RunEvent, landlord: int, controller: RunController) -> void:
	if event.type != RunEvent.Type.METER_CHANGED:
		Audio.play(AudioEvents.name_for(event, landlord))
		if AudioEvents.played_by_player(event):
			Audio.ambience.hush()
		return
	var state: RunView = controller.run
	if not ShownFigures.is_true(state, event.text):
		return
	Audio.play(AudioEvents.name_for(event, landlord))
	if _rose(event, state):
		Audio.play(AudioEvents.METER_ROSE)


## A meter's events arrive in the same batch as the change, so the run's value is the
## value after it.
static func _rose(event: RunEvent, state: RunView) -> bool:
	var after: int = state.famine() if event.text == RunCorrections.FAMINE else state.denunciation()
	var marks: Array[int] = RunDefaults.METERS.bands(event.text).marks()
	return AudioEvents.meter_rose(after - event.value, after, marks)
