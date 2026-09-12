extends "res://tests/base_test.gd"
## GameState.build_index(): the geometry that follows from the data alone. Scoring must not depend
## on whether a caller passes one — the index only saves work (a click previews five or six
## decisions, each scoring the whole city).

const GS := preload("res://scripts/game_state.gd")

const LAT := 48.306
const LON := 14.284


func _data() -> Dictionary:
	var trees: Array = []
	for i in 40:  # a ring of trees, only the first few within SHADE_RADIUS_M of a venue
		trees.append({ "id": "t%d" % i, "lat": LAT + 0.0004 * i, "lon": LON, "species": "Tilia cordata",
			"height_m": 15.0, "crown_m": 8.0, "age_estimate": 60 })
	return {
		"venues": [
			{ "id": "H", "name": "Hauptplatz", "lat": LAT, "lon": LON, "events": 30, "event_weight": 20 },
			{ "id": "S", "name": "PopUp Store", "lat": LAT + 0.012, "lon": LON, "events": 4, "event_weight": 5 },
		],
		"trees": trees,
		"fountains": [{ "id": "f1", "lat": LAT + 0.0009, "lon": LON }],
		"toilets": [{ "id": "wc1", "lat": LAT, "lon": LON + 0.00135 }],
		"streets": [], "meta": {},
	}


func _states(data: Dictionary) -> Array:
	var fresh: Dictionary = GS.create()
	var busy: Dictionary = GS.create()
	GS.decide(busy, GS.find_entity(data, "H", "venue"), "shuttle")
	GS.decide(busy, GS.find_entity(data, "t0", "tree"), "cut")
	GS.decide(busy, GS.find_entity(data, "t1", "tree"), "trim")
	GS.decide(busy, GS.find_entity(data, "H", "venue"), "plant")
	GS.next_day(busy)
	GS.decide(busy, GS.find_entity(data, "wc1", "toilet"), "relocate")
	GS.next_day(busy)
	return [fresh, busy]


func test_index_covers_every_venue_and_only_nearby_trees() -> void:
	var data := _data()
	var index := GS.build_index(data)
	check(index.shade_by_venue.size() == 2 and index.venues.size() == 2, "one tree list per scorable venue: %s" % [index.shade_by_venue.keys()])
	check(index.trees.size() == 40 and index.trees_by_id.size() == 40, "the index carries the filtered collections")
	for tree: Dictionary in index.shade_trees:
		var near := false
		for venue: Dictionary in index.venues:
			near = near or GS._distance_m(venue.lat, venue.lon, tree.lat, tree.lon) <= GS.SHADE_RADIUS_M
		check(near, "%s is in shade_trees but not near a venue" % tree.id)
	check(index.shade_trees.size() < index.trees.size(), "far trees stay out: %d of %d" % [index.shade_trees.size(), index.trees.size()])


func test_scoring_is_identical_with_and_without_an_index() -> void:
	var data := _data()
	var index := GS.build_index(data)
	for state: Dictionary in _states(data):
		var plain: Dictionary = GS.compute_meters(state, data)
		var indexed: Dictionary = GS.compute_meters(state, data, index)
		for key: String in ["attendance", "money", "happiness"]:
			check(is_equal_approx(plain[key], indexed[key]), "%s must not depend on the index: %.4f vs %.4f" % [key, plain[key], indexed[key]])
		for day in [1, 2, 3]:
			var a: Dictionary = GS.petition_for_day(state, data, day)
			var b: Dictionary = GS.petition_for_day(state, data, day, index)
			check(a == b, "petition of day %d must not depend on the index" % day)
		var entity := GS.find_entity(data, "H", "venue")
		check(GS.preview_decisions(state, data, entity) == GS.preview_decisions(state, data, entity, index),
			"previews must not depend on the index")


## The real extract is where the index earns its keep (400 trees, 20 venues).
func test_real_data_scoring_is_identical() -> void:
	var data := {}
	for key: String in ["venues", "trees", "fountains", "toilets", "streets"]:
		var path := "res://data/" + key + ".json"
		if not FileAccess.file_exists(path):
			print("  SKIP test_real_data_scoring_is_identical: no extracted data yet")
			return
		data[key] = JSON.parse_string(FileAccess.get_file_as_string(path))
	var index := GS.build_index(data)
	var state: Dictionary = GS.create()
	GS.decide(state, GS.find_entity(data, str(data.venues[0].id), "venue"), "shuttle")
	GS.next_day(state)
	GS.next_day(state)
	var plain: Dictionary = GS.compute_meters(state, data)
	var indexed: Dictionary = GS.compute_meters(state, data, index)
	for key: String in ["attendance", "money", "happiness"]:
		check(is_equal_approx(plain[key], indexed[key]), "real data %s: %.4f vs %.4f" % [key, plain[key], indexed[key]])
	check(GS.petitions_until(state, data, 3) == GS.petitions_until(state, data, 3, index), "real petitions match")
