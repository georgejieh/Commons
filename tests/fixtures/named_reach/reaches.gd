extends Node
## Fixture: each way a script can reach a private member by its name, one a line.


func _reach(page: Node, drawn: Callable) -> void:
	page.call("_draw_paper")
	page.set_deferred("_paper", null)
	print(Callable(page, "_draw_paper"))
	print(page.has_method("_draw_paper"))
	page.connect("_drawn", drawn)
	print(page.is_connected("_drawn", drawn))
	page.disconnect("_drawn", drawn)
	print(page["_paper"])
