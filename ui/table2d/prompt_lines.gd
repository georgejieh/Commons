class_name PromptLines
extends RefCounted
## Everything the prompt over the action buttons can say, so the table can give the
## column the room its tallest prompt needs (ADR 0034, rule 6) and the tests can put the
## longest one there: in play, the selection's reading or its sum, why it cannot be
## played, the hint's pass, Night Shift's refusal and an armed Campaign's ask or refusal;
## in the bidding, the call and the grab.

## Numbers as wide as a prompt or a bid can print.
const WIDE_SCORE: float = 999999.0
const WIDE_COST: int = 99
const WIDE_PERCENT: int = 150


static func every(controller: RunController, bidding: bool) -> Array[String]:
	if bidding:
		var grab: String = TranslationServer.translate("table.grab_prompt")
		return [
			TranslationServer.translate("table.bid_prompt"),
			grab.format({"name": longest_seat_name(controller), "cost": WIDE_COST}),
		]
	var texts: Array[String] = keyed("hand.reason.")
	texts.append_array(keyed("campaign.reason."))
	for key: String in ["hand.hint.pass", "table.must_play"]:
		texts.append(TranslationServer.translate(key))
	var score: String = Strings.score(WIDE_SCORE)
	var scaled: String = TranslationServer.translate("hand.scaled")
	for type: Pattern.Type in ReadingText.hand_types():
		var named: String = DirectiveSheet.type_name(type)
		texts.append(named)
		var sum: String = TranslationServer.translate("hand.sum").format(
			{
				"type": named,
				"break": "\n",
				"grain": score,
				"rate": score,
				"zeal": score,
				"total": score
			}
		)
		texts.append(sum + " " + scaled.format({"percent": WIDE_PERCENT}))
	texts.append_array(controller.texts.every_campaign_prompt())
	return texts


## The village's longest surname, as any villager may hold the seat.
static func longest_seat_name(controller: RunController) -> String:
	var longest: String = ""
	for name: String in controller.texts.every_surname():
		longest = name if name.length() > longest.length() else longest
	return longest


## Every string of the table whose key starts with prefix.
static func keyed(prefix: String) -> Array[String]:
	var texts: Array[String] = []
	var table: Translation = TranslationServer.get_translation_object("en")
	if table == null:
		return texts
	for key: String in table.get_message_list():
		if key.begins_with(prefix):
			texts.append(TranslationServer.translate(key))
	return texts
