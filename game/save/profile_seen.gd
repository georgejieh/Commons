class_name ProfileSeen
extends RefCounted
## What the profile's seen list remembers (ADR 0026): the arrival, finished or skipped,
## and each one-time tooltip, written through the profile's own read and write. Marking
## the arrival on a first launch is what writes the profile's first save.

const TUTORIAL: String = "tutorial"
const TIPS: Array[String] = ["tip.plot", "tip.debuffs", "tip.memory"]


## True when a profile save, or its backup, is on disk, whole or not.
static func exists(profile: SaveService) -> bool:
	return FileAccess.file_exists(profile.path()) or FileAccess.file_exists(profile.backup_path())


static func has(profile: SaveService, id: String) -> bool:
	return Profile.read(profile).seen.has(id)


## Adds id to the seen list, keeping everything else the profile holds. Writes nothing
## when it is already there.
static func mark(profile: SaveService, id: String) -> Error:
	var data: ProfileData = Profile.read(profile)
	if data.seen.has(id):
		return OK
	data.seen.append(id)
	return Profile.write(profile, data)
