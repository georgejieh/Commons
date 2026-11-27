class_name AuditSlip
extends PanelContainer
## Shows the Commons being split: each claim on it, a seal that flips while the audit
## is decided, the verdict, and what the claim paid. Every claim is checked at the same
## chance each round, so every claim gets a flip, whether or not it was a lie.

const WIDTH: float = 520.0
const SEAL: float = 34.0
const FLIP: float = 0.12
const WAITING: Color = Color("c9a227")
const CLEAR: Color = Color("8a745c")
const HONEST: Color = Color("3f6338")
const CAUGHT: Color = Color("9e1b16")
const ROWS: int = 2

## Where the slip's middle sits.
var center: Vector2 = Vector2.ZERO

var _seats: Array[int] = []
var _needs: Dictionary[int, int] = {}
var _verdicts: Dictionary[int, String] = {}
var _claims: Array[Label] = []
var _seals: Array[Panel] = []
var _results: Array[Label] = []
var _paid: Array[Label] = []
var _flips: Array[Tween] = []
var _names: Dictionary[int, String] = {}


func _ready() -> void:
	theme_type_variation = CommonsTheme.SHEET
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box: VBoxContainer = VBoxContainer.new()
	box.custom_minimum_size = Vector2(WIDTH, 0)
	box.add_theme_constant_override("separation", 10)
	box.add_child(ScreenKit.styled(tr("audit.title"), CommonsTheme.TITLE))
	for _index: int in ROWS:
		var claim: Label = ScreenKit.label("", 24)
		claim.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var paid: Label = ScreenKit.label("", 26, HONEST)
		# A wrapping label in a row shrinks to one letter a line.
		claim.autowrap_mode = TextServer.AUTOWRAP_OFF
		paid.autowrap_mode = TextServer.AUTOWRAP_OFF
		var top: HBoxContainer = HBoxContainer.new()
		top.add_child(claim)
		top.add_child(paid)
		var seal: Panel = Panel.new()
		seal.custom_minimum_size = Vector2(SEAL, SEAL)
		seal.pivot_offset = Vector2(SEAL, SEAL) / 2.0
		var result: Label = ScreenKit.label("", 22)
		result.autowrap_mode = TextServer.AUTOWRAP_OFF
		seal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var bottom: HBoxContainer = HBoxContainer.new()
		bottom.add_theme_constant_override("separation", 12)
		bottom.add_child(seal)
		bottom.add_child(result)
		box.add_child(top)
		box.add_child(bottom)
		_claims.append(claim)
		_paid.append(paid)
		_seals.append(seal)
		_results.append(result)
		_flips.append(null)
	add_child(box)
	visible = false


func setup(names: Dictionary[int, String]) -> void:
	_names = names


## A seat's claim, as its declared need. Shares are worked out across the claims so
## far, so the second claim settles both.
func claim(seat: int, need: int) -> void:
	if _seats.size() >= ROWS:
		clear()
	_seats.append(seat)
	_needs[seat] = need
	var total: int = 0
	for other: int in _seats:
		total += _needs[other]
	for index: int in _seats.size():
		var who: int = _seats[index]
		var percent: int = NeedPanel.share_percent(_needs[who], total - _needs[who])
		_claims[index].text = tr("audit.claim").format(
			{"name": _names.get(who, ""), "percent": percent}
		)
	var row: int = _seats.size() - 1
	_results[row].text = tr("audit.rolling")
	_paid[row].text = ""
	_tint(row, WAITING)
	_spin(row)
	visible = true
	_fit.call_deferred()


## A seat's claim was checked: lied is whether it was above the fair share.
func audited(seat: int, lied: bool) -> void:
	_verdicts[seat] = "audit.caught" if lied else "audit.honest"


## A seat was paid: its seal lands on the verdict, and the payment is written in.
func paid(seat: int, amount: int) -> void:
	var row: int = _seats.find(seat)
	if row < 0:
		return
	var key: String = _verdicts.get(seat, "audit.clear")
	_stop(row)
	_results[row].text = tr(key)
	var color: Color = CLEAR
	if key == "audit.caught":
		color = CAUGHT
	elif key == "audit.honest":
		color = HONEST
	_tint(row, color)
	_results[row].add_theme_color_override("font_color", color)
	_paid[row].text = tr("audit.paid").format({"amount": Strings.score(amount)})
	UiMotion.stamp(_seals[row])
	UiMotion.pulse(_paid[row])


func clear() -> void:
	for row: int in ROWS:
		_stop(row)
		_claims[row].text = ""
		_results[row].text = ""
		_paid[row].text = ""
		_results[row].add_theme_color_override("font_color", ScreenKit.INK)
	_seats.clear()
	_needs.clear()
	_verdicts.clear()
	visible = false


## What a seat's row says, for tests: its claim, verdict and payment.
func row_text(seat: int) -> String:
	var row: int = _seats.find(seat)
	if row < 0:
		return ""
	return "%s | %s | %s" % [_claims[row].text, _results[row].text, _paid[row].text]


func _spin(row: int) -> void:
	_stop(row)
	if UiMotion.reduced():
		return
	var tween: Tween = _seals[row].create_tween().set_loops()
	tween.tween_property(_seals[row], "scale:x", 0.05, FLIP)
	tween.tween_property(_seals[row], "scale:x", 1.0, FLIP)
	_flips[row] = tween


func _stop(row: int) -> void:
	if _flips[row] != null and _flips[row].is_valid():
		_flips[row].kill()
	_flips[row] = null
	_seals[row].scale = Vector2.ONE


func _tint(row: int, color: Color) -> void:
	var round_seal: StyleBoxFlat = StyleBoxFlat.new()
	round_seal.bg_color = color
	round_seal.set_corner_radius_all(int(SEAL / 2.0))
	round_seal.border_color = ScreenKit.INK
	round_seal.set_border_width_all(2)
	_seals[row].add_theme_stylebox_override("panel", round_seal)


func _fit() -> void:
	reset_size()
	if center != Vector2.ZERO:
		position = center - size / 2.0
