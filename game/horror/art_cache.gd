class_name ArtCache
extends RefCounted
## Pictures loaded on demand by file, holding at most limit of them; the least recently
## asked for is dropped first. A dropped picture still on screen stays loaded through the
## node showing it, and comes back as the same texture when asked for again.

## The most pictures it holds at once, at least 1.
var limit: int
var _held: Dictionary[String, Texture2D] = {}
## Paths in the order they were last asked for, oldest first.
var _order: Array[String] = []


func _init(most: int) -> void:
	limit = maxi(most, 1)


## The picture at path, loaded when it is not held. Null for an empty path.
func picture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _held.has(path):
		_order.erase(path)
		_order.append(path)
		return _held[path]
	var texture: Texture2D = load(path)
	_held[path] = texture
	_order.append(path)
	while _order.size() > limit:
		_held.erase(_order.pop_front())
	return texture


## How many pictures it holds now.
func held_count() -> int:
	return _held.size()


## True when the picture at path is held now.
func holds(path: String) -> bool:
	return _held.has(path)


## Drops every held picture.
func clear() -> void:
	_held.clear()
	_order.clear()
