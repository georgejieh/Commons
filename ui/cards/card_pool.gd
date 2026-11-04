class_name CardPool
extends Node
## Every card view the table uses, made once when the table loads and reused after, so
## no card is instanced during a round (P3B.3).

const SIZE: int = 60
const CARD_SCENE: PackedScene = preload("res://ui/cards/card_view.tscn")

var _free: Array[CardView] = []
var _all: Array[CardView] = []


## Makes the pool's views under parent, hidden.
func fill(parent: Node) -> void:
	for _index: int in SIZE:
		var view: CardView = CARD_SCENE.instantiate()
		parent.add_child(view)
		view.bind(null)
		_all.append(view)
		_free.append(view)


## A hidden view to bind, or null when every view is in use.
func acquire() -> CardView:
	if _free.is_empty():
		return null
	return _free.pop_back()


func release(view: CardView) -> void:
	view.bind(null)
	if not _free.has(view):
		_free.append(view)


func release_all() -> void:
	for view: CardView in _all:
		release(view)


func free_count() -> int:
	return _free.size()


func size() -> int:
	return _all.size()
