# Design Spec: "Bürgermeister:in fürs Festival" (working title)

**Event:** AI Hackathon, Ars Electronica Festival 2026 — "Linz neu entdecken" / NEGOTIATING HUMANITY
**Date:** 2026-09-11/12, Grand Garage, Tabakfabrik Linz
**Team:** 3 people · Status: approved design v2

## Concept

An interactive browser game: you are the mayor of Linz during festival week. The
city is a cast of characters — every tree, street, fountain, toilet, and festival
venue is clickable and *speaks*, with a persona grounded in its real open-data
record, via Mistral Medium 3.5 (through our local proxy). You negotiate with the
city entity by entity, day by day, and your decisions are scored against real data.
The official Festival Planner shows attendees where to go; our game makes you
responsible for the city they arrive in.

Theme fit: "negotiation" is the literal game mechanic, and the voices extend
humanity to non-human city dwellers — Negotiating Humanity played out in Linz's
own data.

## Game structure: 3 festival days

Each day has a distinct worry that re-weights the same underlying datasets
(no new data plumbing per day — different decision sets, personas, scoring).

| Day | Theme | Focus entities | Core tension |
|-----|-------|----------------|--------------|
| 1 — Anreise | Mobility | streets, transit stops, venues | Crowds arrive; where do shuttles run, what closes? |
| 2 — Höhepunkt | Sanitation & water | toilets, fountains, venues | Event density vs. coverage of visitor services |
| 3 — Hitzetag | Shade & climate | trees, air quality, drinking fountains | Heat + air quality; the trees become the main negotiation partners |

A day clock drives the arc. Decisions and scores persist across days.
Final: the three mayor meters (attendance, net money, happiness) with a mayor
title verdict + shareable summary.

## Core interaction loop

1. Map of central Linz (Leaflet, OSM tiles) with entities from the datasets.
2. Click an entity → chat panel opens with its Mistral persona, grounded in its
   actual record (tree: species/age/location; street: naming history; venue:
   festival program & event count).
3. The entity argues its case; the player decides (e.g. keep / prune / cut a tree;
   open / relocate / add a service point). Entities may push back once — one
   negotiation round per decision.
4. Score recomputed from real data after each decision; visible score panel.

## Data sources (all local snapshots in `data/`)

- Festival program dataset (`projects`, `locations`, `calendar`) — venues, events, crowds proxy = event count per venue/day
- Tree register (Baumkataster CSV) — species, positions (age estimated from trunk circumference if present)
- Street names + history CSVs — naming stories for street personas
- Drinking fountains, public toilets CSVs — service points
- Air quality live API (optional stretch) — Day 3 modifier

Preprocessing: `tools/extract_innenstadt.py` filters these by bounding box
(Innenstadt: Ars Electronica Center → Hauptplatz → Tabakfabrik) into small
`game/data/*.json`. Persona facts come only from these extracted records.

## Architecture

- Static browser app in `game/` — no build step: `index.html` + `style.css` + native ES modules
- Module ownership (one teammate each): `map.js` (Leaflet layers/markers), `dialogue.js` (persona prompt building, chat state, decision intents), `game.js` (day state machine, scoring, decisions); shared: `data.js`, `ui.js`, `score.js`, `voices.js` (proxy HTTP client)
- LLM path: browser → `mistral-proxy` (127.0.0.1:8377) → OpenRouter; model `mistralai/mistral-medium-3-5`
- Serve with `python3 -m http.server` (ES modules require http, not file://)

## Scoring: three mayor meters

The final verdict shows three meters everyone understands. Only happiness is
directly computable from the datasets; the other two are simulation outputs
fed by real data plus declared constants (all constants shown in the UI —
"real data in, honest model on top"):

- **Besucher:innen (attendance):** demand = event-weighted venue data from the
  festival calendar. Mobility/coverage decisions determine the realized share
  (reachable venue ≈ full demand, poorly connected venue = fraction).
- **Geld (net money):** declared starting city budget − declared unit costs of
  decisions + attendance × declared average visitor spend (constant justified
  by the tourism dataset: arrivals/overnights in Linz).
- **Zufriedenheit (happiness):** composite of real-data metrics — walking
  distance to open toilets/fountains (300 m haversine), heat-day shade from
  the tree register, trees kept vs. cut, air quality reading.

Components per day: service coverage (Day 2), mobility reach (Day 1),
environment/shade (Day 3). Meters update live after each decision; the
final verdict shows all three plus the mayor title earned (e.g.
"Beliebt aber pleite" / "Reich aber unbeliebt" quadrant endings).

## Error handling / demo robustness

- Proxy down / keys exhausted / offline → canned personas: pre-generate a voice
  line set per entity type via the proxy while it works, commit as
  `game/data/fallback_voices.json`; dialogue degrades gracefully to those lines
- Score mode works fully offline (all data local)
- Map tiles need internet — known risk; documented fallback is reduced-detail map

## MVP cut (Saturday 16:00 pitch, half-finished still demos)

2–3 days as above · 4 entity types (tree, street, fountain/toilet, venue) ·
3–4 meaningful decisions per day · live dialogue via proxy with canned fallback ·
German UI · one honest Linz Index verdict.

Stretch (only if ahead): live air-quality modifier, English toggle,
LoD2 3D buildings, more entity types (AEDs, Wi-Fi hotspots, dog zones).

## Out of scope

Backend server, accounts/persistence across sessions, mobile-native app,
multiplayer, any dataset not listed above.

## Open decisions (defaults chosen, revisit if needed)

- Language: German UI and personas (community vote is local; dataset is bilingual)
- Tone of personas: earnest, slightly poetic, factually grounded; no cartoon voices
- Decision parsing: structured intents from Mistral (JSON mode) with a
  two-button fallback UI ("So entscheide ich") in case parsing fails
