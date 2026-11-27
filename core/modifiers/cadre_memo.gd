class_name CadreMemo
extends RefCounted
## One Cadre's own run state (ADR 0021): whole numbers by name, such as a picked rank or
## how many Bombs it has seen. RunState keeps one per held Cadre in CadreMemos, and the
## run loop binds it to that Cadre's effect, so an effect reads and changes only its own.
## Previews only read it. It is saved with the run, so it holds ints alone.

## The Years a Cadre has been held, counted up at each Year's end for every held Cadre.
const YEARS: String = "years"
## The rank a Cadre picked when bought, for the Cadres that need one.
const RANK: String = "rank"

## Set when the effect fired in a way the player should see, with the amount it fired
## for. The run loop logs it as CADRE_FIRED and clears it. Never saved.
var fired: bool = false
var fired_amount: int = 0

var _values: Dictionary[String, int] = {}


static func from_dict(data: Dictionary) -> CadreMemo:
	var memo: CadreMemo = CadreMemo.new()
	for key: Variant in data:
		memo._values[str(key)] = int(data[key])
	return memo


## True when read is a map of names to numbers.
static func is_valid(read: Variant) -> bool:
	if not read is Dictionary:
		return false
	var data: Dictionary = read
	for key: Variant in data:
		if not key is String or not (data[key] is int or data[key] is float):
			return false
	return true


func to_dict() -> Dictionary:
	return _values.duplicate()


func copy() -> CadreMemo:
	return CadreMemo.from_dict(to_dict())


func has(key: String) -> bool:
	return _values.has(key)


func value(key: String, fallback: int = 0) -> int:
	return _values.get(key, fallback)


func put(key: String, amount: int) -> void:
	_values[key] = amount


## Adds to a count and returns the new value.
func add(key: String, amount: int) -> int:
	_values[key] = value(key) + amount
	return _values[key]


## Marks the effect as having fired for amount, for the run loop to show.
func fire(amount: int = 1) -> void:
	fired = true
	fired_amount += amount


## Clears the fired mark and returns the amount it held.
func take_fired() -> int:
	var amount: int = fired_amount
	fired = false
	fired_amount = 0
	return amount
