extends "res://tests/base_test.gd"
## GameState: day machine and decisions (Task 6).

const GS := preload("res://scripts/game_state.gd")

const VENUE_LAT := 48.306
const VENUE_LON := 14.284


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
		"streets": [{ "id": "s1", "name": "Landstraße", "history": "", "lat": VENUE_LAT, "lon": VENUE_LON + 0.001 }],
		"meta": {},
	}


func _ids(decisions: Array) -> Array:
	return decisions.map(func(d): return d.id)


func test_day_themes() -> void:
	var expected := {
		1: ["Tag 1 — Anreise", "Mobilität"],
		2: ["Tag 2 — Höhepunkt", "Sanitär & Wasser"],
		3: ["Tag 3 — Hitzetag", "Schatten & Bäume"],
	}
	for day: int in expected:
		var theme: Dictionary = GS.day_theme(day)
		check(theme.get("title") == expected[day][0], "day %d title: %s" % [day, theme.get("title")])
		check(theme.get("focus") == expected[day][1], "day %d focus: %s" % [day, theme.get("focus")])
		check(theme.get("hint", "") != "", "day %d needs a hint" % day)
	check(GS.day_theme(1).hint == "Wo sollen Shuttle fahren?", "day 1 hint per plan")


func test_day_theme_clamps_out_of_range() -> void:
	check(GS.day_theme(0).title == GS.day_theme(1).title, "day 0 should fall back to day 1")
	check(GS.day_theme(7).title == GS.day_theme(3).title, "day 7 should fall back to day 3")


func test_next_day_advances_and_caps_at_three() -> void:
	var state: Dictionary = GS.create()
	GS.next_day(state)
	check(state.day == 2, "day should be 2, got %s" % state.day)
	GS.next_day(state)
	GS.next_day(state)
	check(state.day == 3, "day should cap at 3, got %s" % state.day)


func test_available_decisions_per_type() -> void:
	var data := _data()
	var tree: Dictionary = GS.find_entity(data, "t1", "tree")
	check(_ids(GS.available_decisions(tree)) == ["trim", "cut"], "tree ids: %s" % [_ids(GS.available_decisions(tree))])
	for type: String in ["fountain", "toilet"]:
		var entity := { "id": "x", "type": type, "lat": VENUE_LAT, "lon": VENUE_LON }
		check(_ids(GS.available_decisions(entity)) == ["relocate", "close"], "%s ids (reopen only once closed)" % type)
	check(_ids(GS.available_decisions(GS.find_entity(data, "v1", "venue"))) == ["shuttle", "extend", "plant"], "venue ids (no purchases below HEADLINE_MIN_EVENTS, curfew only once extended)")
	check(_ids(GS.available_decisions(GS.find_entity(data, "s1", "street"))) == ["pedestrian", "plant"], "street ids (open only once pedestrian)")
	check(GS.available_decisions({ "id": "x", "type": "ufo" }).is_empty(), "unknown type has no decisions")
	check(GS.available_decisions({ "id": "t1" }).is_empty(), "entity without type has no decisions")


func test_decision_shape_and_costs() -> void:
	var costs := {}
	for type: String in ["tree", "fountain", "venue", "street"]:
		for d: Dictionary in GS.available_decisions({ "id": "x", "type": type }):
			for key: String in ["id", "label", "cost", "adds_shuttle"]:
				check(d.has(key), "%s/%s missing %s" % [type, d.get("id"), key])
			costs["%s/%s" % [type, d.id]] = d.cost
	check(not costs.has("tree/keep") and costs.get("tree/trim") == 150.0 and costs.get("tree/cut") == 400.0, "tree costs: %s" % costs)
	check(costs.get("fountain/relocate") == 800.0 and costs.get("fountain/close") == -300.0, "service costs (closing refunds operating costs): %s" % costs)
	check(costs.get("venue/shuttle") == 1800.0 and costs.get("venue/plant") == 300.0, "venue costs: %s" % costs)
	check(costs.get("street/pedestrian") == 300.0 and costs.get("street/plant") == 300.0, "street costs: %s" % costs)
	var shuttle: Dictionary = GS.available_decisions({ "id": "x", "type": "venue" })[0]
	check(shuttle.adds_shuttle == true, "venue shuttle adds a shuttle")


func test_available_decisions_returns_copies() -> void:
	var tree := { "id": "t1", "type": "tree" }
	var first: Array = GS.available_decisions(tree)
	first[0].cost = 99999.0
	first.clear()
	check(GS.available_decisions(tree).size() == 2 and GS.available_decisions(tree)[0].cost == 150.0, "catalog must not be mutable by callers")


func test_find_entity() -> void:
	var data := _data()
	var tree: Dictionary = GS.find_entity(data, "t1", "tree")
	check(tree.get("type") == "tree" and tree.get("species") == "Tilia cordata", "found tree: %s" % tree)
	check(not data.trees[0].has("type"), "find_entity must not modify data")
	check(GS.find_entity(data, "nope", "tree").is_empty(), "missing id returns {}")
	check(GS.find_entity(data, "t1", "ufo").is_empty(), "unknown type returns {}")


func test_decide_records_decision_and_spends_budget() -> void:
	var state: Dictionary = GS.create()
	GS.next_day(state)
	GS.next_day(state)
	var tree: Dictionary = GS.find_entity(_data(), "t1", "tree")
	check(GS.decide(state, tree, "cut") == true, "first cut should succeed")
	check(state.decisions.size() == 1, "one decision recorded")
	check(state.decisions[0] == { "entity_id": "t1", "entity_type": "tree", "decision_id": "cut", "day": 3, "cost": 400.0 },
		"record: %s" % [state.decisions[0] if state.decisions.size() > 0 else null])
	check(is_equal_approx(state.budget, GS.CONFIG.start_budget - 400.0), "budget should drop by 400, got %s" % state.budget)


func test_decide_same_decision_twice_is_rejected() -> void:
	var state: Dictionary = GS.create()
	var fountain: Dictionary = GS.find_entity(_data(), "f1", "fountain")
	check(GS.decide(state, fountain, "relocate") == true, "first relocate should succeed")
	check(GS.decide(state, fountain, "relocate") == false, "second identical relocate should be rejected")
	check(state.decisions.size() == 1, "rejected decision must not be recorded")
	check(is_equal_approx(state.budget, GS.CONFIG.start_budget - 800.0), "rejected decision must not spend, budget %s" % state.budget)


func test_decide_rejects_unknown_decision_and_untyped_entity() -> void:
	var state: Dictionary = GS.create()
	check(GS.decide(state, GS.find_entity(_data(), "t1", "tree"), "shuttle") == false, "shuttle is not a tree decision")
	check(GS.decide(state, { "id": "t1", "lat": VENUE_LAT, "lon": VENUE_LON }, "cut") == false, "entity without type")
	check(state.decisions.is_empty() and state.budget == GS.CONFIG.start_budget, "state must be unchanged")


func test_shuttle_decision_adds_shuttle_at_venue() -> void:
	var data := _data()
	var state: Dictionary = GS.create()
	var before: Dictionary = GS.compute_meters(state, data)
	check(GS.decide(state, GS.find_entity(data, "v1", "venue"), "shuttle") == true, "shuttle should succeed")
	check(state.shuttles == [{ "lat": VENUE_LAT, "lon": VENUE_LON }], "shuttle at venue coords: %s" % [state.shuttles])
	var after: Dictionary = GS.compute_meters(state, data)
	check(after.attendance > before.attendance, "shuttle should raise attendance: %s -> %s" % [before.attendance, after.attendance])


func test_non_shuttle_decision_adds_no_shuttle() -> void:
	var state: Dictionary = GS.create()
	GS.decide(state, GS.find_entity(_data(), "s1", "street"), "pedestrian")
	check(state.shuttles.is_empty(), "street decision must not add shuttles")


func test_decide_and_money_meter_count_costs_once() -> void:
	var data := _data()
	var state: Dictionary = GS.create()
	GS.decide(state, GS.find_entity(data, "v1", "venue"), "shuttle")
	var m: Dictionary = GS.compute_meters(state, data)
	# The single fixture venue is also the day-1 Bürgeranliegen, so the shuttle earns its grant:
	# (start - 1800 + SHUTTLE_REACH * max income + PETITION_GRANT) / (start + max income)
	check(is_equal_approx(m.money, (100.0 * (GS.CONFIG.start_budget - 1800.0 + GS.SHUTTLE_REACH * GS.MAX_VISITOR_INCOME + GS.PETITION_GRANT) / (GS.CONFIG.start_budget + GS.MAX_VISITOR_INCOME))), "cost counted once, got %s" % m.money)


func test_changing_a_decision_is_allowed_and_costs_again() -> void:
	var state: Dictionary = GS.create()
	var toilet: Dictionary = GS.find_entity(_data(), "wc1", "toilet")
	check(not GS.decide(state, toilet, "reopen"), "nothing to reopen while open")
	check(GS.decide(state, toilet, "close"), "close")
	check(GS.decide(state, toilet, "reopen"), "reopen after close")
	check(GS.decide(state, toilet, "close"), "close again once no longer in effect")
	check(state.decisions.size() == 3 and is_equal_approx(state.budget, GS.CONFIG.start_budget + 300.0 - 100.0 + 300.0), "every change is recorded and paid, budget %s" % state.budget)


func test_felled_tree_accepts_no_further_decisions() -> void:
	var state: Dictionary = GS.create()
	var tree: Dictionary = GS.find_entity(_data(), "t1", "tree")
	check(GS.decide(state, tree, "cut"), "cut")
	check(not GS.decide(state, tree, "trim"), "a felled tree cannot be trimmed")
	check(state.decisions.size() == 1, "rejected decisions not recorded")
