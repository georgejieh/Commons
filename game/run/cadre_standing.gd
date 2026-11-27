class_name CadreStanding
extends RefCounted
## Where a held Cadre stands in the run, as a view shows it (ADR 0021): one line for its
## rules text, and a short count for its card on the notice board. Both are empty for a
## Cadre that keeps no state or is not held.

## The Cadre's state in a sentence for its rules text, or empty when it keeps no state.
var line: String = ""
## The short count on the Cadre's card, or empty when it keeps no state.
var count: String = ""


## The standing of a held Cadre, read from the state its effect keeps in the memo.
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
		var given: Variant = raw["count"]
		if given is String:
			return given
		var text: String = String.num(given) if given is float else str(given)
		return "+" + text
	if raw.has("rank"):
		return TranslationServer.translate("cadre.rank_badge").format({"rank": words["rank"]})
	return ""
