class_name TableDeck
extends RefCounted
## The deck sheet at the table (ADR 0041): the table's menu has a Deck entry, beside the
## dossier and the last round, that opens it over the table. The menu has already stopped
## the table's events, and they go on once the sheet is closed.


## Puts a deck sheet over table, opened from its menu, and returns it.
static func attach(
	table: Control, menu: PauseMenu, controller: RunController, player: EventPlayer
) -> DeckSheet:
	var sheet: DeckSheet = DeckSheet.new()
	table.add_child(sheet)
	sheet.set_deferred("size", Vector2(1920, 1080))
	sheet.setup(controller)
	menu.deck_chosen.connect(sheet.open_deck)
	sheet.closed.connect(func() -> void: player.set_process(true))
	return sheet
