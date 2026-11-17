class_name SaveLoad
extends RefCounted
## What reading a save found. notice_key names a string to show the player, or is empty.
## extras is what was kept beside the data under the same seal. tampered is true when the
## file read is at a schema that seals and its seal was missing or wrong (ADR 0022): it
## still loaded, since its shape was valid.

enum Status { OK, RESTORED_FROM_BACKUP, UNREADABLE, MISSING }

var status: Status
var data: Dictionary
var notice_key: String
var extras: Dictionary = {}
var tampered: bool = false
## The seal the file's values make, which names a tampered file; empty otherwise.
var seal: String = ""


func _init(load_status: Status, loaded: Dictionary = {}, key: String = "") -> void:
	status = load_status
	data = loaded
	notice_key = key
