class_name TutorialStep
extends Resource
## One step of the arrival (ADR 0026): the one action the player must take, what it
## points at, the line that asks for it and the line that follows it.

enum Action { BID_CALL, BID_PASS, PLAY, PASS, NEED, BUTTON }

## The step's number as its string keys hold it: "01" to "20".
@export var id: String = ""
@export var action: Action = Action.BUTTON
## PLAY: the exact card IDs.
@export var cards: PackedInt32Array = PackedInt32Array()
## NEED: the need to declare.
@export var need: int = 0
## BUTTON: the named button the step asks for, and the slot it names, or -1.
@export var button: String = ""
@export var slot: int = -1
## The screen the step's prompt shows on, and the target it rings there.
@export var screen: String = "table"
@export var highlight: String = ""
## A button allowed on the way to the action, on its own screen, which keeps the step.
@export var via: String = ""
@export var via_screen: String = ""
## A button that ends the step once its follow-up shows, or empty when the action does.
@export var until: String = ""
@export var prompt_key: String = ""
## The line that follows the action, or empty for none.
@export var then_key: String = ""
## The meter whose high band the board shows for a moment after the action, or empty.
@export var preview: String = ""
