class_name ScoreFormat
extends RefCounted
## Short-scale display: 1,250 becomes 1.2 with the first suffix. The suffixes come from
## the string table, so the caller passes them in.

const SCALE: float = 1000.0
const SHOWN_DECIMALS: float = 0.1


## Returns the number with the suffix for its scale, keeping below 1000.
static func short(value: float, suffixes: PackedStringArray) -> String:
	var clamped: float = Scorer.clamp_score(value)
	var scaled: float = absf(clamped)
	var step: int = 0
	while scaled >= SCALE and step < suffixes.size():
		scaled /= SCALE
		step += 1
	var sign_text: String = "-" if clamped < 0.0 else ""
	if step == 0:
		return sign_text + str(int(scaled))
	return "%s%s%s" % [sign_text, str(snappedf(scaled, SHOWN_DECIMALS)), suffixes[step - 1]]
