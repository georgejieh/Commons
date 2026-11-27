class_name Surnames
extends RefCounted
## The player's family name (ADR 0028): what the surname field accepts, the village
## surnames it refuses, the surnames it offers, and the name a run and its pages use.
## Village and youth surnames are string keys, so they are compared as they read.

const BOOK: NameBook = preload("res://data/villagers/names.tres")
## The most letters a surname may have.
const LONGEST: int = 12
const REFUSED_KEY: String = "surname.refused"
const LENGTH_KEY: String = "surname.length"


## Every village and youth surname key's text, for naming a run.
static func texts(village: VillageBook = RunLoop.DEFAULT_VILLAGE) -> Dictionary[String, String]:
	var found: Dictionary[String, String] = {}
	for family: FamilyDef in village.families + village.youth_templates:
		found[family.name_key] = _t(family.name_key)
	for key: String in village.youth_surnames:
		found[key] = _t(key)
	return found


## What the field keeps of typed text: Latin letters only, at most LONGEST, the first
## capitalised and the rest lowered.
static func clean(typed: String) -> String:
	var letters: String = ""
	for character: String in typed:
		var code: int = character.unicode_at(0)
		var upper: bool = code >= 65 and code <= 90
		var lower: bool = code >= 97 and code <= 122
		if (upper or lower) and letters.length() < LONGEST:
			letters += character
	if letters.is_empty():
		return ""
	return letters.left(1).to_upper() + letters.substr(1).to_lower()


## Why a surname cannot be taken, in words, or "" when it can: too short, or a village
## family's already.
static func refusal(surname: String) -> String:
	var cleaned: String = clean(surname)
	if cleaned.is_empty() or cleaned != surname:
		return _t(LENGTH_KEY)
	if village_holds(surname):
		return _t(REFUSED_KEY).format({"name": surname})
	return ""


## True when a family of the village is called this.
static func village_holds(surname: String) -> bool:
	for family: FamilyDef in RunLoop.DEFAULT_VILLAGE.families:
		if _t(family.name_key).to_lower() == surname.to_lower():
			return true
	return false


## The common surnames the first launch offers as tickets.
static func offered() -> Array[String]:
	return BOOK.offered_surnames.duplicate()


## One of the offered surnames, drawn from seed.
static func pick(seed_value: int) -> String:
	var stream: RandomStream = RandomStream.new(seed_value)
	return BOOK.offered_surnames[stream.next_int(0, BOOK.offered_surnames.size() - 1)]


## The surname the profile holds, or the fallback for one that holds none.
static func of_profile(profile: SaveService) -> String:
	return or_fallback(Profile.read(profile).surname)


static func or_fallback(surname: String) -> String:
	return BOOK.fallback_surname if surname.is_empty() else surname


## Writes a new surname to the profile, keeping all else. False, with nothing written,
## for one the field would refuse.
static func change(profile: SaveService, surname: String) -> bool:
	if not refusal(surname).is_empty():
		return false
	var data: ProfileData = Profile.read(profile)
	data.surname = surname
	return Profile.write(profile, data) == OK


## "Jianguo Wang": a person's name as the pages that introduce them print it, or the
## surname alone for one with no given name.
static func full_name(given: String, surname: String) -> String:
	if given.is_empty():
		return surname
	return _t("name.full").format({"given": given, "surname": surname})


static func _t(key: String) -> String:
	return str(TranslationServer.translate(key))
