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

const CONFIG := { "start_budget": 50000.0, "visitor_spend": 35.0, "walk_radius": 300.0, "shuttle_radius": 250.0 }

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

## Visitor income at 100 % attendance and the reference spend of 35 € per visitor.
const MAX_VISITOR_INCOME := 20000.0
const REFERENCE_SPEND := 35.0
const EARTH_RADIUS_M := 6371000.0

## Share of venue event_weight that must be covered for the service bonus.
const COVERAGE_THRESHOLD := 0.7
const SHADE_RADIUS_M := 150.0
## Total uncut crown diameter near venues that counts as full shade.
const SHADE_FULL_CROWN_M := 200.0
const CUT_PENALTY_RADIUS_M := 50.0
const VENUE_CLUSTER_RADIUS_M := 200.0


static func create() -> Dictionary:
	return { "day": 1, "budget": CONFIG.start_budget, "decisions": [], "shuttles": [] }


## Copy of the Data record `id` in data["<type>s"] with "type" added, or {} if not found.
static func find_entity(data: Dictionary, id: String, type: String) -> Dictionary:
	if not DECISIONS.has(type):
		return {}
	for record: Dictionary in data.get(type + "s", []):
		if record.get("id") == id:
			var entity := record.duplicate(true)
			entity["type"] = type
			return entity
	return {}


## [{ id, label, cost, adds_shuttle }] for the entity's type; [] for unknown or missing type.
## Every type is always available — the day focus only changes the hint.
static func available_decisions(entity: Dictionary) -> Array:
	return DECISIONS.get(entity.get("type", ""), []).duplicate(true)


## Records the decision and spends its cost. Returns false (state unchanged) if the decision
## isn't available for the entity or this exact entity+decision was already taken.
static func decide(state: Dictionary, entity: Dictionary, decision_id: String) -> bool:
	var matches := available_decisions(entity).filter(func(d): return d.id == decision_id)
	if matches.is_empty():
		return false
	for taken: Dictionary in state.decisions:
		if taken.entity_type == entity.type and taken.entity_id == entity.id and taken.decision_id == decision_id:
			return false
	var decision: Dictionary = matches[0]
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


static func next_day(state: Dictionary) -> void:
	state.day = mini(LAST_DAY, state.day + 1)


## { title, focus, hint } — days outside 1..LAST_DAY clamp to the nearest day.
static func day_theme(day: int) -> Dictionary:
	return DAY_THEMES[clampi(day, 1, LAST_DAY)].duplicate()


static func compute_meters(state: Dictionary, data: Dictionary) -> Dictionary:
	var venues: Array = data.get("venues", [])
	var trees: Array = data.get("trees", [])
	var closed_fountains := _decided_ids(state, "fountain", "close")
	var closed_toilets := _decided_ids(state, "toilet", "close")
	var cut_trees := _decided_ids(state, "tree", "cut")

	var open_fountains: Array = data.get("fountains", []).filter(func(f): return not closed_fountains.has(f.id))
	var open_toilets: Array = data.get("toilets", []).filter(func(t): return not closed_toilets.has(t.id))
	var uncut_trees: Array = trees.filter(func(t): return not cut_trees.has(t.id))

	var happiness := 50.0
	if _coverage_score(venues, open_fountains, CONFIG.walk_radius) >= COVERAGE_THRESHOLD:
		happiness += 20.0
	if _coverage_score(venues, open_toilets, CONFIG.walk_radius) >= COVERAGE_THRESHOLD:
		happiness += 20.0
	var uncut_share := 1.0 if trees.is_empty() else float(uncut_trees.size()) / trees.size()
	if uncut_share > 0.8:
		happiness += 15.0
	happiness += 15.0 * _shade_score(venues, uncut_trees)
	for tree: Dictionary in trees:
		if cut_trees.has(tree.id) and _near_any(tree, venues, CUT_PENALTY_RADIUS_M):
			happiness -= 10.0

	var attendance := 40.0 + 60.0 * _reachability(state, venues)

	return {
		"attendance": clampf(attendance, 0.0, 100.0),
		"money": clampf(_money_score(state, clampf(attendance, 0.0, 100.0)), 0.0, 100.0),
		"happiness": clampf(happiness, 0.0, 100.0),
	}


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


## 0..1: uncut crown diameter within SHADE_RADIUS_M of any venue, SHADE_FULL_CROWN_M = full.
static func _shade_score(venues: Array, uncut_trees: Array) -> float:
	var crown := 0.0
	for tree: Dictionary in uncut_trees:
		if tree.get("crown_m") != null and _near_any(tree, venues, SHADE_RADIUS_M):
			crown += float(tree.crown_m)
	return minf(1.0, crown / SHADE_FULL_CROWN_M)


## Share (0..1) of event_weight at venues with a shuttle within shuttle_radius
## or another venue within VENUE_CLUSTER_RADIUS_M.
static func _reachability(state: Dictionary, venues: Array) -> float:
	var total := 0.0
	var reachable := 0.0
	for venue: Dictionary in venues:
		var weight := float(venue.event_weight)
		total += weight
		if _near_any(venue, state.shuttles, CONFIG.shuttle_radius) or _near_any(venue, venues, VENUE_CLUSTER_RADIUS_M):
			reachable += weight
	return reachable / total if total > 0.0 else 0.0


## Net money as 0..100 (unclamped). Costs come from the decision log, not state.budget,
## so they are counted once even though decide() also deducts them from budget.
static func _money_score(state: Dictionary, attendance: float) -> float:
	var costs := 0.0
	for decision: Dictionary in state.decisions:
		costs += float(decision.cost)
	var income: float = attendance / 100.0 * MAX_VISITOR_INCOME * CONFIG.visitor_spend / REFERENCE_SPEND
	var net: float = CONFIG.start_budget - costs + income
	return 100.0 * net / (CONFIG.start_budget + MAX_VISITOR_INCOME)


## Set of entity ids of the given type that have the given decision.
static func _decided_ids(state: Dictionary, entity_type: String, decision_id: String) -> Dictionary:
	var ids := {}
	for decision: Dictionary in state.decisions:
		if decision.entity_type == entity_type and decision.decision_id == decision_id:
			ids[decision.entity_id] = true
	return ids


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
