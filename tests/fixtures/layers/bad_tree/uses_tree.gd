extends RefCounted
## Fixture: reaches the scene tree without naming an autoload.


func main_loop() -> MainLoop:
	return Engine.get_main_loop()
