class_name LossMeterEffect
extends ModifierEffect
## Each round the holder's side loses, a meter rises by its row in the meter table, a
## full band (ADR 0023): Big-Character Poster raises Denunciation, Hungry Winter Famine.

var _source: String


func _init(meter_source: String) -> void:
	_source = meter_source


## The meter table row a lost round raises.
func source() -> String:
	return _source


func round_end(context: RoundContext) -> void:
	if context.side_lost(holder_seat):
		context.meter_sources.append(_source)
