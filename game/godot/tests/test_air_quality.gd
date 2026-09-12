extends "res://tests/base_test.gd"
## GameState: Day-3 air quality modifier (Sprint 2, B1).
## PM10 <= 20 µg/m³ -> +10 happiness, >= 50 -> -10, linear between; day 3 only; missing data -> 0.

const GS := preload("res://scripts/game_state.gd")

const VENUE_LAT := 48.306
const VENUE_LON := 14.284


## Same fixture as test_game_state.gd; _fresh() is its day-1 happiness derived from the constants.
func _data(air: Variant = null) -> Dictionary:
	var data := {
		"venues": [
			{ "id": "v1", "name": "Hauptplatz", "lat": VENUE_LAT, "lon": VENUE_LON, "events": 10, "event_weight": 10 },
		],
		"trees": [
			{ "id": "t1", "lat": VENUE_LAT + 0.00018, "lon": VENUE_LON, "species": "Tilia cordata",
				"height_m": 15.0, "crown_m": 12.0, "age_estimate": null },
		],
		"fountains": [{ "id": "f1", "name": "Trinkbrunnen", "lat": VENUE_LAT + 0.0009, "lon": VENUE_LON }],
		"toilets": [{ "id": "wc1", "name": "WC-Anlage", "lat": VENUE_LAT, "lon": VENUE_LON + 0.00135 }],
		"streets": [],
		"meta": {},
	}
	if air != null:
		data["airquality"] = air
	return data


func _fresh() -> float:
	return (GS.HAPPINESS_BASE + GS.FOUNTAIN_WEIGHT + GS.TOILET_WEIGHT + GS.SHADE_WEIGHT * 12.0 / GS.SHADE_FULL_CROWN_M - GS.SECURITY_SHORTFALL_CAP)


func _air(pm10: Variant) -> Dictionary:
	return { "station": "S184 Stadtpark", "measured_at": "2026-09-11T08:30:00+00:00", "pm10": pm10, "pm25": 4.7, "source": "test" }


func _state_on_day(day: int) -> Dictionary:
	var state: Dictionary = GS.create()
	for i in day - 1:
		GS.next_day(state)
	return state


func _happiness(day: int, data: Dictionary) -> float:
	return GS.compute_meters(_state_on_day(day), data).happiness


func test_clean_air_adds_ten_on_day_three() -> void:
	check(is_equal_approx(_happiness(3, _data(_air(6.7))), minf(100.0, _fresh() + GS.AIR_MODIFIER)), "PM10 6.7 on day 3 should add AIR_MODIFIER, got %s" % _happiness(3, _data(_air(6.7))))


func test_modifier_only_applies_on_day_three() -> void:
	for day: int in [1, 2]:
		check(is_equal_approx(_happiness(day, _data(_air(6.7))), _fresh()), "day %d must ignore air quality, got %s" % [day, _happiness(day, _data(_air(6.7)))])
		check(is_equal_approx(_happiness(day, _data(_air(90.0))), _fresh()), "day %d must ignore bad air too" % day)


func test_modifier_curve() -> void:
	var expected := { 0.0: 10.0, 20.0: 10.0, 27.5: 5.0, 35.0: 0.0, 42.5: -5.0, 50.0: -10.0, 120.0: -10.0 }
	for pm10: float in expected:
		var modifier: float = GS.air_quality_modifier(_state_on_day(3), _data(_air(pm10)))
		check(is_equal_approx(modifier, expected[pm10]), "PM10 %.1f -> %+.1f expected, got %+.2f" % [pm10, expected[pm10], modifier])


func test_integer_pm10_from_json_is_accepted() -> void:
	check(is_equal_approx(GS.air_quality_modifier(_state_on_day(3), _data(_air(35))), 0.0), "int PM10 35 should work like 35.0")


func test_missing_or_malformed_air_quality_is_neutral() -> void:
	var cases := {
		"no airquality key": _data(),
		"pm10 null": _data(_air(null)),
		"pm10 string": _data(_air("6.7")),
		"pm10 NaN": _data(_air(NAN)),
		"pm10 negative": _data(_air(-5.0)),
		"airquality not a dict": _data([6.7]),
		"airquality without pm10": _data({ "station": "S184" }),
	}
	for label: String in cases:
		var state := _state_on_day(3)
		check(GS.air_quality_modifier(state, cases[label]) == 0.0, "%s should give modifier 0" % label)
		check(is_equal_approx(GS.compute_meters(state, cases[label]).happiness, _fresh()), "%s should leave happiness unchanged" % label)


func test_bonus_adds_on_top_of_a_full_score() -> void:
	var data := _data(_air(5.0))
	var state := _state_on_day(3)
	data.trees[0].crown_m = 400.0  # full shade
	var full: float = GS.HAPPINESS_BASE + GS.FOUNTAIN_WEIGHT + GS.TOILET_WEIGHT + GS.SHADE_WEIGHT - GS.SECURITY_SHORTFALL_CAP
	var m: Dictionary = GS.compute_meters(state, data)
	check(is_equal_approx(m.happiness, minf(100.0, full + GS.AIR_MODIFIER)), "full score plus clean air (clamped), got %s" % m.happiness)


func test_bad_air_can_push_happiness_down_but_not_below_zero() -> void:
	var data := _data(_air(80.0))
	data.fountains.clear()
	data.toilets.clear()
	var state := _state_on_day(3)
	state.decisions.append({ "entity_id": "t1", "entity_type": "tree", "decision_id": "cut", "day": 3, "cost": 400.0 })
	# base + shade - air before the cut (fountains/toilets removed)
	var before := GS.HAPPINESS_BASE + GS.SHADE_WEIGHT * 12.0 / GS.SHADE_FULL_CROWN_M - GS.AIR_MODIFIER - GS.SECURITY_SHORTFALL_CAP
	check(is_equal_approx(GS.compute_meters(_state_on_day(3), data).happiness, clampf(before, 0.0, 100.0)), "bad air on day 3 should subtract AIR_MODIFIER")
	for i in 10:  # enough felled trees next to the venue to go far below zero
		data.trees.append({ "id": "c%d" % i, "lat": VENUE_LAT, "lon": VENUE_LON + 0.0001, "species": "Acer", "height_m": 9.0, "crown_m": 1.0, "age_estimate": null })
		state.decisions.append({ "entity_id": "c%d" % i, "entity_type": "tree", "decision_id": "cut", "day": 3, "cost": 400.0 })
	check(GS.compute_meters(state, data).happiness == 0.0, "happiness must clamp at 0")


func test_modifier_does_not_touch_attendance_or_money() -> void:
	var clean: Dictionary = GS.compute_meters(_state_on_day(3), _data(_air(5.0)))
	var none: Dictionary = GS.compute_meters(_state_on_day(3), _data())
	check(is_equal_approx(clean.attendance, none.attendance) and is_equal_approx(clean.money, none.money), "air quality affects happiness only")
