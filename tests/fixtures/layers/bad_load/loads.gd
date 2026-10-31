extends RefCounted
## Fixture: loads a resource at runtime.


func fetch() -> Resource:
	return load("ui/title.tscn")
