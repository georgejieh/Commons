class_name IntelWorstCase
extends RefCounted
## What an information Cadre can print on a seat at its worst (ADR 0034, rule 9), from
## real hands: the Holds line that wraps tallest, and a Cards line of twenty of the
## widest glyphs. For the tests.

## Seeded hands the worst Holds line is drawn from, of each size.
const INTEL_HANDS: int = 2000
const INTEL_SEED: int = 5303
const MOST_CARDS: int = 20

static var _holds: Array[String] = []


## Every Holds line an Informant can print, from seeded hands of 17 and 20 cards grouped
## as the game groups them, each line once.
static func holds_lines(app: DemoApp) -> Array[String]:
	if not _holds.is_empty():
		return _holds
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = INTEL_SEED
	var table: BotTable = app.controller.table.player_table()
	var seen: Dictionary[String, bool] = {}
	for size: int in [17, MOST_CARDS]:
		for _hand: int in INTEL_HANDS:
			var deck: Array[int] = []
			for card: int in Deck.SIZE:
				deck.insert(rng.randi_range(0, deck.size()), card)
			var counts: PackedByteArray = PackedByteArray()
			counts.resize(Ranks.COUNT)
			for card: int in deck.slice(0, size):
				counts[Deck.new().card(card).base_rank()] += 1
			var types: PackedInt32Array = PackedInt32Array()
			types.resize(Pattern.Type.size())
			for group: Pattern in Bot.suggest_groups(counts, table, BotConfig.new()):
				types[group.type] += 1
			var line: String = TranslationServer.translate("intel.types").format(
				{"list": IntelText.types_text(types)}
			)
			seen[line] = true
	_holds.assign(seen.keys())
	return _holds


## The intel a seat can show at its worst: the Holds line that wraps tallest across the
## sheet at the type now, and a Cards line of twenty of the widest glyphs.
static func worst_intel(app: DemoApp, panel: SeatPanel) -> String:
	var label: Label = panel.intel_line
	var font: Font = label.get_theme_font("font")
	var font_size: int = TextSize.px(SeatPanel.INTEL_SIZE)
	var wide: float = panel.size.x - panel.get_theme_stylebox("panel").get_minimum_size().x
	var best: String = ""
	var best_size: Vector2 = Vector2(-1.0, -1.0)
	for line: String in holds_lines(app):
		var tall: float = (
			font.get_multiline_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, wide, font_size).y
		)
		var long: float = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if tall > best_size.y or (is_equal_approx(tall, best_size.y) and long > best_size.x):
			best = line
			best_size = Vector2(long, tall)
	var ranks: Array[int] = []
	for rank: int in Ranks.COUNT:
		ranks.append(rank)
	var glyph: Callable = func(rank: int) -> float:
		var text: String = TranslationServer.translate(CardView.RANK_KEYS[rank])
		return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	ranks.sort_custom(func(a: int, b: int) -> bool: return glyph.call(a) > glyph.call(b))
	var counts: PackedByteArray = PackedByteArray()
	counts.resize(Ranks.COUNT)
	var left: int = MOST_CARDS
	for rank: int in ranks:
		var copies: int = mini(1 if rank >= Ranks.SMALL_JOKER else 4, left)
		counts[rank] = copies
		left -= copies
	var cards_line: String = TranslationServer.translate("intel.cards").format(
		{"list": IntelText.cards_text(counts)}
	)
	return best + "\n" + cards_line
