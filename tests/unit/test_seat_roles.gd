extends GdUnitTestSuite
## The two peasant seats act differently, and the behavior follows the seat.

const HAND: String = "6Q99KK"
const LANDLORD: String = "5789TJ"
const OTHER: String = "3456789"


func test_the_upstream_peasant_blocks_a_landlord_single() -> void:
	var play: BotPlay = BotScript.decide([LANDLORD, OTHER, HAND], ["5", ""])
	assert_str(BotScript.text_of(play)).is_equal("Q")


func test_the_downstream_peasant_sheds_cheaply() -> void:
	var play: BotPlay = BotScript.decide([LANDLORD, HAND, OTHER], ["5"])
	assert_str(BotScript.text_of(play)).is_equal("6")


func test_the_upstream_peasant_blocks_with_an_ace_or_a_two() -> void:
	var high: BotPlay = BotScript.decide([LANDLORD, OTHER, "62"], ["5", ""])
	assert_str(BotScript.text_of(high)).is_equal("2")
	var ace: BotPlay = BotScript.decide([LANDLORD, OTHER, "6A99"], ["5", ""])
	assert_str(BotScript.text_of(ace)).is_equal("A")


func test_the_downstream_peasant_saves_its_aces_and_twos() -> void:
	var play: BotPlay = BotScript.decide([LANDLORD, "A2KK99", OTHER], ["5"])
	assert_str(BotScript.text_of(play)).is_equal("9")


func test_the_upstream_peasant_feeds_its_teammate() -> void:
	var seats: Array[String] = ["3TJQKA", "4TJQKA", "5345679K"]
	var play: BotPlay = BotScript.decide(seats, ["3", "4", "5", "", ""])
	assert_str(BotScript.text_of(play)).is_equal("9")


func test_the_downstream_peasant_leads_to_shed_low_cards() -> void:
	var seats: Array[String] = ["3TJQKA", "5345679K", "4TJQKA"]
	var play: BotPlay = BotScript.decide(seats, ["3", "5", "", ""])
	assert_str(BotScript.text_of(play)).is_equal("34567")


func test_swapping_the_seats_swaps_the_behaviors() -> void:
	var as_upstream: BotPlay = BotScript.decide([HAND, LANDLORD, OTHER], ["5", ""], 1)
	assert_str(BotScript.text_of(as_upstream)).is_equal("Q")
	var as_downstream: BotPlay = BotScript.decide([OTHER, LANDLORD, HAND], ["5"], 1)
	assert_str(BotScript.text_of(as_downstream)).is_equal("6")
