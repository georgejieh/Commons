extends Node
## Fixture: a UI script that stocks a shop and rebuilds a run's modifiers, as only tests and
## tools may.


func _stock(shop: Object, loop: Object) -> void:
	shop.stock_with([], [])
	loop.rebuild_modifiers()
