class_name TipPlacer
extends Node
## Stands the engine's own tooltips where SlipPlacer stands every slip: right beside the
## control they explain, above it or below it first, never over it or its own button.
## The engine puts a tooltip at the pointer, which lays it over the very thing hovered;
## this moves it once the engine has shown it, before it is drawn. One watches the whole
## tree from the app.

## How the engine marks its tooltip's panel.
const VARIATION: StringName = &"TooltipPanel"
## The room, in pixels, between a tooltip and the control it explains.
const GAP: float = 10.0
## The room, in pixels, a tooltip keeps from the screen's edge.
const EDGE: float = 12.0


func _ready() -> void:
	get_tree().node_added.connect(_on_added)


## Moves a tooltip's panel beside the control it was added to. Anything else is left be.
func settle(panel: Window) -> void:
	if not is_instance_valid(panel) or not _is_tooltip(panel):
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
static func _is_tooltip(panel: Window) -> bool:
	return (
		panel is PopupPanel
		and (panel.theme_type_variation == VARIATION or panel.get_class() == "TooltipPanel")
	)


## What a tooltip on control keeps off: the control and every button inside it, which may
## stand past its edge.
static func subject(control: Control) -> Rect2:
	var rect: Rect2 = SlipPlacer.on_screen(control)
	for node: Node in control.find_children("*", "BaseButton", true, false):
		var button: Control = node as Control
		if button.is_visible_in_tree():
			rect = rect.merge(SlipPlacer.on_screen(button))
	return rect


func _on_added(node: Node) -> void:
	if node is PopupPanel and node.get_parent() is Control:
		settle.call_deferred(node as Window)
