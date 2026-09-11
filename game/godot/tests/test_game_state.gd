extends "res://tests/base_test.gd"
## GameState: three mayor meters (Task 5).

const GS := preload("res://scripts/game_state.gd")

# ~111 195 m per degree latitude; ~73 990 m per degree longitude at 48.306° N.
const VENUE_LAT := 48.306
const VENUE_LON := 14.284


## One venue with a tree ~20 m north, a fountain ~100 m north, a toilet ~100 m east.
func _data() -> Dictionary:
	return {
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


func _decision(entity_id: String, entity_type: String, decision_id: String, cost: float) -> Dictionary:
	return { "entity_id": entity_id, "entity_type": entity_type, "decision_id": decision_id, "day": 1, "cost": cost }


func test_distance_is_haversine_meters() -> void:
	var d: float = GS._distance_m(VENUE_LAT, VENUE_LON, VENUE_LAT + 0.0009, VENUE_LON)
	check(absf(d - 100.0) < 1.0, "0.0009° latitude should be ~100 m, got %.2f" % d)
	check(GS._distance_m(VENUE_LAT, VENUE_LON, VENUE_LAT, VENUE_LON) == 0.0, "same point should be 0 m")


func test_create_returns_fresh_state() -> void:
	var a: Dictionary = GS.create()
	check(a.day == 1, "day should start at 1")
	check(a.budget == GS.CONFIG.start_budget, "budget should start at start_budget")
	a.decisions.append(_decision("t1", "tree", "cut", 400.0))
	a.shuttles.append({ "lat": VENUE_LAT, "lon": VENUE_LON })
	var b: Dictionary = GS.create()
	check(b.decisions.is_empty() and b.shuttles.is_empty(), "create() must not share arrays between states")


func test_fresh_state_meters_in_range() -> void:
	var m: Dictionary = GS.compute_meters(GS.create(), _data())
	for key: String in ["attendance", "money", "happiness"]:
		check(m.has(key), "missing meter %s" % key)
		var value: float = m.get(key, -1.0)
		check(value >= 0.0 and value <= 100.0, "%s out of range: %s" % [key, value])
	check(m.get("money", 0.0) > 50.0, "fresh money should be > 50, got %s" % m.get("money"))


func test_fresh_state_expected_values() -> void:
	var m: Dictionary = GS.compute_meters(GS.create(), _data())
	# 50 base + 20 fountains + 20 toilets + 15 trees kept + 0.9 shade, clamped.
	check(is_equal_approx(m.happiness, 100.0), "fresh happiness should clamp to 100, got %s" % m.happiness)
	# Single isolated venue, no shuttle: base only.
	check(is_equal_approx(m.attendance, 40.0), "fresh attendance should be 40, got %s" % m.attendance)
	# (50000 + 0.4 * 20000) / 70000
	check(absf(m.money - 82.857) < 0.01, "fresh money should be ~82.86, got %s" % m.money)


func test_cutting_tree_lowers_happiness() -> void:
	var data := _data()
	var fresh: Dictionary = GS.compute_meters(GS.create(), data)
	var state: Dictionary = GS.create()
	state.decisions.append({ "entity_id": "t1", "entity_type": "tree", "decision_id": "cut", "day": 3, "cost": 200.0 })
	var m: Dictionary = GS.compute_meters(state, data)
	check(m.happiness < fresh.happiness, "cut should lower happiness: %s -> %s" % [fresh.happiness, m.happiness])
	# 50 + 20 + 20 + 0 (0% kept) + 0 shade - 10 (cut within 50 m of venue)
	check(is_equal_approx(m.happiness, 80.0), "happiness after cut should be 80, got %s" % m.happiness)


func test_cost_decisions_lower_money() -> void:
	var data := _data()
	var fresh: Dictionary = GS.compute_meters(GS.create(), data)
	var state: Dictionary = GS.create()
	state.decisions.append(_decision("f1", "fountain", "relocate", 800.0))
	state.decisions.append(_decision("v1", "venue", "shuttle", 1200.0))
	var m: Dictionary = GS.compute_meters(state, data)
	check(m.money < fresh.money, "costs should lower money: %s -> %s" % [fresh.money, m.money])


func test_money_clamps_at_zero() -> void:
	var state: Dictionary = GS.create()
	state.decisions.append(_decision("v1", "venue", "shuttle", 1000000.0))
	var m: Dictionary = GS.compute_meters(state, _data())
	check(m.money == 0.0, "money should clamp to 0, got %s" % m.money)


func test_closing_only_fountain_lowers_happiness() -> void:
	var data := _data()
	var fresh: Dictionary = GS.compute_meters(GS.create(), data)
	var state: Dictionary = GS.create()
	state.decisions.append(_decision("f1", "fountain", "close", 0.0))
	var m: Dictionary = GS.compute_meters(state, data)
	check(m.happiness < fresh.happiness, "closing fountain should lower happiness: %s -> %s" % [fresh.happiness, m.happiness])


func test_decision_ids_are_scoped_by_entity_type() -> void:
	var data := _data()
	data.toilets[0].id = "f1"  # same id as the fountain, different type
	var state: Dictionary = GS.create()
	state.decisions.append(_decision("f1", "fountain", "close", 0.0))
	var m: Dictionary = GS.compute_meters(state, data)
	# Fountain closed (-20) but the toilet with the same id stays open: 50 + 20 + 15 + 0.9
	check(absf(m.happiness - 85.9) < 0.01, "only the fountain should close, got happiness %s" % m.happiness)


func test_shuttle_near_venue_raises_attendance() -> void:
	var data := _data()
	var fresh: Dictionary = GS.compute_meters(GS.create(), data)
	var state: Dictionary = GS.create()
	state.shuttles.append({ "lat": VENUE_LAT, "lon": VENUE_LON })
	var m: Dictionary = GS.compute_meters(state, data)
	check(m.attendance > fresh.attendance, "shuttle should raise attendance: %s -> %s" % [fresh.attendance, m.attendance])
	check(is_equal_approx(m.attendance, 100.0), "fully reachable venue should give 100, got %s" % m.attendance)


func test_shuttle_out_of_radius_does_not_count() -> void:
	var state: Dictionary = GS.create()
	state.shuttles.append({ "lat": VENUE_LAT + 0.0045, "lon": VENUE_LON })  # ~500 m away
	var m: Dictionary = GS.compute_meters(state, _data())
	check(is_equal_approx(m.attendance, 40.0), "far shuttle should not help, got %s" % m.attendance)


func test_clustered_venues_are_reachable() -> void:
	var data := _data()
	data.venues.append({ "id": "v2", "name": "Lentos", "lat": VENUE_LAT + 0.0009, "lon": VENUE_LON, "events": 5, "event_weight": 5 })
	var m: Dictionary = GS.compute_meters(GS.create(), data)
	check(is_equal_approx(m.attendance, 100.0), "venues ~100 m apart should reach each other, got %s" % m.attendance)


func test_empty_data_does_not_crash() -> void:
	var empty := { "venues": [], "trees": [], "fountains": [], "toilets": [], "streets": [], "meta": {} }
	var m: Dictionary = GS.compute_meters(GS.create(), empty)
	for key: String in ["attendance", "money", "happiness"]:
		var value: float = m.get(key, -1.0)
		check(value >= 0.0 and value <= 100.0, "%s out of range on empty data: %s" % [key, value])
