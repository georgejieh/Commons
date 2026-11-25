extends GdUnitTestSuite
## The name data is ADR 0028's, word for word: the four era pools and the generations each
## serves, the given names blocked with every surname, the pairs blocked together and the
## 24 offered surnames, read from the ADR itself so a revision the data missed fails here.
## Each pool holds 40 pinyin names, capitalised, none twice and none on the every-surname
## list; no offered surname, nor the fallback, is a village family's.

const ADR: String = "res://docs/adr/0028-names-and-generations.md"
const BOOK: NameBook = preload("res://data/villagers/names.tres")
const POOLS: Dictionary[String, int] = {"Old": 1, "Founding": 2, "Red": 3, "Reform": 4}
const POOL_SIZE: int = 40
const OFFERED: int = 24


func _adr() -> String:
	return FileAccess.get_file_as_string(ADR).replace("\r", "")


func _list(text: String) -> Array[String]:
	var names: Array[String] = []
	for part: String in text.split(","):
		names.append(part.strip_edges().trim_suffix("."))
	return names


func test_the_pools_are_the_adrs_word_for_word() -> void:
	if not FileAccess.file_exists(ADR):
		return
	var text: String = _adr()
	assert_int(BOOK.pools.size()).is_equal(POOLS.size())
	var index: int = 0
	for label: String in POOLS:
		var line: RegExMatch = (
			RegEx.create_from_string("(?m)^\\*\\*%s\\.\\*\\* (.+)$" % label).search(text)
		)
		assert_array(BOOK.pools[index].names).is_equal(_list(line.get_string(1)))
		assert_int(BOOK.pools[index].first_generation).is_equal(POOLS[label])
		index += 1


func test_the_blocked_lists_are_the_adrs_word_for_word() -> void:
	if not FileAccess.file_exists(ADR):
		return
	var text: String = _adr()
	var every: RegExMatch = (
		RegEx
		. create_from_string("(?m)^\\*\\*Given names blocked with every surname\\.\\*\\*.*?: (.+)$")
		. search(text)
	)
	assert_array(BOOK.blocked_given).is_equal(_list(every.get_string(1)))
	var pairs: Array[String] = []
	var section: String = text.split("**Full names blocked as a pair**")[1].split("\n\n")[1]
	for line: String in section.split("\n"):
		if line.begins_with("- "):
			pairs.append_array(_list(line.split(": ", true, 1)[1]))
	assert_array(BOOK.blocked_pairs).is_equal(pairs)
	var offered: RegExMatch = RegEx.create_from_string("(?m)^- The 24: (.+?)\\. None").search(text)
	assert_array(BOOK.offered_surnames).is_equal(_list(offered.get_string(1)))


func test_every_pool_is_forty_capitalised_pinyin_names_none_blocked_or_twice() -> void:
	var pinyin: RegEx = RegEx.create_from_string("^[A-Z][a-z]+$")
	for pool: NamePool in BOOK.pools:
		assert_int(pool.names.size()).override_failure_message(pool.id).is_equal(POOL_SIZE)
		var seen: Dictionary[String, bool] = {}
		for given: String in pool.names:
			assert_object(pinyin.search(given)).override_failure_message(given).is_not_null()
			assert_bool(BOOK.blocked_given.has(given)).override_failure_message(given).is_false()
			assert_bool(seen.has(given)).override_failure_message(given).is_false()
			seen[given] = true


func test_the_offered_surnames_and_the_fallback_belong_to_no_village_family() -> void:
	assert_int(BOOK.offered_surnames.size()).is_equal(OFFERED)
	var village: Array[String] = []
	for family: FamilyDef in RunDefaults.VILLAGE.families:
		village.append(tr(family.name_key))
	for surname: String in BOOK.offered_surnames + [BOOK.fallback_surname]:
		assert_bool(village.has(surname)).override_failure_message(surname).is_false()
	# The fallback is no youth's either, so a run with no profile moves no youth's surname.
	for key: String in RunDefaults.VILLAGE.youth_surnames:
		assert_str(tr(key)).is_not_equal(BOOK.fallback_surname)


func test_generations_take_their_pools() -> void:
	var expected: Dictionary[int, int] = {0: 0, 1: 0, 2: 1, 3: 2, 4: 3, 5: 3, 9: 3}
	for generation: int in expected:
		assert_int(BOOK.pool_index(generation)).is_equal(expected[generation])


func test_a_blocked_name_is_blocked_with_its_surname_alone() -> void:
	assert_bool(BOOK.blocked("Zhang", "Zedong")).is_true()
	assert_bool(BOOK.blocked("Wang", "Ming")).is_true()
	assert_bool(BOOK.blocked("Zhang", "Ming")).is_false()
	assert_bool(BOOK.blocked("Li", "Jianguo")).is_true()
	assert_bool(BOOK.blocked("Wang", "Jianguo")).is_false()
