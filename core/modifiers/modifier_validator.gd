class_name ModifierValidator
extends RefCounted
## Checks one definition against the hook list, its effect script and the string table.


## Returns one entry per problem. string_keys is the table's keys, passed in because
## core does no file reading.
static func validate(
	definition: ModifierDef, string_keys: Dictionary[String, bool]
) -> PackedStringArray:
	var problems: PackedStringArray = []
	for hook: String in definition.hooks:
		if not Hooks.ALL.has(hook):
			problems.append("%s: unknown hook %s" % [definition.id, hook])
	for key: String in [definition.name_key, definition.text_key]:
		if not string_keys.has(key):
			problems.append("%s: missing string key %s" % [definition.id, key])
	if not EffectRegistry.has_effect(definition.id):
		problems.append("%s: no effect script" % definition.id)
		return problems

	var effect: ModifierEffect = EffectRegistry.create(definition, Seats.NONE)
	for parameter: String in effect.required_parameters():
		if not definition.parameters.has(parameter):
			problems.append("%s: missing parameter %s" % [definition.id, parameter])
	return problems
