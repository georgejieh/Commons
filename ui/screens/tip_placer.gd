class_name TipPlacer
extends Node
## Stands the engine's own tooltips where SlipPlacer stands every slip: right beside the
## control they explain, above it or below it first, never over it or its own button.
## The engine puts a tooltip at the pointer, which lays it over the very thing hovered;
## this moves it once the engine has shown it, before it is drawn. One watches the whole
## tree from the app.

## A control may name another as the thing its tooltip explains, as a Buy button names
## its card: the tooltip then keeps off all of that one.
const SUBJECT: StringName = &"tip_subject"
## How the engine marks its tooltip's panel.
const VARIATION: StringName = &"TooltipPanel"
const GAP: float = 10.0
const EDGE: float = 12.0


func _ready() -> void:
	get_tree().node_added.connect(_on_added)


## Moves a tooltip's panel beside the control it was added to. Anything else is left be.
func settle(panel: Window) -> void:
	if not is_instance_valid(panel) or not is_tooltip(panel):
		return
	var owner_control: Control = panel.get_parent() as Control
	if owner_control == null or not owner_control.is_inside_tree():
		return
	var screen: Rect2 = owner_control.get_viewport().get_visible_rect().grow(-EDGE)
	var keep: Rect2 = subject(owner_control)
	var root: Node = owner_control.get_viewport()
	var at: Vector2 = SlipPlacer.place(Vector2(panel.size), keep, GAP, screen, root, panel)
	panel.position = Vector2i(at.round())


## True for the panel the engine shows a tooltip in.
static func is_tooltip(panel: Window) -> bool:
	return (
		panel is PopupPanel
		and (panel.theme_type_variation == VARIATION or panel.get_class() == "TooltipPanel")
	)


## What a tooltip on control keeps off: the control, or the one it names, and every
## button inside that, which may stand past its edge.
static func subject(control: Control) -> Rect2:
	var named: Object = control.get_meta(SUBJECT) if control.has_meta(SUBJECT) else null
	var thing: Control = control
	if is_instance_valid(named) and named is Control and (named as Control).is_inside_tree():
		thing = named as Control
	var rect: Rect2 = SlipPlacer.on_screen(thing)
	for node: Node in thing.find_children("*", "BaseButton", true, false):
		var button: Control = node as Control
		if button.is_visible_in_tree():
			rect = rect.merge(SlipPlacer.on_screen(button))
	return rect


func _on_added(node: Node) -> void:
	if node is PopupPanel and node.get_parent() is Control:
		settle.call_deferred(node as Window)
