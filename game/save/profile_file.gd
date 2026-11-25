class_name ProfileFile
extends RefCounted
## Writes an entry into the family's file (ADR 0022) at once, when an offence is acted
## on, so quitting does not avoid it. An entry goes in once: one whose key the file
## already holds adds nothing, so a replay or a second load of the same offence cannot
## file it twice. Each entry adds corruption (ADR 0018) as it is written, by the books'
## data, growing with corruption as every act does. Nothing here ever takes one out.


## Files the entry and adds its corruption, in one write. Returns true when it was new and
## the write held; false when the file already had it, or the profile could not be written.
static func add(
	profile: SaveService, entry: FileEntry, params: BooksParams = RunBooks.DEFAULT_PARAMS
) -> bool:
	var data: ProfileData = Profile.read(profile)
	if data.has_entry(entry.key):
		return false
	data.file.append(entry)
	data.corruption = corrupted(data.corruption, params)
	return Profile.write(profile, data) == OK


## The corruption after one entry: its amount times (1 + growth * corruption / 100), as
## CorruptionEvents adds every event, clamped.
static func corrupted(corruption: float, params: BooksParams = RunBooks.DEFAULT_PARAMS) -> float:
	var growth: float = CorruptionEvents.DEFAULT_PARAMS.growth
	var value: float = clampf(corruption, 0.0, CorruptionEvents.MAX_VALUE)
	var step: float = params.entry_corruption * (1.0 + growth * value / CorruptionEvents.MAX_VALUE)
	return clampf(value + step, 0.0, CorruptionEvents.MAX_VALUE)


## The entries the profile's file holds now.
static func entries(profile: SaveService) -> Array[FileEntry]:
	return Profile.read(profile).file
