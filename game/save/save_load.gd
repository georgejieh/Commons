class_name SaveLoad
extends RefCounted
## What reading a save found. notice_key names a string to show the player, or is empty.

enum Status { OK, RESTORED_FROM_BACKUP, UNREADABLE, MISSING }

var status: Status
var data: Dictionary
var notice_key: String


func _init(load_status: Status, loaded: Dictionary = {}, key: String = "") -> void:
	status = load_status
	data = loaded
	notice_key = key
