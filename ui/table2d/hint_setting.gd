class_name HintSetting
extends RefCounted
## Whether the table offers its Hint (the owner's playtest of 2026-11-24): a setting, on
## by default. With it off the Hint button is not shown, its key and gamepad button do
## nothing, and the Controls page leaves it out. What the hint suggests never changes.
## The arrival asks for no hint, so it plays the same either way.

const SETTING: String = "show_hint"
## The table action the Hint answers to (ADR 0035).
const ACTION: String = "commons_hint"


static func shown() -> bool:
	return bool(Settings.value(SETTING))
