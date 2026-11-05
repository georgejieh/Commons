class_name DossierScreen
extends Control
## What you have seen each villager at the table do this run (P3B.8): bids and calls,
## bombs, passes, plays over a teammate, first-out finishes and rounds as landlord. It
## reads the run's observations and never names a personality.

## Each line's string key and the observation it reports.
const LINES: Dictionary[String, Observations.Kind] = {
	"dossier.bombs": Observations.Kind.BOMBS,
	"dossier.passes": Observations.Kind.PASSES,
	"dossier.beat_teammate": Observations.Kind.BEAT_TEAMMATE,
	"dossier.went_out": Observations.Kind.WENT_OUT,
	"dossier.landlord": Observations.Kind.LANDLORD_ROUNDS,
}
const PORTRAIT_SIZE: Vector2 = Vector2(150, 188)

var _entries: Dictionary[int, PackedStringArray] = {}


func open(app: DemoApp) -> void:
	var state: RunState = app.controller.state_copy()
	var column: VBoxContainer = ScreenKit.centered_sheet(self, ScreenKit.ART.notice_wall)
	column.add_child(ScreenKit.header(tr("dossier.eyebrow"), tr("dossier.title")))
	var cards: Array[Control] = []
	for seat: int in range(1, Seats.COUNT):
		cards.append(_villager(app, state, seat))
	column.add_child(ScreenKit.row(cards, 28))
	var back: Button = ScreenKit.button(tr("dossier.back"), CommonsTheme.PRIMARY)
	back.pressed.connect(app.back)
	column.add_child(back)
	ScreenKit.reveal(column)
	back.grab_focus()


## The lines shown for a seat, for tests.
func entries(seat: int) -> PackedStringArray:
	return _entries.get(seat, PackedStringArray())


func _villager(app: DemoApp, state: RunState, seat: int) -> Control:
	var sheet: VBoxContainer = ScreenKit.card(Vector2(420, 0))
	var portrait: TextureRect = TextureRect.new()
	portrait.texture = app.seat_portrait(seat, PORTRAIT_SIZE)
	portrait.custom_minimum_size = PORTRAIT_SIZE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sheet.add_child(portrait)
	sheet.add_child(ScreenKit.styled(app.seat_name(seat), CommonsTheme.TITLE))
	var lines: PackedStringArray = _lines(state.observations, state.table[seat])
	_entries[seat] = lines
	for text: String in lines:
		sheet.add_child(ScreenKit.label(text, 22))
	return ScreenKit.card_panel(sheet)


func _lines(seen: Observations, family: String) -> PackedStringArray:
	if not seen.has_family(family):
		return PackedStringArray([tr("dossier.empty")])
	var lines: PackedStringArray = []
	var bids: int = seen.count(family, Observations.Kind.BIDS)
	var called: int = seen.count(family, Observations.Kind.CALLS)
	lines.append(tr("dossier.calls").format({"called": called, "bids": bids}))
	for key: String in LINES:
		lines.append(tr(key).format({"count": seen.count(family, LINES[key])}))
	return lines
