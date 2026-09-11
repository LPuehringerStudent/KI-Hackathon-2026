class_name GameState
extends RefCounted
## Pure game logic (no Nodes): game state and the three mayor meters.
## Contract: docs/superpowers/plans/2026-09-11-buergermeister-spiel-godot.md — Shared Interfaces.
##
## State:    { day: int, budget: float, decisions: Array, shuttles: Array }
## Decision: { entity_id, entity_type, decision_id, day, cost }
## Shuttle:  { lat, lon }
## Entity:   a Data record plus "type" ("venue" | "tree" | "fountain" | "toilet" | "street"),
##           as returned by find_entity() — the same type string map_view's entity_clicked emits.

const CONFIG := { "start_budget": 15000.0, "visitor_spend": 35.0, "walk_radius": 300.0, "shuttle_radius": 250.0 }

const LAST_DAY := 3

const DAY_THEMES := {
	1: { "title": "Tag 1 — Anreise", "focus": "Mobilität", "hint": "Wo sollen Shuttle fahren?" },
	2: { "title": "Tag 2 — Höhepunkt", "focus": "Sanitär & Wasser", "hint": "Reichen Toiletten und Trinkbrunnen für den Andrang?" },
	3: { "title": "Tag 3 — Hitzetag", "focus": "Schatten & Bäume", "hint": "Welche Bäume spenden den Besucher:innen Schatten?" },
}

## Decision catalogue per entity type. ids are what dialogue.gd emits in [[ENTSCHEID:<id>]].
const SERVICE_DECISIONS := [
	{ "id": "keep", "label": "Stehen lassen", "cost": 0.0, "adds_shuttle": false },
	{ "id": "relocate", "label": "Verlegen", "cost": 800.0, "adds_shuttle": false },
	{ "id": "close", "label": "Schließen", "cost": 0.0, "adds_shuttle": false },
]
const DECISIONS := {
	"tree": [
		{ "id": "keep", "label": "Stehen lassen", "cost": 0.0, "adds_shuttle": false },
		{ "id": "trim", "label": "Zurückschneiden", "cost": 150.0, "adds_shuttle": false },
		{ "id": "cut", "label": "Fällen", "cost": 400.0, "adds_shuttle": false },
	],
	"fountain": SERVICE_DECISIONS,
	"toilet": SERVICE_DECISIONS,
	"venue": [
		{ "id": "shuttle", "label": "Shuttle-Haltestelle einrichten", "cost": 1200.0, "adds_shuttle": true },
	],
	"street": [
		{ "id": "pedestrian", "label": "Für Fußgänger sperren", "cost": 300.0, "adds_shuttle": false },
		{ "id": "open", "label": "Freigeben", "cost": 0.0, "adds_shuttle": false },
	],
}

## Tuning constants — balanced against the real Innenstadt extract (20 venues, 400 trees,
## 38 fountains, 41 toilets) so every decision moves a meter without cliffs.

## Visitor income at 100 % attendance and the reference spend of 35 € per visitor.
const MAX_VISITOR_INCOME := 10000.0
const REFERENCE_SPEND := 35.0
const EARTH_RADIUS_M := 6371000.0

## Happiness = base + weight × (0..1 component) per term, minus cut penalties.
const HAPPINESS_BASE := 20.0
const FOUNTAIN_WEIGHT := 25.0
const TOILET_WEIGHT := 25.0
const SHADE_WEIGHT := 20.0
const SHADE_RADIUS_M := 150.0
## Total crown diameter near venues that counts as full shade.
const SHADE_FULL_CROWN_M := 200.0
## A trimmed tree still gives this share of its shade.
const TRIM_SHADE_FACTOR := 0.5
## Every felled tree costs happiness; more when it stood at a venue.
const CUT_PENALTY := 2.0
const CUT_NEAR_VENUE_PENALTY := 6.0
const CUT_PENALTY_RADIUS_M := 50.0
## "keep" after negotiating: people feel heard. Per decision, capped.
const LISTEN_BONUS := 1.0
const LISTEN_BONUS_MAX := 5.0

## Attendance = event-weighted share of demand realised, by how well each venue is connected.
const SHUTTLE_REACH := 1.0
const CLUSTER_REACH := 0.7
const ISOLATED_REACH := 0.4
const VENUE_CLUSTER_RADIUS_M := 200.0
const PEDESTRIAN_REACH_BONUS := 0.15
const PEDESTRIAN_RADIUS_M := 250.0

## Hitzetag air quality (data.airquality, PM10 in µg/m³ from tools/fetch_airquality.py):
## <= AIR_CLEAN_PM10 gives +AIR_MODIFIER happiness, >= AIR_POLLUTED_PM10 gives -AIR_MODIFIER,
## linear in between. Only on AIR_QUALITY_DAY; missing or invalid readings count as 0.
const AIR_QUALITY_DAY := 3
const AIR_CLEAN_PM10 := 20.0
const AIR_POLLUTED_PM10 := 50.0
const AIR_MODIFIER := 10.0


static func create() -> Dictionary:
	return { "day": 1, "budget": CONFIG.start_budget, "decisions": [], "shuttles": [] }


## Copy of the Data record `id` in data["<type>s"] with "type" added, or {} if not found.
## Ids compare by string form, so a numeric JSON id 42 is found as "42".
static func find_entity(data: Dictionary, id: String, type: String) -> Dictionary:
	if not DECISIONS.has(type):
		return {}
	var records: Variant = data.get(type + "s")
	if not (records is Array):
		return {}
	for record: Variant in records:
		if record is Dictionary and record.has("id") and str(record.id) == id:
			var entity: Dictionary = record.duplicate(true)
			entity["type"] = type
			return entity
	return {}


## [{ id, label, cost, adds_shuttle }] for the entity's type; [] for unknown or missing type.
## Every type is always available — the day focus only changes the hint.
static func available_decisions(entity: Dictionary) -> Array:
	return DECISIONS.get(entity.get("type", ""), []).duplicate(true)


## Records the decision and spends its cost. An entity's latest decision is the one in effect
## (e.g. "keep" reopens a closed toilet), but every decision's cost is spent.
## Returns false (state unchanged) if the decision isn't available for the entity, is already
## in effect for it, the entity is a felled tree, or state/entity are malformed (no id, or no
## position for a shuttle) — everything is validated before the state is touched.
static func decide(state: Dictionary, entity: Dictionary, decision_id: String) -> bool:
	if not _is_valid_state(state) or not entity.has("id"):
		return false
	var matches := available_decisions(entity).filter(func(d): return d.id == decision_id)
	if matches.is_empty():
		return false
	var current: String = _latest_decisions(state).get(_key(entity.type, entity.id), "")
	if current == decision_id or current == "cut":
		return false
	var decision: Dictionary = matches[0]
	if decision.adds_shuttle and not _has_position(entity):
		return false
	state.decisions.append({
		"entity_id": entity.id,
		"entity_type": entity.type,
		"decision_id": decision_id,
		"day": state.day,
		"cost": decision.cost,
	})
	state.budget -= decision.cost
	if decision.adds_shuttle:
		state.shuttles.append({ "lat": entity.lat, "lon": entity.lon })
	return true


## No-op for a state without a numeric day.
static func next_day(state: Dictionary) -> void:
	if _is_number(state.get("day")):
		state.day = mini(LAST_DAY, int(state.day) + 1)


## { title, focus, hint } — days outside 1..LAST_DAY clamp to the nearest day.
static func day_theme(day: int) -> Dictionary:
	return DAY_THEMES[clampi(day, 1, LAST_DAY)].duplicate()


## Records without an id or a finite lat/lon (and venues without a numeric event_weight) are
## ignored, as are malformed decision records — bad data degrades the score, never corrupts it.
static func compute_meters(state: Dictionary, data: Dictionary) -> Dictionary:
	var venues := _records(data, "venues").filter(
		func(v): return _is_number(v.get("event_weight")) and float(v.event_weight) >= 0.0)
	var trees := _records(data, "trees")
	var latest := _latest_decisions(state)
	var fountains := _effective_services(_records(data, "fountains"), "fountain", state, latest, venues)
	var toilets := _effective_services(_records(data, "toilets"), "toilet", state, latest, venues)
	var pedestrian_streets := _records(data, "streets").filter(
		func(s): return latest.get(_key("street", s.id)) == "pedestrian")

	var happiness := HAPPINESS_BASE
	happiness += FOUNTAIN_WEIGHT * _coverage_score(venues, fountains, CONFIG.walk_radius)
	happiness += TOILET_WEIGHT * _coverage_score(venues, toilets, CONFIG.walk_radius)
	happiness += SHADE_WEIGHT * _shade_score(venues, trees, latest)
	happiness -= _cut_penalty(venues, trees, latest)
	happiness += minf(LISTEN_BONUS_MAX, LISTEN_BONUS * latest.values().count("keep"))
	happiness += air_quality_modifier(state, data)

	var attendance := clampf(100.0 * _reachability(state, venues, pedestrian_streets), 0.0, 100.0)

	return {
		"attendance": attendance,
		"money": clampf(_money_score(state, attendance), 0.0, 100.0),
		"happiness": clampf(happiness, 0.0, 100.0),
	}


## Happiness modifier from the cached PM10 reading: +AIR_MODIFIER (clean) .. -AIR_MODIFIER (polluted)
## on AIR_QUALITY_DAY, 0 on other days or when data.airquality is missing or invalid.
static func air_quality_modifier(state: Dictionary, data: Dictionary) -> float:
	var air: Variant = data.get("airquality")
	if state.get("day") != AIR_QUALITY_DAY or not (air is Dictionary):
		return 0.0
	var pm10: Variant = air.get("pm10")
	if not (pm10 is float or pm10 is int) or is_nan(float(pm10)) or float(pm10) < 0.0:
		return 0.0
	var pollution := clampf(inverse_lerp(AIR_CLEAN_PM10, AIR_POLLUTED_PM10, float(pm10)), 0.0, 1.0)
	return lerpf(AIR_MODIFIER, -AIR_MODIFIER, pollution)


## Share (0..1) of total venue event_weight with an open service within radius.
static func _coverage_score(venues: Array, services: Array, radius: float) -> float:
	var total := 0.0
	var covered := 0.0
	for venue: Dictionary in venues:
		var weight := float(venue.event_weight)
		total += weight
		if _near_any(venue, services, radius):
			covered += weight
	return covered / total if total > 0.0 else 0.0


## Open services of one type at their effective positions. Closed ones are dropped; relocated ones
## move (in decision order) to the highest-weight venue left without that service in walk_radius,
## but only if that raises coverage — so a relocation never lowers it.
static func _effective_services(records: Array, type: String, state: Dictionary, latest: Dictionary, venues: Array) -> Array:
	var services: Array = records.filter(func(r): return latest.get(_key(type, r.id)) != "close")
	var moved := {}
	for decision: Dictionary in _decisions(state):
		var key := _key(decision.entity_type, decision.entity_id)
		if decision.entity_type != type or latest.get(key) != "relocate" or moved.has(key):
			continue
		moved[key] = true
		var index := services.find_custom(func(s): return str(s.id) == str(decision.entity_id))
		if index == -1:
			continue
		var others := services.duplicate()
		others.remove_at(index)
		var target := _heaviest_uncovered_venue(venues, others, CONFIG.walk_radius)
		if target.is_empty():
			continue
		var moved_services := services.duplicate()
		moved_services[index] = { "id": decision.entity_id, "lat": target.lat, "lon": target.lon }
		if _coverage_score(venues, moved_services, CONFIG.walk_radius) > _coverage_score(venues, services, CONFIG.walk_radius):
			services = moved_services
	return services


static func _heaviest_uncovered_venue(venues: Array, services: Array, radius: float) -> Dictionary:
	var best := {}
	for venue: Dictionary in venues:
		if not _near_any(venue, services, radius) and (best.is_empty() or venue.event_weight > best.event_weight):
			best = venue
	return best


## 0..1: crown diameter within SHADE_RADIUS_M of any venue (felled trees 0, trimmed
## TRIM_SHADE_FACTOR), SHADE_FULL_CROWN_M = full.
static func _shade_score(venues: Array, trees: Array, latest: Dictionary) -> float:
	var crown := 0.0
	for tree: Dictionary in trees:
		var decision: String = latest.get(_key("tree", tree.id), "")
		if decision == "cut" or not _is_number(tree.get("crown_m")) or not _near_any(tree, venues, SHADE_RADIUS_M):
			continue
		crown += float(tree.crown_m) * (TRIM_SHADE_FACTOR if decision == "trim" else 1.0)
	return minf(1.0, crown / SHADE_FULL_CROWN_M)


static func _cut_penalty(venues: Array, trees: Array, latest: Dictionary) -> float:
	var penalty := 0.0
	for tree: Dictionary in trees:
		if latest.get(_key("tree", tree.id)) == "cut":
			penalty += CUT_PENALTY
			if _near_any(tree, venues, CUT_PENALTY_RADIUS_M):
				penalty += CUT_NEAR_VENUE_PENALTY
	return penalty


## 0..1: event-weighted reach factor. A shuttle within shuttle_radius gives SHUTTLE_REACH; otherwise
## CLUSTER_REACH with another venue within VENUE_CLUSTER_RADIUS_M, else ISOLATED_REACH — plus
## PEDESTRIAN_REACH_BONUS near a pedestrianised street.
static func _reachability(state: Dictionary, venues: Array, pedestrian_streets: Array) -> float:
	var total := 0.0
	var reached := 0.0
	var shuttles := _positions(state.get("shuttles"))
	for venue: Dictionary in venues:
		var weight := float(venue.event_weight)
		var reach := ISOLATED_REACH
		if _near_any(venue, shuttles, CONFIG.shuttle_radius):
			reach = SHUTTLE_REACH
		elif _near_any(venue, venues, VENUE_CLUSTER_RADIUS_M):
			reach = CLUSTER_REACH
		if _near_any(venue, pedestrian_streets, PEDESTRIAN_RADIUS_M):
			reach += PEDESTRIAN_REACH_BONUS
		total += weight
		reached += weight * minf(1.0, reach)
	return reached / total if total > 0.0 else 0.0


## Net money as 0..100 (unclamped). Costs come from the decision log, not state.budget,
## so they are counted once even though decide() also deducts them from budget.
static func _money_score(state: Dictionary, attendance: float) -> float:
	var costs := 0.0
	for decision: Dictionary in _decisions(state):
		costs += float(decision.cost) if _is_number(decision.get("cost")) else 0.0
	var income: float = attendance / 100.0 * MAX_VISITOR_INCOME * CONFIG.visitor_spend / REFERENCE_SPEND
	var net: float = CONFIG.start_budget - costs + income
	return 100.0 * net / (CONFIG.start_budget + MAX_VISITOR_INCOME)


## The decision in effect per entity: { "<type>:<id>": decision_id }, later decisions win.
static func _latest_decisions(state: Dictionary) -> Dictionary:
	var latest := {}
	for decision: Dictionary in _decisions(state):
		latest[_key(decision.entity_type, decision.entity_id)] = decision.decision_id
	return latest


## "<type>:<id>" — ids by string form, so numeric JSON ids and their strings match.
static func _key(entity_type: Variant, entity_id: Variant) -> String:
	return str(entity_type) + ":" + str(entity_id)


## Well-formed decision records of the state (dicts with entity_type, entity_id and decision_id).
static func _decisions(state: Dictionary) -> Array:
	var decisions: Variant = state.get("decisions")
	if not (decisions is Array):
		return []
	return decisions.filter(func(d): return d is Dictionary and d.has("entity_type") and d.has("entity_id") and d.has("decision_id"))


## Scorable records of one data collection: dicts with an id and a finite lat/lon.
static func _records(data: Dictionary, key: String) -> Array:
	return _positions(data.get(key)).filter(func(r): return r.has("id"))


## Dicts with a finite lat/lon from a value that should be an Array (anything else -> []).
static func _positions(value: Variant) -> Array:
	if not (value is Array):
		return []
	return value.filter(func(r): return r is Dictionary and _has_position(r))


static func _has_position(record: Dictionary) -> bool:
	return _is_number(record.get("lat")) and _is_number(record.get("lon"))


static func _is_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


static func _is_valid_state(state: Dictionary) -> bool:
	return state.get("decisions") is Array and state.get("shuttles") is Array \
		and _is_number(state.get("day")) and _is_number(state.get("budget"))


## True if any of `others` (dicts with lat/lon) is within radius of point, ignoring point itself.
static func _near_any(point: Dictionary, others: Array, radius: float) -> bool:
	for other: Dictionary in others:
		if not is_same(other, point) and _distance_m(point.lat, point.lon, other.lat, other.lon) <= radius:
			return true
	return false


## Haversine distance in meters between two WGS84 points.
static func _distance_m(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
	var d_lat := deg_to_rad(lat2 - lat1)
	var d_lon := deg_to_rad(lon2 - lon1)
	var a := sin(d_lat / 2.0) ** 2 + cos(deg_to_rad(lat1)) * cos(deg_to_rad(lat2)) * sin(d_lon / 2.0) ** 2
	return 2.0 * EARTH_RADIUS_M * asin(minf(1.0, sqrt(a)))
