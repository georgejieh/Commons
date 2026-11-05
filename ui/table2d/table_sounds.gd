class_name TableSounds
extends RefCounted
## Chooses the table's sound effects for each event (P3C.8): the event's own sound, a
## round won or lost from the player's side, and a meter rising past a mark.

## The Famine meter's event text. The UI may not name the core code that moves meters.
const FAMINE: String = "famine"


static func play(event: RunEvent, landlord: int, controller: RunController) -> void:
	Audio.play(AudioEvents.name_for(event, landlord))
	if event.type == RunEvent.Type.METER_CHANGED and _rose(event, controller.state_copy()):
		Audio.play(AudioEvents.METER_ROSE)


## A meter's events arrive in the same batch as the change, so the run's value is the
## value after it.
static func _rose(event: RunEvent, state: RunState) -> bool:
	var after: int = state.famine if event.text == FAMINE else state.denunciation
	return AudioEvents.meter_rose(after - event.value, after, SfxPlayer.BANK.meter_marks)
