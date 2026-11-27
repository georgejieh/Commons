class_name TutorialStep
extends Resource
## One step of the arrival (ADR 0026): the one action the player must take, what it
## points at, the line that asks for it and the line that follows it.

## What the step asks of the player: a bid or a pass in the bidding, a play, a pass, a need,
## or a press of a named button.
enum Action { BID_CALL, BID_PASS, PLAY, PASS, NEED, BUTTON }

## The step's number as its string keys hold it: "01" to "20".
@export var id: String = ""
## The action the step asks for.
@export var action: Action = Action.BUTTON
## PLAY: the exact card IDs.
@export var cards: PackedInt32Array = PackedInt32Array()
## NEED: the need to declare.
@export var need: int = 0
## BUTTON: the named button the step asks for.
@export var button: String = ""
## The slot the named button belongs to, or -1.
@export var slot: int = -1
## The screen the step's prompt shows on.
@export var screen: String = "table"
## The target the step's prompt rings.
@export var highlight: String = ""
## A button allowed on the way to the action, which keeps the step.
@export var via: String = ""
## The screen the via button is on.
@export var via_screen: String = ""
## A button that ends the step once its follow-up shows, or empty when the action does.
@export var until: String = ""
## The string key of the line that asks for the action.
@export var prompt_key: String = ""
## The line that follows the action, or empty for none.
@export var then_key: String = ""
