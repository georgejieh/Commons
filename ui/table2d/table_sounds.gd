class_name TableSounds
extends RefCounted
## Chooses the table's sound effects for each event (P3C.8): the event's own sound, a
## round won or lost from the player's side, a meter rising past a mark, and the
## ambience's hush when the player plays. A meter not shown as it is (ADR 0022) moves
## in silence: no sound gives it away.

## The Famine meter's event text. The UI may not name the core code that moves meters.
const FAMINE: String = "famine"


static func play(event: RunEvent, landlord: int, controller: RunController) -> void:
	if event.type != RunEvent.Type.METER_CHANGED:
		Audio.play(AudioEvents.name_for(event, landlord))
		if AudioEvents.played_by_player(event):
			Audio.ambience.hush()
		return
	var state: RunState = controller.state_copy()
	if not ShownFigures.is_true(state, event.text):
		return
	Audio.play(AudioEvents.name_for(event, landlord))
	if _rose(event, state):
		Audio.play(AudioEvents.METER_ROSE)


## A meter's events arrive in the same batch as the change, so the run's value is the
## value after it.
static func _rose(event: RunEvent, state: RunState) -> bool:
	var after: int = state.famine if event.text == FAMINE else state.denunciation
	return AudioEvents.meter_rose(after - event.value, after, SfxPlayer.BANK.meter_marks)
