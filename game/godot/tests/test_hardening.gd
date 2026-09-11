extends "res://tests/base_test.gd"
## GameState edge cases (Sprint 2, B3): malformed data or state must not corrupt the meters,
## and a rejected decide() must leave the state untouched.
## Note: a GDScript runtime error does not abort the run — the failing function returns a default
## and the caller continues — so every case asserts the exact expected result, not just "no crash".

const GS := preload("res://scripts/game_state.gd")

const VENUE_LAT := 48.306
const VENUE_LON := 14.284


## Same fixture as test_game_state.gd: fresh meters attendance 40 / money 76 / happiness 71.2.
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


func _same_meters(a: Variant, b: Variant) -> bool:
	if not (a is Dictionary and b is Dictionary):
		return false
	for key: String in ["attendance", "money", "happiness"]:
		if not (a.has(key) and b.has(key) and is_equal_approx(a[key], b[key])):
			return false
	return true


func _expect_fixture_meters(data: Dictionary, label: String, state: Dictionary = GS.create()) -> void:
	var m: Variant = GS.compute_meters(state, data)
	check(_same_meters(m, GS.compute_meters(GS.create(), _data())), "%s: expected fixture meters 40/76/71.2, got %s" % [label, m])


func test_invalid_records_are_ignored() -> void:
	var cases := {
		"venue with null event_weight": func(d): d.venues.append({ "id": "v9", "lat": VENUE_LAT + 0.0003, "lon": VENUE_LON, "event_weight": null }),
		"venue with string event_weight": func(d): d.venues.append({ "id": "v9", "lat": VENUE_LAT + 0.0003, "lon": VENUE_LON, "event_weight": "10" }),
		"venue without lat": func(d): d.venues.append({ "id": "v9", "lon": VENUE_LON, "event_weight": 10 }),
		"tree with null lat": func(d): d.trees.append({ "id": "t9", "lat": null, "lon": VENUE_LON, "crown_m": 50.0 }),
		"toilet with NaN lon": func(d): d.toilets.append({ "id": "wc9", "lat": VENUE_LAT, "lon": NAN }),
		"fountain that is not a dict": func(d): d.fountains.append("f9"),
		"street without position": func(d): d.streets.append({ "id": "s9", "name": "Landstraße" }),
	}
	for label: String in cases:
		var data := _data()
		cases[label].call(data)
		_expect_fixture_meters(data, label)


func test_null_or_missing_collections_count_as_empty() -> void:
	var expected: Dictionary = GS.compute_meters(GS.create(), {})
	for label: String in ["null arrays", "missing keys"]:
		var data := { "venues": null, "trees": null, "fountains": null, "toilets": null, "streets": null } if label == "null arrays" else {}
		var m: Variant = GS.compute_meters(GS.create(), data)
		check(_same_meters(m, expected), "%s should equal empty data, got %s" % [label, m])
	check(is_equal_approx(expected.money, 60.0) and expected.attendance == 0.0, "empty data: money 60, attendance 0, got %s" % expected)


func test_empty_state_scores_like_a_fresh_game() -> void:
	_expect_fixture_meters(_data(), "state {}", {})


func test_malformed_decision_records_do_not_corrupt_meters() -> void:
	var state: Dictionary = GS.create()
	state.decisions.append({ "entity_id": "f1", "entity_type": "fountain" })  # no decision_id, no cost
	state.decisions.append("close f1")
	state.decisions.append({ "entity_id": "x", "entity_type": "tree", "decision_id": "keep" })  # no cost
	var m: Dictionary = GS.compute_meters(state, _data())
	check(is_equal_approx(m.money, 76.0), "missing costs count as 0, money should stay 76, got %s" % m.money)
	check(is_equal_approx(m.happiness, 72.2), "only the valid keep counts (+1), got %s" % m.happiness)


func test_numeric_ids_match_their_string_form() -> void:
	var data := _data()
	data.trees[0].id = 42
	var state: Dictionary = GS.create()
	state.decisions.append({ "entity_id": 42, "entity_type": "tree", "decision_id": "cut", "day": 1, "cost": 400 })
	# 20 + 25 + 25 - 2 - 6 (tree 42 cut next to the venue)
	check(is_equal_approx(GS.compute_meters(state, data).happiness, 62.0), "int ids should work, got %s" % GS.compute_meters(state, data).happiness)
	var entity := GS.find_entity(data, "42", "tree")
	check(entity.get("type") == "tree", "find_entity should find an int id by its string form")


func test_rejected_decide_leaves_state_untouched() -> void:
	var cases := {
		"venue without position": { "type": "venue", "id": "v9" },
		"entity without id": { "type": "tree", "lat": VENUE_LAT, "lon": VENUE_LON },
		"empty entity": {},
	}
	for label: String in cases:
		var state: Dictionary = GS.create()
		var decision_id := "shuttle" if label == "venue without position" else "cut"
		check(GS.decide(state, cases[label], decision_id) == false, "%s: decide should return false" % label)
		check(state == GS.create(), "%s: state must be unchanged, got %s" % [label, state])


func test_decide_on_invalid_state_returns_false() -> void:
	var venue := GS.find_entity(_data(), "v1", "venue")
	var state := {}
	check(GS.decide(state, venue, "shuttle") == false, "decide on {} should return false")
	check(state.is_empty(), "invalid state must not be half-filled")


func test_next_day_on_invalid_state_is_a_no_op() -> void:
	var state := {}
	GS.next_day(state)
	check(state.is_empty(), "next_day on {} should not add keys, got %s" % state)


func test_click_spam_on_one_entity_charges_once() -> void:
	var data := _data()
	var state: Dictionary = GS.create()
	var toilet := GS.find_entity(data, "wc1", "toilet")
	var accepted := 0
	for i in 50:
		if GS.decide(state, toilet, "relocate"):
			accepted += 1
	check(accepted == 1 and state.decisions.size() == 1, "50 identical clicks should record once, got %d" % accepted)
	check(is_equal_approx(state.budget, 14200.0), "and charge 800 once, budget %s" % state.budget)


func test_decision_after_day_change_records_new_day() -> void:
	var state: Dictionary = GS.create()
	var fountain := GS.find_entity(_data(), "f1", "fountain")
	GS.next_day(state)
	GS.next_day(state)
	GS.next_day(state)
	check(GS.decide(state, fountain, "close"), "decision on day 3")
	check(state.decisions[-1].day == 3, "a decision taken after the day advanced belongs to the new day")
