class_name DirectiveSheet
extends RefCounted
## The lines of a Directive's typed document, shared by the state store's Directive column
## and an envelope's choices (ADR 0021): each hand type it raises with its Rate now and
## after, its Rate alone while it ticks, or its Rate at the top level.

const EYEBROW: String = "directive.eyebrow"


## "Pair: Rate 3 to 8", or the Rate alone once the type is at the top level.
static func rate_line(controller: RunController, type: int) -> String:
	var level: int = controller.figures.hand_level(type)
	var rate: int = controller.figures.hand_rate(type, level)
	if level >= controller.figures.max_hand_level():
		return TranslationServer.translate("directive.rate.top").format(
			{"type": type_name(type), "rate": rate}
		)
	var next: int = controller.figures.hand_rate(type, level + 1)
	return TranslationServer.translate("directive.rate").format(
		{"type": type_name(type), "from": rate, "to": next}
	)


## A Rate line while it ticks: the Rate alone, as the type now stands.
static func ticked(controller: RunController, value: float, type: int) -> String:
	var key: String = "directive.rate.now"
	if controller.figures.hand_level(type) >= controller.figures.max_hand_level():
		key = "directive.rate.top"
	return TranslationServer.translate(key).format({"type": type_name(type), "rate": roundi(value)})


static func type_name(type: int) -> String:
	return TranslationServer.translate("pattern." + ReadingText.type_key(type as Pattern.Type))


## The Rate of each type the Directive raises, as it stands now.
static func rates(controller: RunController, directive_id: String) -> Array[int]:
	var now: Array[int] = []
	for type: int in controller.items.directive_types(directive_id):
		now.append(controller.figures.hand_rate(type, controller.figures.hand_level(type)))
	return now


## Rolls each Rate line from its old value to the type's Rate now, one after another, on
## the tween given.
static func tick(
	tween: Tween,
	controller: RunController,
	directive_id: String,
	lines: Array[Label],
	before: Array[int],
	stagger: float
) -> void:
	var types: Array[int] = controller.items.directive_types(directive_id)
	for index: int in mini(types.size(), lines.size()):
		var type: int = types[index]
		var after: int = controller.figures.hand_rate(type, controller.figures.hand_level(type))
		var line: Label = lines[index]
		var from: int = before[index]
		var shown: Callable = func(value: float) -> String: return ticked(controller, value, type)
		tween.tween_callback(func() -> void: UiMotion.count(line, from, after, shown))
		tween.tween_interval(stagger)
