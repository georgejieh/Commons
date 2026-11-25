class_name EndingView
extends RefCounted
## A run's end as the ending screen shows it (ADR 0024), as plain values with every
## string already filled in. It is worked out from the run state alone, so a save loaded
## at the run's end shows the same page.

## The ending's ID, or the death's.
var id: String = ""
var death: bool = false
var title: String = ""
var text: String = ""
var famine: int = 0
var denunciation: int = 0
var landlord: bool = false
## The epilogue's lines, filled in, in order.
var lines: Array[String] = []
## The historical note under the epilogue, or empty for an ending without one.
var note: String = ""
## Decorative Chinese for the title card, or empty.
var seal: String = ""
## The player's full name in this run, for the line under the eyebrow (ADR 0028).
var player_name: String = ""


## surname is the player's family name, as the endings call them.
static func of(state: RunState, surname: String) -> EndingView:
	var params: EndingParams = Endings.DEFAULT_PARAMS
	var view: EndingView = EndingView.new()
	view.id = Endings.outcome(state, RunLoop.DEFAULT_METERS, params)
	view.death = Endings.is_death(view.id)
	view.title = _t(Endings.title_key(view.id))
	var text_values: Dictionary[String, Variant] = {"surname": surname, "year": state.year}
	view.text = _t(Endings.text_key(view.id)).format(text_values)
	view.famine = state.famine
	view.denunciation = state.denunciation
	view.landlord = YearClass.is_landlord(state)
	var epilogue: Array[EpilogueLine] = Endings.epilogue(
		state, view.id, RunLoop.DEFAULT_VILLAGE, RunLoop.DEFAULT_MEMORY, params
	)
	for line: EpilogueLine in epilogue:
		var names: PackedStringArray = []
		for name_key: String in line.name_keys:
			names.append(_t(name_key))
		# The dead line's key lists its names with commas; the others join them in words.
		var values: Dictionary[String, Variant] = {
			"name": joined(names), "surname": surname, "names": ", ".join(names)
		}
		view.lines.append(_t(line.key).format(values))
	if Endings.NOTED.has(view.id):
		view.note = _t(Endings.NOTE_KEY)
	view.seal = params.seals.get(view.id, "")
	view.player_name = _t("end.name").format(
		{"name": Surnames.full_name(state.names.player_given_name(), surname)}
	)
	return view


## Surnames joined for one line, in roster order: "Sun", "Sun and Gao", "Sun, Gao and Ma".
static func joined(names: PackedStringArray) -> String:
	if names.size() <= 1:
		return "" if names.is_empty() else names[0]
	if names.size() == 2:
		return _t("list.pair").format({"a": names[0], "b": names[1]})
	var rest: String = ", ".join(names.slice(0, names.size() - 1))
	return _t("list.last").format({"rest": rest, "last": names[-1]})


static func _t(key: String) -> String:
	return str(TranslationServer.translate(key))
