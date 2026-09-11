extends "res://tests/base_test.gd"
## GameState.verdict_title: tier thresholds and precedence.

const GS := preload("res://scripts/game_state.gd")


func _title(attendance: float, money: float, happiness: float) -> String:
	return GS.verdict_title({ "attendance": attendance, "money": money, "happiness": happiness })


func _expect(attendance: float, money: float, happiness: float, expected: String) -> void:
	var title := _title(attendance, money, happiness)
	check(title == expected, "%.1f/%.1f/%.1f -> expected %s, got %s" % [attendance, money, happiness, expected, title])


func test_gold_needs_all_strong_and_a_high_average() -> void:
	_expect(67, 67, 73, "Goldene:r Bürgermeister:in")          # average 69.0 (inclusive)
	_expect(67, 67, 72.9, "Volksnahe Stadtplanung")             # average 68.97
	_expect(66, 90, 90, "Solide Verwaltung")                    # 66 is not > 66


func test_volksnahe_is_strictly_above_66() -> void:
	_expect(66.1, 66.1, 66.1, "Volksnahe Stadtplanung")
	_expect(66.0, 67, 67, "Solide Verwaltung")


func test_existing_quadrant_endings_keep_precedence() -> void:
	_expect(40, 70, 49.9, "Effizienz-Tyrann:in")
	_expect(40, 70, 50.0, "Stadt im Gleichgewicht")
	_expect(40, 49.9, 70, "Beliebt, aber pleite")
	_expect(70, 60, 60, "Gastgeber:in der Stadt")
	_expect(70, 20, 60, "Gastgeber:in der Stadt")               # quadrant endings beat the crisis tier
	_expect(20, 70, 40, "Effizienz-Tyrann:in")


func test_crisis_below_35_on_any_meter() -> void:
	_expect(34.9, 60, 60, "Stadt in Schieflage")
	_expect(60, 60, 34.9, "Stadt in Schieflage")
	_expect(35.0, 60, 60, "Stadt im Gleichgewicht")


func test_solid_needs_every_meter_at_55() -> void:
	_expect(55, 55, 55, "Solide Verwaltung")
	_expect(54.9, 60, 60, "Stadt im Gleichgewicht")
	_expect(60, 66, 60, "Solide Verwaltung")


func test_untouched_city_band_stays_neutral() -> void:
	# The real untouched day-3 city (45 / 75 / 55..75) must not get a tier of its own.
	for happiness: float in [55.0, 65.0, 75.0]:
		_expect(45, 75, happiness, "Stadt im Gleichgewicht")


func test_missing_meters_count_as_zero() -> void:
	check(GS.verdict_title({}) == "Stadt in Schieflage", "empty meters are a crisis, not a crash")


func test_main_delegates_to_game_state() -> void:
	var main_script := preload("res://scripts/main.gd")
	check(main_script.verdict_title({ "attendance": 55, "money": 55, "happiness": 55 }) == "Solide Verwaltung", "main.gd uses the same tiers")
