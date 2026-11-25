class_name ItemText
extends RefCounted
## The rules each kind of shop item prints, with its numbers from data, for the pages
## that show items outside a run's counters: the collection, and the controller's reads.


static func cadre(definition: ModifierDef) -> String:
	var text: String = CadreText.rules(definition)
	if definition.counts_for_teammate:
		text += " " + TranslationServer.translate("modifier.counts_for_teammate")
	return text


static func campaign(definition: CampaignDef) -> String:
	return TranslationServer.translate(definition.text_key).format(definition.text_values())


static func directive(definition: DirectiveDef) -> String:
	return TranslationServer.translate(definition.text_key)


## A Reform's rules, the limits it raises included.
static func reform(definition: ReformDef) -> String:
	var values: Dictionary[String, Variant] = definition.text_values()
	var limits: ShopParams = RunPools.STORE
	values["cadre_limit"] = limits.cadre_slots + definition.parameters.get("cadres", 0)
	values["campaign_limit"] = limits.campaign_slots + definition.parameters.get("campaigns", 0)
	return TranslationServer.translate(definition.text_key).format(values)


## An envelope's rules, showing choices items.
static func envelope(definition: EnvelopeDef, choices: int) -> String:
	return TranslationServer.translate(definition.text_key).format({"choices": choices})
