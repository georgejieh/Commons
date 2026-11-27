class_name CadreStanding
extends RefCounted
## Where a held Cadre stands in the run, as a view shows it (ADR 0021): one line for its
## rules text, and a short count for its card on the notice board. Both are empty for a
## Cadre that keeps no state or is not held.

var line: String = ""
var count: String = ""


static func of(definition: ModifierDef, memo: CadreMemo) -> CadreStanding:
	var standing: CadreStanding = CadreStanding.new()
	var effect: ModifierEffect = EffectRegistry.create(definition, RunLoop.PLAYER, memo)
	var raw: Dictionary[String, Variant] = effect.state_values()
	if raw.is_empty():
		return standing
	var values: Dictionary[String, Variant] = definition.text_values()
	values.merge(raw, true)
	var words: Dictionary[String, Variant] = CadreText.words(values)
	standing.line = TranslationServer.translate(definition.state_key).format(words)
	standing.count = _count(raw, words)
	return standing


## A count as it reads on the card: text as it is, a number signed, a picked rank as
## its plural.
static func _count(raw: Dictionary[String, Variant], words: Dictionary[String, Variant]) -> String:
	if raw.has("count"):
		var count: Variant = raw["count"]
		if count is String:
			return count
		var text: String = String.num(count) if count is float else str(count)
		return "+" + text
	if raw.has("rank"):
		return TranslationServer.translate("cadre.rank_badge").format({"rank": words["rank"]})
	return ""
