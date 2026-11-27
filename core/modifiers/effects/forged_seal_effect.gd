class_name ForgedSealEffect
extends ModifierEffect
## The holder's stamped cards add no Resentment when they score (ADR 0032). It only reads
## the play, so a preview says the same.


## Waives the Resentment the holder's stamped cards add as they score.
func play_scored(context: PlayContext) -> void:
	context.stamps_resented = false
