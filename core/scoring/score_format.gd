class_name ScoreFormat
extends RefCounted
## Short-scale display: 1,250 becomes 1.3K. Suffixes come from the string table under
## SUFFIX_KEYS, so the caller passes them in. Past the last suffix it uses an exponent.

const SUFFIX_KEYS: PackedStringArray = [
	"score.suffix.thousand",
	"score.suffix.million",
	"score.suffix.billion",
	"score.suffix.trillion",
]
const SCALE: float = 1000.0
const SHOWN_DECIMALS: float = 0.1


## Returns the number with the suffix for its scale, keeping the number below 1000.
static func short(value: float, suffixes: PackedStringArray) -> String:
	var clamped: float = Scorer.clamp_score(value)
	var sign_text: String = "-" if clamped < 0.0 else ""
	var scaled: float = absf(clamped)
	if scaled < SCALE:
		return sign_text + str(int(scaled))
	var step: int = 0
	while scaled >= SCALE and step < suffixes.size():
		scaled /= SCALE
		step += 1
	if snappedf(scaled, SHOWN_DECIMALS) >= SCALE and step < suffixes.size():
		scaled /= SCALE
		step += 1
	var shown: float = snappedf(scaled, SHOWN_DECIMALS)
	if shown >= SCALE:
		return sign_text + String.num_scientific(snappedf(absf(clamped), 1.0))
	return "%s%.1f%s" % [sign_text, shown, suffixes[step - 1]]
