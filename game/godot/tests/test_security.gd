extends "res://tests/base_test.gd"
## Round 8: deterministic security risk and incidents.

const GS := preload("res://scripts/game_state.gd")

const LAT := 48.306
const LON := 14.284


## Big venue B (weight 20) and small venue S (weight 5), each with a fountain and toilet.
func _data() -> Dictionary:
	return {
		"venues": [
			{ "id": "B", "name": "Ars Electronica Center", "lat": LAT, "lon": LON, "events": 40, "event_weight": 20 },
			{ "id": "S", "name": "PopUp Store", "lat": LAT + 0.009, "lon": LON, "events": 5, "event_weight": 5 },
		],
		"trees": [], "streets": [],
		"fountains": [{ "id": "fB", "lat": LAT + 0.0005, "lon": LON }, { "id": "fS", "lat": LAT + 0.0095, "lon": LON }],
		"toilets": [{ "id": "wB", "lat": LAT, "lon": LON + 0.0007 }, { "id": "wS", "lat": LAT + 0.009, "lon": LON + 0.0007 }],
		"meta": {},
	}


func _demand(weight: float) -> int:
	return maxi(1, roundi(weight / GS.SECURITY_UNITS_PER_WEIGHT))


func _state_on_day(day: int, security_at_B := 0) -> Dictionary:
	var state: Dictionary = GS.create()
	for i in security_at_B:
		GS.decide(state, GS.find_entity(_data(), "B", "venue"), "security")
	for i in day - 1:
		GS.next_day(state)
	return state


func test_risk_formula() -> void:
	var big := { "event_weight": 20.0 }
	check(is_equal_approx(GS.security_risk(big, 0), 1.0), "uncovered full crowd is maximum risk, got %f" % GS.security_risk(big, 0))
	check(GS.security_risk(big, _demand(20.0)) == 0.0, "full coverage is no risk")
	check(GS.security_risk(big, 99) == 0.0, "more units than demand stay at zero")
	var small := { "event_weight": 5.0 }
	check(is_equal_approx(GS.security_risk(small, 0), 5.0 / GS.SECURITY_RISK_FULL_CROWD), "small crowd, small risk: %f" % GS.security_risk(small, 0))
	check(GS.security_risk({}, 0) == 0.0 and GS.security_risk({ "event_weight": "x" }, 0) == 0.0, "invalid venue -> 0")
	check(GS.security_risk(big, -3) == GS.security_risk(big, 0), "negative units count as none")
	# monotone: more units never raise the risk
	var previous := 1.1
	for units in range(0, _demand(20.0) + 2):
		var risk := GS.security_risk(big, units)
		check(risk <= previous, "risk must not rise with more units (%d: %f)" % [units, risk])
		previous = risk


func test_incident_threshold_and_first_day() -> void:
	var data := _data()
	check(GS.security_incidents(_state_on_day(1), data).is_empty(), "day 1 is a grace day")
	var incidents := GS.security_incidents(_state_on_day(2), data)
	check(incidents.size() == 1 and incidents[0].venue_id == "B", "only the big venue is over the threshold: %s" % [incidents])
	check(incidents[0].venue_name == "Ars Electronica Center" and incidents[0].risk >= GS.SECURITY_INCIDENT_THRESHOLD, "incident carries name and risk: %s" % incidents[0])
	check(GS.security_incidents(_state_on_day(2, _demand(20.0)), data).is_empty(), "staffing the venue clears it")
	check(GS.security_risk({ "event_weight": GS.SECURITY_INCIDENT_THRESHOLD * GS.SECURITY_RISK_FULL_CROWD }, 0) >= GS.SECURITY_INCIDENT_THRESHOLD,
		"a venue exactly at the threshold weight counts as an incident")


func test_incidents_are_deterministic_and_idempotent() -> void:
	var data := _data()
	var state := _state_on_day(3)
	check(GS.security_incidents(state, data) == GS.security_incidents(state, data), "same inputs, same list")
	var first: Dictionary = GS.compute_meters(state, data)
	var second: Dictionary = GS.compute_meters(state, data)
	check(is_equal_approx(first.happiness, second.happiness) and is_equal_approx(first.attendance, second.attendance),
		"repeated scoring does not stack incident penalties")
	check(state == _state_on_day(3), "scoring never mutates the state")


func test_incident_penalties_scale_with_the_crowd_behind_them() -> void:
	var data := _data()
	var day1: Dictionary = GS.compute_meters(_state_on_day(1), data)
	var day2: Dictionary = GS.compute_meters(_state_on_day(2), data)
	# B carries 20 of 25 event weight -> 0.8 of the caps
	var share: float = 20.0 / 25.0
	check(is_equal_approx(day1.happiness - day2.happiness, GS.INCIDENT_HAPPINESS_CAP * share), "happiness penalty by crowd share: %.2f" % (day1.happiness - day2.happiness))
	check(is_equal_approx(day1.attendance - day2.attendance, GS.INCIDENT_ATTENDANCE_CAP * share), "attendance penalty by crowd share: %.2f" % (day1.attendance - day2.attendance))
	var staffed: Dictionary = GS.compute_meters(_state_on_day(2, _demand(20.0)), data)
	check(staffed.happiness > day2.happiness and staffed.attendance > day2.attendance, "clearing the incident buys both back")


func test_shortfall_penalty_applies_before_any_incident() -> void:
	var data := _data()
	var empty: Dictionary = GS.compute_meters(_state_on_day(1), data)
	var staffed: Dictionary = GS.compute_meters(_state_on_day(1, _demand(20.0)), data)
	var share: float = float(_demand(20.0)) / float(_demand(20.0) + _demand(5.0))
	check(is_equal_approx(staffed.happiness - empty.happiness, GS.SECURITY_SHORTFALL_CAP * share),
		"day 1 has no incidents, but staffing still nudges happiness: %+.2f" % (staffed.happiness - empty.happiness))


## The closing text must not name one venue when the stock is spread over several.
func test_subtitle_counts_spread_out_purchases() -> void:
	var data := _data()
	var single: Dictionary = GS.create()
	check(GS.decide(single, GS.find_entity(data, "B", "venue"), "security"), "security at the big venue")
	check(GS.verdict_subtitle(single, data).contains("1 Security-Team am Ars Electronica Center."),
		"one venue is named: %s" % GS.verdict_subtitle(single, data))
	var spread: Dictionary = single.duplicate(true)
	check(GS.decide(spread, GS.find_entity(data, "S", "venue"), "security"), "security at the small venue")
	check(GS.verdict_subtitle(spread, data).contains("2 Security-Teams an 2 Spielstätten."),
		"spread stock is counted, not attributed: %s" % GS.verdict_subtitle(spread, data))
