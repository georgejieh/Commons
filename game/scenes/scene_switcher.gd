class_name SceneSwitcher
extends Node
## Shows one screen at a time under a host node, with a back stack. Screens are scenes
## named by ID. The run lives in RunController beside the switcher, never in a screen,
## so changing or going back between screens keeps the run.

signal screen_changed(screen_id: String)

var _host: Node
var _screens: Dictionary[String, PackedScene] = {}
var _stack: Array[String] = []
var _current: Node = null


## host receives each screen as its only child; screens maps IDs to scenes.
func setup(host: Node, screens: Dictionary[String, PackedScene]) -> void:
	_host = host
	_screens = screens


func current_id() -> String:
	return "" if _stack.is_empty() else _stack[-1]


func current() -> Node:
	return _current


## Shows a screen on top of the stack.
func push(screen_id: String) -> Node:
	_stack.append(screen_id)
	return _show(screen_id)


## Replaces the stack with one screen, for moves with no way back.
func replace(screen_id: String) -> Node:
	_stack.clear()
	return push(screen_id)


## Goes back one screen. Returns false at the bottom of the stack.
func back() -> bool:
	if _stack.size() < 2:
		return false
	_stack.pop_back()
	_show(_stack[-1])
	return true


func _show(screen_id: String) -> Node:
	assert(_screens.has(screen_id), "Unknown screen")
	if _current != null:
		_host.remove_child(_current)
		_current.queue_free()
	_current = _screens[screen_id].instantiate()
	_host.add_child(_current)
	screen_changed.emit(screen_id)
	return _current
