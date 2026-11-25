extends GdUnitTestSuite
## ADR 0037's session file: written when a copy opens, written again at each beat,
## removed when it closes and only by the copy that wrote it; a file left unwritten past
## the stale beats, or one cut off, is a copy that stopped.

const FOLDER: String = "user://test_session_file"
const PARAMS: SessionParams = preload("res://data/session/session_params.tres")

var _file: SessionFile


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute(FOLDER)
	_file = SessionFile.new(PARAMS, FOLDER.path_join("session.json"))
	_file.end()
	if FileAccess.file_exists(_file.path()):
		DirAccess.remove_absolute(_file.path())


func after_test() -> void:
	if FileAccess.file_exists(_file.path()):
		DirAccess.remove_absolute(_file.path())


func _beat_on_disk() -> float:
	var written: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_file.path()))
	return written[SessionFile.BEAT_KEY]


func test_the_file_is_written_beaten_and_removed() -> void:
	var now: float = 1_000_000.0
	assert_int(_file.look(now)).is_equal(SessionFile.Found.NONE)
	assert_int(_file.begin(now)).is_equal(OK)
	assert_bool(_file.is_mine()).is_true()
	assert_int(_file.look(now + PARAMS.beat_seconds)).is_equal(SessionFile.Found.LIVE)
	assert_float(_beat_on_disk()).is_equal(now)
	assert_int(_file.beat(now + PARAMS.beat_seconds)).is_equal(OK)
	assert_float(_beat_on_disk()).is_equal(now + PARAMS.beat_seconds)
	_file.end()
	assert_bool(FileAccess.file_exists(_file.path())).is_false()
	assert_bool(_file.is_mine()).is_false()


func test_a_file_unwritten_past_the_stale_beats_is_a_copy_that_stopped() -> void:
	var now: float = 2_000_000.0
	_file.begin(now)
	assert_int(_file.look(now + PARAMS.stale_after())).is_equal(SessionFile.Found.LIVE)
	assert_int(_file.look(now + PARAMS.stale_after() + 1.0)).is_equal(SessionFile.Found.STALE)
	# A beat ahead of the clock, as after the clock was set back, still looks open.
	assert_int(_file.look(now - 3600.0)).is_equal(SessionFile.Found.LIVE)


func test_a_file_cut_off_as_its_copy_stopped_is_stale() -> void:
	var written: FileAccess = FileAccess.open(_file.path(), FileAccess.WRITE)
	written.store_string('{"started": 1, "be')
	written.close()
	assert_int(_file.look(0.0)).is_equal(SessionFile.Found.STALE)


## A second copy that never began leaves the first copy's file where it is.
func test_only_the_copy_that_began_the_file_removes_it() -> void:
	var first: SessionFile = SessionFile.new(PARAMS, _file.path())
	first.begin(10.0)
	_file.end()
	assert_bool(FileAccess.file_exists(_file.path())).is_true()
	first.end()
	assert_bool(FileAccess.file_exists(_file.path())).is_false()
