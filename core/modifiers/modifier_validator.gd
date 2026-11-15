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
	var is_debuff: bool = definition.kind == ModifierDef.Kind.DEBUFF
	var tier_ok: bool = definition.tier >= 1 and definition.tier <= ModifierDef.MAX_TIER
	if (is_debuff and not tier_ok) or (not is_debuff and definition.tier != 0):
		problems.append("%s: bad tier %d" % [definition.id, definition.tier])
	if not EffectRegistry.has_effect(definition.id):
		problems.append("%s: no effect script" % definition.id)
		return problems

	var effect: ModifierEffect = EffectRegistry.create(definition, Seats.NONE)
	for parameter: String in effect.required_parameters():
		if not definition.parameters.has(parameter):
			problems.append("%s: missing parameter %s" % [definition.id, parameter])
	for parameter: String in effect.rank_parameters():
		if not Ranks.is_valid(definition.parameters.get(parameter, 0)):
			problems.append("%s: bad rank in %s" % [definition.id, parameter])
	var own_methods: Array[String] = []
	var script: Script = effect.get_script()
	for method: Dictionary in script.get_script_method_list():
		own_methods.append(method["name"])
	for hook: String in definition.hooks:
		# The list repeats a method the script overrides, once per class that defines it.
		if Hooks.ALL.has(hook) and own_methods.count(hook) < 2:
			problems.append("%s: does not implement %s" % [definition.id, hook])
	problems.append_array(_cadre_problems(definition, effect, string_keys))
	return problems


## A Cadre needs an unlock tier, and one that keeps run state needs the line that says
## where it stands (ADR 0021). A Cadre that asks for a rank must have one in its data,
## for a run where none was picked.
static func _cadre_problems(
	definition: ModifierDef, effect: ModifierEffect, string_keys: Dictionary[String, bool]
) -> PackedStringArray:
	var problems: PackedStringArray = []
	if definition.kind != ModifierDef.Kind.CADRE:
		return problems
	if definition.unlock_tier < 0:
		problems.append("%s: bad unlock tier %d" % [definition.id, definition.unlock_tier])
	# State is read through the parameters, which the checks above already report.
	for parameter: String in effect.required_parameters():
		if not definition.parameters.has(parameter):
			return problems
	var keeps_state: bool = not effect.state_values().is_empty()
	if keeps_state and not string_keys.has(definition.state_key):
		problems.append("%s: missing state key %s" % [definition.id, definition.state_key])
	if not keeps_state and not definition.state_key.is_empty():
		problems.append("%s: state key without state" % definition.id)
	if definition.needs_rank and not definition.parameters.has(CadreMemo.RANK):
		problems.append("%s: needs a rank but has no rank to fall back on" % definition.id)
	return problems


## Checks a Directive (ADR 0021): its strings, a cost, an unlock tier, and a family of
## real hand types, none twice.
static func validate_directive(
	definition: DirectiveDef, string_keys: Dictionary[String, bool]
) -> PackedStringArray:
	var problems: PackedStringArray = []
	for key: String in [definition.name_key, definition.text_key]:
		if not string_keys.has(key):
			problems.append("%s: missing string key %s" % [definition.id, key])
	if definition.cost <= 0:
		problems.append("%s: bad cost %d" % [definition.id, definition.cost])
	if definition.unlock_tier < 0:
		problems.append("%s: bad unlock tier %d" % [definition.id, definition.unlock_tier])
	if definition.hand_types.is_empty():
		problems.append("%s: raises no hand type" % definition.id)
	var seen: Dictionary[int, bool] = {}
	for type: int in definition.hand_types:
		if type <= Pattern.Type.PASS or type >= Pattern.Type.size() or seen.has(type):
			problems.append("%s: bad hand type %d" % [definition.id, type])
		seen[type] = true
	return problems


## Checks a Campaign (ADR 0021): its strings, a cost, an unlock tier, a card count that
## a hand can give, an effect script and the parameters it needs.
static func validate_campaign(
	definition: CampaignDef, string_keys: Dictionary[String, bool]
) -> PackedStringArray:
	var problems: PackedStringArray = []
	for key: String in [definition.name_key, definition.text_key, definition.prompt_key]:
		if not string_keys.has(key):
			problems.append("%s: missing string key %s" % [definition.id, key])
	if definition.cost <= 0:
		problems.append("%s: bad cost %d" % [definition.id, definition.cost])
	if definition.unlock_tier < 0:
		problems.append("%s: bad unlock tier %d" % [definition.id, definition.unlock_tier])
	var counts_ok: bool = definition.min_cards >= 0 and definition.min_cards <= definition.max_cards
	if not counts_ok or definition.max_cards > Dealer.HAND_SIZE:
		problems.append("%s: bad card count" % definition.id)
	if not CampaignRegistry.has_effect(definition.id):
		problems.append("%s: no effect script" % definition.id)
		return problems
	for parameter: String in CampaignRegistry.create(definition).required_parameters():
		if not definition.parameters.has(parameter):
			problems.append("%s: missing parameter %s" % [definition.id, parameter])
	return problems


## Checks a Reform (ADR 0021): its strings, a cost, an unlock tier, an effect script and
## the parameters it needs.
static func validate_reform(
	definition: ReformDef, string_keys: Dictionary[String, bool]
) -> PackedStringArray:
	var problems: PackedStringArray = []
	for key: String in [definition.name_key, definition.text_key]:
		if not string_keys.has(key):
			problems.append("%s: missing string key %s" % [definition.id, key])
	if definition.cost <= 0:
		problems.append("%s: bad cost %d" % [definition.id, definition.cost])
	if definition.unlock_tier < 0:
		problems.append("%s: bad unlock tier %d" % [definition.id, definition.unlock_tier])
	if not ReformRegistry.has_effect(definition.id):
		problems.append("%s: no effect script" % definition.id)
		return problems
	for parameter: String in ReformRegistry.create(definition).required_parameters():
		if not definition.parameters.has(parameter):
			problems.append("%s: missing parameter %s" % [definition.id, parameter])
	return problems


## Checks an envelope kind (ADR 0021): its strings, a cost, an unlock tier, a number of
## choices, and contents of real kinds, none twice, each with a weight above 0.
static func validate_envelope(
	definition: EnvelopeDef, string_keys: Dictionary[String, bool]
) -> PackedStringArray:
	var problems: PackedStringArray = []
	for key: String in [definition.name_key, definition.text_key]:
		if not string_keys.has(key):
			problems.append("%s: missing string key %s" % [definition.id, key])
	if definition.cost <= 0:
		problems.append("%s: bad cost %d" % [definition.id, definition.cost])
	if definition.unlock_tier < 0:
		problems.append("%s: bad unlock tier %d" % [definition.id, definition.unlock_tier])
	if definition.choices <= 0:
		problems.append("%s: bad choices %d" % [definition.id, definition.choices])
	if definition.contents.is_empty():
		problems.append("%s: holds nothing" % definition.id)
	if definition.weights.size() != definition.contents.size():
		problems.append("%s: one weight per content needed" % definition.id)
	var seen: Dictionary[int, bool] = {}
	for index: int in definition.contents.size():
		var kind: int = definition.contents[index]
		if kind < 0 or kind >= EnvelopeDef.Content.size() or seen.has(kind):
			problems.append("%s: bad content %d" % [definition.id, kind])
		seen[kind] = true
		if index < definition.weights.size() and definition.weights[index] <= 0:
			problems.append("%s: bad weight for content %d" % [definition.id, kind])
	if definition.wrapping < 0 or definition.wrapping >= EnvelopeDef.Wrapping.size():
		problems.append("%s: bad wrapping %d" % [definition.id, definition.wrapping])
	return problems
