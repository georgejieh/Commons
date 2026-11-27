class_name TableColumns
extends RefCounted
## The table's two side columns under the seats (ADR 0034, rules 6 to 10). Each gives way
## in a fixed order until what it holds fits; nothing in either is ever laid over
## another piece.
##
## Left, between the left seat's top and the brigade notice's foot: the seat, then the
## Campaign tray, then the notice. The tray drops its heading; then the notice is taken
## down; then the seat's intel line fits its type down, never under Standard.
##
## Right, between the right seat's top and the action column at its tallest, which is its
## height at Standard since the prompt's box is (rule 10): the seat, then the rules slip,
## then the wall roster at the column's foot. The roster is taken down first; then the
## slip names its rules, then fits their type down; then the seat's intel line fits its
## type down; only then is the slip counted.

## Between a seat's foot and what stands under it, and above the action column.
const GAP: float = 8.0
## Between the tray and the notice, and above the status line.
const TRAY_GAP: float = 4.0

## How many times a column has been laid out, for tests.
var refits: int = 0

var _left: SeatPanel
var _right: SeatPanel
var _tray: CampaignTray
var _dressing: DreadDressing
var _strip: DebuffStrip
var _actions: ActionBar
## The action column's top at its tallest, measured once the table is laid out.
var _floor: float = -1.0
## True while a second layout is waiting for the frame's end.
var _again: bool = false
## True while a column is being laid out, so a signal it sets off cannot start another.
var _fitting: bool = false


## Gives the columns the seats, the Campaign tray, the dressing, the rules slip and the action bar
## they lay out, and lays the right column out whenever the slip is read or the tray changes.
func setup(
	seats: Dictionary[int, SeatPanel],
	tray: CampaignTray,
	dressing: DreadDressing,
	strip: DebuffStrip,
	actions: ActionBar
) -> void:
	_left = seats[Seats.LEFT]
	_right = seats[Seats.RIGHT]
	_tray = tray
	_dressing = dressing
	_strip = strip
	_actions = actions
	strip.shown.connect(fit_right)
	tray.changed.connect(fit_left)


## Lays both columns out now, and once more when the frame's layout has settled, since a
## seat's lines take their final size only then. A layout is never started by a size
## change it made: it runs on the table's own moments (the queue drained, the rules read
## again, a Campaign armed or put down), and a call made while one runs does nothing.
func fit() -> void:
	fit_left()
	fit_right()
	if not _again:
		_again = true
		_fit_again.call_deferred()


func _fit_again() -> void:
	_again = false
	if is_instance_valid(_left) and _left.is_inside_tree():
		fit_left()
		fit_right()


## The seat, the tray and the notice, in that order down the left edge.
func fit_left() -> void:
	if _fitting:
		return
	_fitting = true
	refits += 1
	_left.put_away_intel(false)
	_left.fit_intel(TextSize.px(SeatPanel.INTEL_SIZE))
	if not _tray.visible:
		_dressing.take_down_notice(false)
	elif not _fit_tray() and _tray.armed_slot() >= 0 and _left.has_intel():
		# Rule 8's last step: the seat's intel waits until the Campaign is used or put down.
		_left.put_away_intel(true)
		_fit_tray()
	_fitting = false


## Steps the left column down until the tray fits; false when even the intel's type at
## its Standard size leaves it short.
func _fit_tray() -> bool:
	var size: int = _left.intel_size()
	var least: int = TextSize.least(SeatPanel.INTEL_SIZE)
	var fitted: bool = false
	var settled: bool = false
	while not settled:
		var top: float = _tray_top()
		var notice: float = _dressing.notice_top()
		settled = true
		fitted = true
		if top + _tray.standing_height(true) <= notice - TRAY_GAP:
			_settle_tray(top, true, false)
		elif top + _tray.standing_height(false) <= notice - TRAY_GAP:
			_settle_tray(top, false, false)
		else:
			fitted = top + _tray.standing_height(false) <= DreadDressing.NOTICE_AT.end.y
			if fitted or size <= least or not _left.has_intel():
				_settle_tray(top, false, true)
			else:
				settled = false
				size -= 1
				_left.fit_intel(size)
	return fitted


## The seat, the rules slip and the roster, in that order down the right edge.
func fit_right() -> void:
	if _fitting:
		return
	_fitting = true
	refits += 1
	_right.fit_intel(TextSize.px(SeatPanel.INTEL_SIZE))
	_place_strip()
	_strip.allow_count = false
	_strip.refit()
	var size: int = _right.intel_size()
	var least: int = TextSize.least(SeatPanel.INTEL_SIZE)
	while _right.has_intel() and not _strip.fits() and size > least:
		size -= 1
		_right.fit_intel(size)
		_place_strip()
		_strip.refit()
	if not _strip.fits():
		_strip.allow_count = true
		_strip.refit()
	_dressing.hang_roster(_strip_top() + _strip.standing() + GAP, floor_top() - GAP)
	_fitting = false


## The action column's top with the prompt's box over its tallest row, playing or
## bidding: never higher than at Standard (ADR 0034, rule 10).
func floor_top() -> float:
	if _floor < 0.0:
		var tall: float = 0.0
		for bidding: bool in [false, true]:
			tall = maxf(tall, _actions.tallest(bidding))
		_floor = _actions.held().end.y - tall
	return _floor


## The slip's room as the right seat stands now.
func _strip_room() -> float:
	return floor_top() - GAP - _strip_top()


func _place_strip() -> void:
	_strip.position.y = _strip_top()
	_strip.room = _strip_room()


func _strip_top() -> float:
	return _right.position.y + _right.get_combined_minimum_size().y + GAP


func _tray_top() -> float:
	return maxf(
		TableCampaigns.TRAY_AT.y, _left.position.y + _left.get_combined_minimum_size().y + TRAY_GAP
	)


func _settle_tray(top: float, heading: bool, notice_down: bool) -> void:
	_tray.position.y = top
	_tray.show_heading(heading)
	_dressing.take_down_notice(notice_down)
