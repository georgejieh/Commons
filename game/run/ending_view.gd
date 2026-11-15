class_name EndingView
extends RefCounted
## A run's end as the ending screen shows it (ADR 0024), as plain values with every
## string already filled in. It is worked out from the run state alone, so a save loaded
## at the run's end shows the same page.

## The ending's ID, or the death's.
var id: String = ""
var death: bool = false
var title_key: String = ""
var text_key: String = ""
var text_values: Dictionary[String, Variant] = {}
var title: String = ""
var text: String = ""
var famine: int = 0
var denunciation: int = 0
var landlord: bool = false
## One string key per epilogue line, in order, with the values that fill it and the
## filled line.
var line_keys: Array[String] = []
var line_values: Array[Dictionary] = []
var lines: Array[String] = []
## The historical note under the epilogue, or empty for an ending without one.
var note_key: String = ""
var note: String = ""
## Decorative Chinese for the title card, or empty.
var seal: String = ""


## surname is the player's family name, as the endings call them.
static func of(
	state: RunState,
	surname: String,
	meters: MeterTable = RunLoop.DEFAULT_METERS,
	params: EndingParams = Endings.DEFAULT_PARAMS
) -> EndingView:
	var view: EndingView = EndingView.new()
	view.id = Endings.outcome(state, meters, params)
	view.death = Endings.is_death(view.id)
	view.title_key = Endings.title_key(view.id)
	view.text_key = Endings.text_key(view.id)
	view.text_values = {"surname": surname, "year": state.year}
	view.title = _t(view.title_key)
	view.text = _t(view.text_key).format(view.text_values)
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
		var values: Dictionary[String, Variant] = {
			"name": _t(line.name_key), "surname": surname, "names": ", ".join(names)
		}
		view.line_keys.append(line.key)
		view.line_values.append(values)
		view.lines.append(_t(line.key).format(values))
	if Endings.NOTED.has(view.id):
		view.note_key = Endings.NOTE_KEY
		view.note = _t(view.note_key)
	view.seal = params.seals.get(view.id, "")
	return view


static func _t(key: String) -> String:
	return str(TranslationServer.translate(key))
