class_name BooksCorrection
extends RefCounted
## What one books command corrected (ADR 0022, P4.19), carried by its BOOKS_CORRECTED
## event, so the notice can be built from the event alone: each figure that differed, its
## true value and the value reported, and what followed. A correction with no figures is
## an offence with nothing to correct, such as a save whose seal failed.

## The figures that differed, in RunCorrections.FIGURES order, with the true and the
## reported value of each at the same index.
var figures: Array[String] = []
var true_values: Array[float] = []
var reported: Array[float] = []
## How far this correction raised every later target and both shops' prices, in percent
## points of the run's raise, and the figures it put out of sight.
var norm_added: int = 0
var price_added: int = 0
var dark: Array[String] = []


func add(figure: String, true_value: float, reported_value: float) -> void:
	figures.append(figure)
	true_values.append(true_value)
	reported.append(reported_value)


func is_empty() -> bool:
	return figures.is_empty()


## One line for logs: each figure as true>reported, then what followed.
func describe() -> String:
	var parts: PackedStringArray = []
	for index: int in figures.size():
		parts.append("%s %s>%s" % [figures[index], true_values[index], reported[index]])
	if norm_added > 0:
		parts.append("norm+%d%%" % norm_added)
	if price_added > 0:
		parts.append("prices+%d%%" % price_added)
	for figure: String in dark:
		parts.append("%s dark" % figure)
	return ", ".join(parts)
