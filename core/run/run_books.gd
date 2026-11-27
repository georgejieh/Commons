class_name RunBooks
extends RefCounted
## What the run's books hold after figures reported from outside the game were taken as
## official (ADR 0022): the figures that went dark, how far corrections raised
## the norm and the shops' prices, and how many corrections there were. A raised norm is
## kept here as a percent of each target, apart from the overfulfilment steps, and so is
## a raised price. Both compound: each correction multiplies what the last left.

## The divisor that turns a whole-number percent into a fraction.
const PERCENT: int = 100
## The file's and the corrections' rates and caps, used when a caller gives none.
const DEFAULT_PARAMS: BooksParams = preload("res://data/run/books.tres")
## The figures that can go dark: a lowered meter, or a lowered norm.
const DARKENS: Array[String] = [
	RunCorrections.FAMINE,
	RunCorrections.DENUNCIATION,
	RunCorrections.RESENTMENT,
	RunCorrections.NORM,
]

## Figures shown from now on as "None reported", in the order they went dark. The true
## figure goes on counting where the player cannot see it.
var dark: Array[String] = []
## How far corrections have raised every later Quota's target, in percent.
var norm_percent: int = 0
## The part of norm_percent in force for the Quota in play, as start_quota sets it.
var norm_in_force: int = 0
## How far corrections have raised both shops' prices, in percent, from the moment each
## was made.
var price_percent: int = 0
## Corrections this run that changed or darkened a figure.
var corrections: int = 0


## Books from their saved form; a field that is missing is at its empty value.
static func from_dict(data: Dictionary) -> RunBooks:
	var books: RunBooks = RunBooks.new()
	books.dark.assign(data.get("dark", []))
	books.norm_percent = int(data.get("norm_percent", 0))
	books.norm_in_force = int(data.get("norm_in_force", 0))
	books.price_percent = int(data.get("price_percent", 0))
	books.corrections = int(data.get("corrections", 0))
	return books


## The books as a map for the run save; from_dict reads it back.
func to_dict() -> Dictionary:
	return {
		"dark": dark.duplicate(),
		"norm_percent": norm_percent,
		"norm_in_force": norm_in_force,
		"price_percent": price_percent,
		"corrections": corrections,
	}


## True when the figure is shown as None reported.
func is_dark(figure: String) -> bool:
	return dark.has(figure)


## True when value is a whole books record: each dark figure one that can go dark, once,
## and every number a whole count, the norm in force no more than the norm.
static func is_valid(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var data: Dictionary = value
	if not data.get("dark") is Array:
		return false
	var seen: Array[String] = []
	for figure: Variant in data["dark"]:
		if not figure is String or not DARKENS.has(figure) or seen.has(figure):
			return false
		seen.append(figure)
	for key: String in ["norm_percent", "norm_in_force", "price_percent", "corrections"]:
		var number: Variant = data.get(key)
		if not RunState.is_count(number):
			return false
	return data["norm_in_force"] <= data["norm_percent"]


## A Quota starts: what corrections raised the norm by until now is in force for it.
static func start_quota(state: RunState) -> void:
	state.books.norm_in_force = state.books.norm_percent


## How far the family's file raises every target of a run that began with entries in it:
## entry_percent an entry, up to entry_cap_percent.
static func file_percent(entries: int, params: BooksParams = DEFAULT_PARAMS) -> int:
	return mini(maxi(entries, 0) * params.entry_percent, params.entry_cap_percent)


## A target under the file and the corrections in force, or the same target when neither
## raises it, so a run with neither computes exactly what it did before them.
static func raised_target(
	target_value: float, state: RunState, params: BooksParams = DEFAULT_PARAMS
) -> float:
	var filed: int = file_percent(state.identity.file_entries, params)
	var corrected: int = state.books.norm_in_force
	if filed == 0 and corrected == 0:
		return target_value
	return target_value * (PERCENT + filed) / PERCENT * (PERCENT + corrected) / PERCENT


## A shop's price under the corrections' raise, rounded up, or the same price with none.
static func priced(state: RunState, price: int) -> int:
	var raise: int = state.books.price_percent
	if raise == 0:
		return price
	@warning_ignore("integer_division")
	return (price * (PERCENT + raise) + PERCENT - 1) / PERCENT


## A percent raise multiplied by ratio, rounded up and capped: what a raise already at
## percent becomes when the figure it follows grew ratio times.
static func compound(percent: int, ratio: float, cap: int) -> int:
	if not ratio > 1.0:
		return percent
	var raised: float = (PERCENT + percent) * ratio - PERCENT
	return clampi(ceili(minf(raised, float(cap))), percent, maxi(cap, percent))
