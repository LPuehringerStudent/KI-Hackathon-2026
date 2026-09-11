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
	# base + fountains + toilets + shade (12 m crown / SHADE_FULL_CROWN_M); expectations follow the constants
	check(is_equal_approx(m.happiness, (GS.HAPPINESS_BASE + GS.FOUNTAIN_WEIGHT + GS.TOILET_WEIGHT + GS.SHADE_WEIGHT * 12.0 / GS.SHADE_FULL_CROWN_M)), "fresh happiness, got %s" % m.happiness)
	# Single isolated venue, no shuttle: ISOLATED_REACH.
	check(is_equal_approx(m.attendance, 100.0 * GS.ISOLATED_REACH), "fresh attendance, got %s" % m.attendance)
	# (start_budget + reach * max income) / (start_budget + max income)
	check(is_equal_approx(m.money, (100.0 * (GS.CONFIG.start_budget - 0.0 + GS.ISOLATED_REACH * GS.MAX_VISITOR_INCOME) / (GS.CONFIG.start_budget + GS.MAX_VISITOR_INCOME))), "fresh money, got %s" % m.money)


func test_cutting_tree_lowers_happiness() -> void:
	var data := _data()
	var fresh: Dictionary = GS.compute_meters(GS.create(), data)
	var state: Dictionary = GS.create()
	state.decisions.append({ "entity_id": "t1", "entity_type": "tree", "decision_id": "cut", "day": 3, "cost": 200.0 })
	var m: Dictionary = GS.compute_meters(state, data)
	check(m.happiness < fresh.happiness, "cut should lower happiness: %s -> %s" % [fresh.happiness, m.happiness])
	# base + fountains + toilets + 0 shade - cut penalty - near-venue penalty
	check(is_equal_approx(m.happiness, GS.HAPPINESS_BASE + GS.FOUNTAIN_WEIGHT + GS.TOILET_WEIGHT - GS.CUT_PENALTY - GS.CUT_NEAR_VENUE_PENALTY),
		"happiness after cut, got %s" % m.happiness)


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
	# Fountain closed but the toilet with the same id stays open
	check(is_equal_approx(m.happiness, (GS.HAPPINESS_BASE + GS.FOUNTAIN_WEIGHT + GS.TOILET_WEIGHT + GS.SHADE_WEIGHT * 12.0 / GS.SHADE_FULL_CROWN_M) - GS.FOUNTAIN_WEIGHT), "only the fountain should close, got happiness %s" % m.happiness)


func test_shuttle_near_venue_raises_attendance() -> void:
	var data := _data()
	var fresh: Dictionary = GS.compute_meters(GS.create(), data)
	var state: Dictionary = GS.create()
	state.shuttles.append({ "lat": VENUE_LAT, "lon": VENUE_LON })
	var m: Dictionary = GS.compute_meters(state, data)
	check(m.attendance > fresh.attendance, "shuttle should raise attendance: %s -> %s" % [fresh.attendance, m.attendance])
	check(is_equal_approx(m.attendance, 100.0 * GS.SHUTTLE_REACH), "shuttle-served venue should give SHUTTLE_REACH, got %s" % m.attendance)


func test_shuttle_out_of_radius_does_not_count() -> void:
	var state: Dictionary = GS.create()
	state.shuttles.append({ "lat": VENUE_LAT + 0.0045, "lon": VENUE_LON })  # ~500 m away
	var m: Dictionary = GS.compute_meters(state, _data())
	check(is_equal_approx(m.attendance, 100.0 * GS.ISOLATED_REACH), "far shuttle should not help, got %s" % m.attendance)


func test_clustered_venues_are_reachable() -> void:
	var data := _data()
	data.venues.append({ "id": "v2", "name": "Lentos", "lat": VENUE_LAT + 0.0009, "lon": VENUE_LON, "events": 5, "event_weight": 5 })
	var m: Dictionary = GS.compute_meters(GS.create(), data)
	check(is_equal_approx(m.attendance, 100.0 * GS.CLUSTER_REACH), "clustered venues should get CLUSTER_REACH, got %s" % m.attendance)


func test_empty_data_does_not_crash() -> void:
	var empty := { "venues": [], "trees": [], "fountains": [], "toilets": [], "streets": [], "meta": {} }
	var m: Dictionary = GS.compute_meters(GS.create(), empty)
	for key: String in ["attendance", "money", "happiness"]:
		var value: float = m.get(key, -1.0)
		check(value >= 0.0 and value <= 100.0, "%s out of range on empty data: %s" % [key, value])


func test_closing_service_is_continuous_not_a_cliff() -> void:
	var data := _data()
	data.venues.append({ "id": "v2", "name": "Posthof", "lat": VENUE_LAT + 0.009, "lon": VENUE_LON, "events": 25, "event_weight": 30 })
	data.toilets.append({ "id": "wc2", "name": "WC Posthof", "lat": VENUE_LAT + 0.009, "lon": VENUE_LON })
	var fresh: Dictionary = GS.compute_meters(GS.create(), data)
	var state: Dictionary = GS.create()
	state.decisions.append(_decision("wc1", "toilet", "close", 0.0))
	var m: Dictionary = GS.compute_meters(state, data)
	# v1 carries 10 of 40 event_weight: losing its toilet costs 25 * 10/40
	check(is_equal_approx(fresh.happiness - m.happiness, 6.25), "closing wc1 should cost 6.25, got %s" % (fresh.happiness - m.happiness))


func test_relocating_service_moves_it_to_heaviest_uncovered_venue() -> void:
	var data := _data()
	data.venues.append({ "id": "v2", "name": "Posthof", "lat": VENUE_LAT + 0.009, "lon": VENUE_LON, "events": 25, "event_weight": 30 })
	var fresh: Dictionary = GS.compute_meters(GS.create(), data)
	var state: Dictionary = GS.create()
	state.decisions.append(_decision("wc1", "toilet", "relocate", 800.0))
	var m: Dictionary = GS.compute_meters(state, data)
	# wc1 leaves v1 (10) for v2 (30): toilet coverage 10/40 -> 30/40
	check(is_equal_approx(m.happiness - fresh.happiness, 12.5), "relocation should add 25 * 20/40, got %s" % (m.happiness - fresh.happiness))


func test_relocating_never_lowers_coverage() -> void:
	var data := _data()
	data.toilets.append({ "id": "wc2", "name": "WC 2", "lat": VENUE_LAT, "lon": VENUE_LON - 0.001 })
	var fresh: Dictionary = GS.compute_meters(GS.create(), data)
	var state: Dictionary = GS.create()
	state.decisions.append(_decision("wc1", "toilet", "relocate", 0.0))
	var m: Dictionary = GS.compute_meters(state, data)
	check(is_equal_approx(m.happiness, fresh.happiness), "all venues covered: relocation keeps happiness, %s -> %s" % [fresh.happiness, m.happiness])

	# wc1 alone covers v1 (10) and v3 (10); the only uncovered venue v2 weighs 15 — moving would lose 5.
	data = _data()
	data.venues.append({ "id": "v3", "name": "Nachbar", "lat": VENUE_LAT - 0.0005, "lon": VENUE_LON, "events": 10, "event_weight": 10 })
	data.venues.append({ "id": "v2", "name": "Posthof", "lat": VENUE_LAT + 0.009, "lon": VENUE_LON, "events": 15, "event_weight": 15 })
	fresh = GS.compute_meters(GS.create(), data)
	m = GS.compute_meters(state, data)
	check(is_equal_approx(m.happiness, fresh.happiness), "relocation must not trade 20 covered weight for 15, %s -> %s" % [fresh.happiness, m.happiness])


func test_trim_halves_shade_without_penalty() -> void:
	var state: Dictionary = GS.create()
	state.decisions.append(_decision("t1", "tree", "trim", 150.0))
	var m: Dictionary = GS.compute_meters(state, _data())
	# shade 20 * (6 m / 200) = 0.6 instead of 1.2
	check(is_equal_approx(m.happiness, (GS.HAPPINESS_BASE + GS.FOUNTAIN_WEIGHT + GS.TOILET_WEIGHT + GS.SHADE_WEIGHT * 12.0 / GS.SHADE_FULL_CROWN_M) - GS.SHADE_WEIGHT * 12.0 / GS.SHADE_FULL_CROWN_M * (1.0 - GS.TRIM_SHADE_FACTOR)),
		"trimmed tree should give TRIM_SHADE_FACTOR of its shade, got %s" % m.happiness)


func test_cutting_distant_tree_costs_base_penalty() -> void:
	var data := _data()
	data.trees.append({ "id": "t2", "lat": VENUE_LAT + 0.009, "lon": VENUE_LON, "species": "Acer", "height_m": 10.0, "crown_m": 20.0, "age_estimate": null })
	var fresh: Dictionary = GS.compute_meters(GS.create(), data)
	var state: Dictionary = GS.create()
	state.decisions.append(_decision("t2", "tree", "cut", 400.0))
	var m: Dictionary = GS.compute_meters(state, data)
	check(is_equal_approx(fresh.happiness - m.happiness, GS.CUT_PENALTY), "distant cut should cost CUT_PENALTY, got %s" % (fresh.happiness - m.happiness))


func test_keep_listen_bonus_is_capped() -> void:
	var data := _data()
	var state: Dictionary = GS.create()
	state.decisions.append(_decision("t1", "tree", "keep", 0.0))
	check(is_equal_approx(GS.compute_meters(state, data).happiness, (GS.HAPPINESS_BASE + GS.FOUNTAIN_WEIGHT + GS.TOILET_WEIGHT + GS.SHADE_WEIGHT * 12.0 / GS.SHADE_FULL_CROWN_M) + GS.LISTEN_BONUS), "one keep adds LISTEN_BONUS")
	for i in 10:
		state.decisions.append(_decision("far%d" % i, "tree", "keep", 0.0))
	check(is_equal_approx(GS.compute_meters(state, data).happiness, (GS.HAPPINESS_BASE + GS.FOUNTAIN_WEIGHT + GS.TOILET_WEIGHT + GS.SHADE_WEIGHT * 12.0 / GS.SHADE_FULL_CROWN_M) + GS.LISTEN_BONUS_MAX), "listen bonus capped")


func test_latest_decision_per_entity_is_in_effect() -> void:
	var data := _data()
	var state: Dictionary = GS.create()
	state.decisions.append(_decision("f1", "fountain", "close", 0.0))
	state.decisions.append(_decision("f1", "fountain", "keep", 0.0))
	var m: Dictionary = GS.compute_meters(state, data)
	# reopened (+25 back) and heard (+1)
	check(is_equal_approx(m.happiness, (GS.HAPPINESS_BASE + GS.FOUNTAIN_WEIGHT + GS.TOILET_WEIGHT + GS.SHADE_WEIGHT * 12.0 / GS.SHADE_FULL_CROWN_M) + GS.LISTEN_BONUS), "keep after close should reopen the fountain, got %s" % m.happiness)


func test_pedestrian_street_near_venue_raises_attendance_until_reopened() -> void:
	var data := _data()
	data.streets.append({ "id": "s1", "name": "Landstraße", "history": "", "lat": VENUE_LAT, "lon": VENUE_LON + 0.001 })
	var state: Dictionary = GS.create()
	state.decisions.append(_decision("s1", "street", "pedestrian", 300.0))
	check(is_equal_approx(GS.compute_meters(state, data).attendance, 100.0 * (GS.ISOLATED_REACH + GS.PEDESTRIAN_REACH_BONUS)), "isolated + pedestrian bonus")
	state.decisions.append(_decision("s1", "street", "open", 0.0))
	check(is_equal_approx(GS.compute_meters(state, data).attendance, 100.0 * GS.ISOLATED_REACH), "reopening removes the bonus")
