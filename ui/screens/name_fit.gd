class_name NameFit
extends RefCounted
## Sets a name so that no line ever breaks inside a word: lines break only between words,
## and when one word is wider than the paper the type shrinks until it fits, never below
## a floor. Every paper that prints a name goes through here: Campaign leaflets, counter
## panels, envelope choices, shop Cadre cards, the collection and the notice board.
## Callers hand it sizes from TextSize: the base as TextSize.px and the floor as
## TextSize.least, so a name grows with the text size and never sets smaller than at
## Standard.

## The least a name is set at on full-size paper; compact papers set their own floor.
const LEAST: int = 16


## The largest size from base down to least at which every word of text fits wide.
static func size_for(font: Font, text: String, wide: float, base: int, least: int) -> int:
	var font_size: int = base
	while font_size > least and not words_fit(font, text, wide, font_size):
		font_size -= 1
	return font_size


## True when every word of text, set at font_size, is no wider than wide.
static func words_fit(font: Font, text: String, wide: float, font_size: int) -> bool:
	for word: String in text.split(" ", false):
		if font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > wide:
			return false
	return true


## Sets label to text at the size that fits wide, wrapping only between words.
static func apply(label: Label, text: String, wide: float, base: int, least: int) -> void:
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	var font: Font = label.get_theme_font("font")
	label.add_theme_font_size_override("font_size", size_for(font, text, wide, base, least))


## True when no word of the label's text is wider than the label, so no line can break
## inside one: for tests.
static func label_fits(label: Label) -> bool:
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	var wrapping: bool = label.autowrap_mode == TextServer.AUTOWRAP_WORD
	return wrapping and words_fit(font, label.text, label.size.x + 0.5, font_size)
