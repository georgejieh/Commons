class_name Ledger
extends VBoxContainer
## The round's work points, as a scoreboard: the landlord's running total, then the
## Commons pool with each peasant's part of it, then the last few plays written out as
## Grain × Rate × Zeal. Rows are made once and reused, so scoring a play instances nothing. A
## seat's total counts up as its play is stamped in (P3B.6).

const MAX_PLAYS: int = 5
## A play's Grain × Rate × Zeal line is smaller than its heading, to fit on one line.
const SUM_SIZE: int = 15
## Rows wrap inside the ledger's paper.
const ROW_WIDTH: float = 270.0
const INK: Color = Color("1e1a16")
const SOFT: Color = Color("5a4a36")

var _pending_type: String = ""
var _names: Dictionary[int, String] = {}
var _totals: PackedFloat64Array = PackedFloat64Array()
var _landlord: int = Seats.NONE
var _rows: Array[HBoxContainer] = []
var _amounts: Array[Label] = []
var _landlord_head: Label = Label.new()
var _commons_head: HBoxContainer = HBoxContainer.new()
var _pool: Label = Label.new()
var _rule: HSeparator = HSeparator.new()
var _plays_head: Label = Label.new()
var _plays: KeywordText = KeywordText.new()
var _texts: PackedStringArray = []
var _counting: Tween = null


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	custom_minimum_size = Vector2(ROW_WIDTH, 0)
	var title: Label = Label.new()
	title.text = tr("ledger.title")
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_font_override("font", ScreenKit.TYPEWRITER_BOLD)
	title.add_theme_color_override("font_color", INK)
	add_child(title)
	_as_head(_landlord_head, "ledger.landlord")
	_as_head(_plays_head, "ledger.plays")
	_as_amount(_pool)
	add_child(_landlord_head)
	var commons: Label = Label.new()
	_as_head(commons, "ledger.commons")
	commons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	commons.tooltip_text = tr("keyword.commons.text")
	commons.mouse_filter = Control.MOUSE_FILTER_STOP
	_commons_head.add_child(commons)
	_commons_head.add_child(_pool)
	add_child(_commons_head)
	_totals.resize(Seats.COUNT)
	for seat: int in Seats.COUNT:
		var row: HBoxContainer = HBoxContainer.new()
		var who: Label = Label.new()
		_as_text(who)
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(who)
		var amount: Label = Label.new()
		_as_amount(amount)
		row.add_child(amount)
		add_child(row)
		_rows.append(row)
		_amounts.append(amount)
	add_child(_rule)
	add_child(_plays_head)
	_plays.bbcode_enabled = true
	_plays.fit_content = true
	_plays.scroll_active = false
	_plays.custom_minimum_size = Vector2(ROW_WIDTH, 0)
	_plays.add_theme_font_override("normal_font", ScreenKit.TYPEWRITER)
	_plays.add_theme_font_override("bold_font", ScreenKit.TYPEWRITER_BOLD)
	_plays.add_theme_font_size_override("normal_font_size", 18)
	_plays.add_theme_font_size_override("bold_font_size", 18)
	_plays.add_theme_color_override("default_color", INK)
	add_child(_plays)
	start_round(Seats.NONE)


## Names each seat's row.
func setup(names: Dictionary[int, String]) -> void:
	_names = names
	for seat: int in _rows.size():
		var who: Label = _rows[seat].get_child(0)
		who.text = names.get(seat, "")


## A new round: every total back to zero, and the rows set out by side. With no
## landlord yet, the seats are simply listed.
func start_round(landlord: int) -> void:
	_landlord = landlord
	_totals.fill(0.0)
	_texts.clear()
	_pending_type = ""
	var sided: bool = landlord != Seats.NONE
	_landlord_head.visible = sided
	_commons_head.visible = sided
	var next: int = _landlord_head.get_index() + 1
	if sided:
		move_child(_rows[landlord], next)
		next += 1
		move_child(_commons_head, next)
		next += 1
	for seat: int in _rows.size():
		if seat != landlord:
			move_child(_rows[seat], next)
			next += 1
	_show()


## The next play's hand type, from the play event that comes before its score.
func set_pending(type_text: String) -> void:
	_pending_type = type_text


## Adds a scored play: its seat's total counts up, and the play is written under Plays.
## With a delay, the total holds its old value until the score arrives from the table.
func add_play(
	seat: int, grain: float, rate: float, zeal: float, total: float, delay: float = 0.0
) -> void:
	var before: float = _totals[seat]
	_totals[seat] += total
	var head: String = tr("ledger.play").format(
		{"who": _names.get(seat, ""), "type": _pending_type, "total": Strings.score(total)}
	)
	var sum: String = (
		tr("ledger.sum")
		. format(
			{
				"grain": Strings.score(grain),
				"rate": Strings.factor(rate),
				"zeal": Strings.factor(zeal),
			}
		)
	)
	var percent: int = ScoreTally.scale_percent(grain, rate, zeal, total)
	if percent != ScoreTally.WHOLE:
		sum += " " + tr("ledger.scaled").format({"percent": percent})
	var line: String = "[font_size=%d]%s[/font_size]" % [SUM_SIZE, Keywords.mark(sum)]
	_texts.append("[b]%s[/b]\n%s" % [head.replace("[", "[lb]"), line])
	if _texts.size() > MAX_PLAYS:
		_texts.remove_at(0)
	_show()
	var amount: Label = _amounts[seat]
	if delay <= 0.0 or UiMotion.reduced():
		UiMotion.stamp(amount)
		_counting = UiMotion.count(amount, before, _totals[seat], Strings.score)
		return
	amount.text = Strings.score(before)
	_counting = amount.create_tween()
	_counting.tween_interval(delay)
	_counting.tween_callback(UiMotion.stamp.bind(amount))
	_counting.tween_method(
		func(value: float) -> void: amount.text = Strings.score(value),
		before,
		_totals[seat],
		UiMotion.PRESETS.count_time
	)


## The seat's total once the round's end multipliers are in.
func set_final(seat: int, total: float) -> void:
	_totals[seat] = total
	_show()


func clear_rows() -> void:
	start_round(Seats.NONE)


## The plays written out, oldest first, as plain text.
func row_texts() -> PackedStringArray:
	return _texts


func total_of(seat: int) -> float:
	return _totals[seat]


## What the peasants have scored between them this round.
func pool() -> float:
	var sum: float = 0.0
	for seat: int in _totals.size():
		if seat != _landlord:
			sum += _totals[seat]
	return sum if _landlord != Seats.NONE else 0.0


## Where a seat's total sits on screen, its middle.
func amount_center(seat: int) -> Vector2:
	var amount: Label = _amounts[seat]
	return amount.global_position + amount.size / 2.0


## Whether the newest score is still counting up.
func is_counting() -> bool:
	return _counting != null and _counting.is_running()


func _show() -> void:
	# A count still rolling would write over a total that has since changed.
	if _counting != null and _counting.is_valid():
		_counting.kill()
	_counting = null
	for seat: int in _amounts.size():
		_amounts[seat].text = Strings.score(_totals[seat])
	_pool.text = Strings.score(pool())
	_plays_head.visible = not _texts.is_empty()
	_rule.visible = not _texts.is_empty()
	_plays.text = "\n".join(_texts)


func _as_head(label: Label, key: String) -> void:
	label.text = tr(key).to_upper()
	label.theme_type_variation = CommonsTheme.EYEBROW
	label.add_theme_color_override("font_color", SOFT)


func _as_text(label: Label) -> void:
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_font_override("font", ScreenKit.TYPEWRITER)
	label.add_theme_color_override("font_color", INK)


func _as_amount(label: Label) -> void:
	_as_text(label)
	label.add_theme_font_override("font", ScreenKit.TYPEWRITER_BOLD)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
