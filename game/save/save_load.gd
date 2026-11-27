class_name SaveLoad
extends RefCounted
## What reading a save found. notice_key names a string to show the player, or is empty.
## extras is what was kept beside the data under the same seal. tampered is true when the
## file read is at a schema that seals and its seal was missing or wrong (ADR 0022): it
## still loaded, since its shape was valid. NEWER_VERSION is a save a newer build wrote,
## which this one cannot read and keeps (ADR 0037): not damaged, and never written over.

## How a read went: the save, the save restored from its backup, neither readable, no
## file, or a save a newer build wrote.
enum Status { OK, RESTORED_FROM_BACKUP, UNREADABLE, MISSING, NEWER_VERSION }

## How the read went.
var status: Status
## The save's data, or empty when it could not be read.
var data: Dictionary
## The string key of the notice to show the player, or empty for none.
var notice_key: String
## What was kept beside the data under the same seal.
var extras: Dictionary = {}
## True when the file's seal was missing or wrong at a schema that seals.
var tampered: bool = false
## The seal the file's values make, which names a tampered file; empty otherwise.
var seal: String = ""


func _init(load_status: Status, loaded: Dictionary = {}, key: String = "") -> void:
	status = load_status
	data = loaded
	notice_key = key
