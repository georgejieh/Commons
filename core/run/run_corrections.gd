class_name RunCorrections
extends RefCounted
## The books command (ADR 0022): figures reported from outside the game, taken as
## official and never refused for being untrue. A figure outside what its field holds is
## clamped to the field; only a malformed command is refused. Against the true figures:
## coupons or progress reported higher become the reported ones, and every later Quota's
## target rises by the same proportion (RunBooks.norm_percent), and for coupons both
## shops' prices too; reported lower, they become the reported ones and nothing else. A
## meter reported higher becomes the reported one with all a real rise brings; reported
## lower, the true meter stays and keeps counting, and the meter goes dark. The norm is
## the same: higher is accepted, lower leaves the true norm and goes dark.

const COUPONS: String = "coupons"
const PROGRESS: String = "progress"
const FAMINE: String = "famine"
const DENUNCIATION: String = "denunciation"
const RESENTMENT: String = "resentment"
const NORM: String = "norm"
## Every figure the books can correct, in the order a correction applies them.
const FIGURES: Array[String] = [COUPONS, PROGRESS, FAMINE, DENUNCIATION, RESENTMENT, NORM]
## The Resentment cause a reported rise is logged under.
const CAUSE: String = "books"


## True when value is a books command's figures: known figures only, each a number, and
## progress a number or a float saved as its bits (RunState.float_text).
static func is_valid(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var figures: Dictionary = value
	for figure: Variant in figures:
		if not figure is String or not FIGURES.has(figure):
			return false
		var reported: Variant = figures[figure]
		if figure == PROGRESS and reported is String:
			var text: String = reported
			if text.length() != 16 or not text.is_valid_hex_number():
				return false
		elif not (reported is int or reported is float):
			return false
	return true


## The figures as a record keeps them: each clamped to what its field holds, whole
## figures as whole numbers, and progress as its bits. Call only on valid figures.
static func clamped(
	figures: Dictionary, params: RunParams, resentment: ResentmentParams, books: BooksParams
) -> Dictionary:
	var kept: Dictionary = {}
	for figure: String in FIGURES:
		if not figures.has(figure):
			continue
		if figure == PROGRESS:
			var progress: float = _progress(figures[figure])
			kept[figure] = RunState.float_text(clampf(progress, 0.0, Scorer.MAX_SCORE))
			continue
		var most: int = books.norm_steps_max
		match figure:
			COUPONS:
				most = books.coupons_max
			FAMINE, DENUNCIATION:
				most = params.meter_max
			RESENTMENT:
				most = resentment.cap
		kept[figure] = _whole(figures[figure], most)
	return kept


## Applies clamped figures against the true ones the state holds, logging meter and
## Resentment changes into events, and returns what was corrected. target is the Quota's
## target in force, which a reported gain in progress is a share of.
static func apply(
	state: RunState,
	figures: Dictionary,
	target: float,
	meters: MeterTable,
	params: RunParams,
	resentment: ResentmentParams,
	books: BooksParams,
	events: Array[RunEvent],
	player: int
) -> BooksCorrection:
	var correction: BooksCorrection = BooksCorrection.new()
	var norm_before: int = state.books.norm_percent
	var price_before: int = state.books.price_percent
	if figures.has(COUPONS):
		_coupons(state, int(figures[COUPONS]), books, correction)
	if figures.has(PROGRESS):
		var reported: float = RunState.float_from_text(str(figures[PROGRESS]))
		_progress_figure(state, reported, target, books, correction)
	for meter: String in [FAMINE, DENUNCIATION]:
		if figures.has(meter):
			var amount: int = int(figures[meter])
			var true_value: int = RunMeters.value(state, meter)
			if _note(state, meter, true_value, amount, correction) > 0:
				RunMeters.report(state, meter, amount, meters, params, player, events)
	if figures.has(RESENTMENT):
		var amount: int = int(figures[RESENTMENT])
		var true_value: int = state.resentment
		if _note(state, RESENTMENT, true_value, amount, correction) > 0:
			Resentment.add(state, amount - true_value, CAUSE, resentment, events)
	if figures.has(NORM):
		var steps: int = int(figures[NORM])
		if _note(state, NORM, state.norm_steps, steps, correction) > 0:
			state.norm_steps = steps
	correction.norm_added = state.books.norm_percent - norm_before
	correction.price_added = state.books.price_percent - price_before
	if not correction.is_empty():
		state.books.corrections += 1
	return correction


## Coupons become the reported figure. Reported higher, the norm and both shops' prices
## rise by reported over true, a true count of none taken as one.
static func _coupons(
	state: RunState, reported: int, books: BooksParams, correction: BooksCorrection
) -> void:
	var true_value: int = state.coupons
	if reported == true_value:
		return
	correction.add(COUPONS, true_value, reported)
	if reported > true_value:
		var ratio: float = float(reported) / maxi(true_value, 1)
		_raise_norm(state, ratio, books)
		var prices: int = state.books.price_percent
		state.books.price_percent = RunBooks.compound(prices, ratio, books.price_cap_percent)
	state.coupons = reported


## Progress becomes the reported figure. Reported higher, the norm rises by the reported
## gain as a share of the Quota's target.
static func _progress_figure(
	state: RunState, reported: float, target: float, books: BooksParams, correction: BooksCorrection
) -> void:
	var true_value: float = state.set_progress
	if RunState.float_text(reported) == RunState.float_text(true_value):
		return
	correction.add(PROGRESS, true_value, reported)
	if reported > true_value and target > 0.0:
		_raise_norm(state, 1.0 + (reported - true_value) / target, books)
	state.set_progress = reported


static func _raise_norm(state: RunState, ratio: float, books: BooksParams) -> void:
	var norm: int = state.books.norm_percent
	state.books.norm_percent = RunBooks.compound(norm, ratio, books.norm_cap_percent)


## Notes a figure that can go dark: a lower report darkens it and changes nothing else.
## Returns the report's sign against the true figure, so a caller applies a rise.
static func _note(
	state: RunState, figure: String, true_value: int, reported: int, correction: BooksCorrection
) -> int:
	if reported == true_value:
		return 0
	correction.add(figure, true_value, reported)
	if reported > true_value:
		return 1
	if not state.books.is_dark(figure):
		state.books.dark.append(figure)
		correction.dark.append(figure)
	return -1


static func _progress(value: Variant) -> float:
	var progress: float = RunState.float_from_text(value) if value is String else float(value)
	return 0.0 if is_nan(progress) else progress


## A whole figure in 0..most. A number past the field's range is clamped to it, and one
## that is not a number at all reads as none.
static func _whole(value: Variant, most: int) -> int:
	var number: float = float(value)
	if is_nan(number):
		return 0
	return int(clampf(floorf(number), 0.0, float(most)))
