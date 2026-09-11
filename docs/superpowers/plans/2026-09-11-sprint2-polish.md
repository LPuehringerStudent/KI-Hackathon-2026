# Sprint 2 — Polish & Pitch (2026-09-11 afternoon → 2026-09-12 16:00)

**Base state:** `main` after PR #25 — playable three-day loop, 91 headless
checks green (run_tests 40, run_data_tests 11, run_panel_tests 8,
run_integration_tests 20, run_client_tests 12 via
`python3 tools/check_proxy_client.py godot`).

**Rules:** one state (`main`); branch per task off latest main; headless tests
green + 15-min no-objection = author merges (CONTRIBUTING.md). Objections beat
merges. Track ownership is exclusive per file — see AGENTS.md.

**Goal for Saturday 16:00:** polished, pitched, playable demo.

## Track A — Visuals (Kimi)

The current map reads as "plain Google Maps" — rework into an appealing
isometric 2.5D miniature of Linz.

- [ ] **A1: Isometric renderer** — rewrite `tools/render_map.py`: 30° iso
  projection, extruded buildings (OSM `height`/`building:levels` tags, defaults
  by type), walls+roofs light "model village" palette, soft shadows, OSM tree
  canopies, venue glow beacons (from `venues.json`, height by event_weight).
- [ ] **A2: map_meta.json v2** — iso transform params (cos/sin, scale,
  offsets) written by the renderer; `map_view.gd::latlon_to_pixel` mirrors it
  exactly. Contract: same function signature, markers land pixel-perfect.
- [ ] **A3: Marker polish** — dots readable on the light map (white ring,
  tuned colors), subtle pop-in animation, hover grow.
- [ ] **A4: Day tint** — `map_view.set_day_tint(day)`: neutral → cool → hot
  orange for Days 1–3 (Hitzetag reads hot). Track C wires the call in
  `main.gd` if not already hooked.
- [ ] Verify: `run_data_tests` green + PNG visually confirmed + all other
  suites still green (transform change is Track A's blast radius).

## Track B — Gameplay depth (Opus)

- [ ] **B1: Airquality modifier** — wire `data.airquality` (already cached by
  Track A's `fetch_airquality.py`) into `compute_meters`: Day 3 only, PM10
  ≤20 → +10 happiness, ≥50 → −10, linear between, missing file → 0. Named
  constants + tests.
- [ ] **B2: Playtest-driven balance** — after first human playtest, tune
  decision costs/weights where the feel is off. Keep `test_balance_real_data`
  green; document every constant change in the PR.
- [ ] **B3: Edge-case hardening** — rapid click spam across entities, decision
  during pending voice across day boundary (partially covered), empty/missing
  data files, proxy mid-request death.

## Track C — Demo & Pitch (Astra)

- [ ] **C1: Export builds** — Linux x86_64 build on the pitch laptop; Windows
  build if time (start menu already exists). Verify `data/*.json` ships
  (include_filter) and the binary runs without the editor.
- [ ] **C2: Playtest checklist** — scripted run-through: start → day 1 shuttle
  → day 2 toilet negotiation → day 3 tree spared/cut → verdict → restart;
  expected meter movements noted for the pit crew.
- [ ] **C3: Pitch assets** — 3-minute demo script (German), 3–5 pitch slides,
  README quick-start updated (proxy + build + editor paths).
- [ ] **C4: Fallback voices top-up** — regenerate/extend `fallback_voices.json`
  variants if personas feel repetitive in playtest.

## Track C — 3D Models & Art (Astra) — UPDATED direction (human decision)

Astra's strength is Godot MCP / modeling — logic is owned by Kimi + Opus.
**Deliverable: 3D-modeled props as angled sprites** for the isometric map.
**Astra reads ONLY `docs/track-c-brief.md`** — the complete, pre-decided spec.

### Sprite contract (summary — the brief is authoritative)

- Location: `game/godot/assets/sprites/` — transparent PNGs, `prop_<name>.png`.
- **30° isometric, viewer from the northeast**, matching the baked map
  (`docs/screenshots/map-after-iso.png`).
- **Anchor: bottom-center** = ground contact point.
- Sizes: trees 10–15 px (3 variants), fountain/toilet/shuttle 8 px, stage 14 px.
- Style: warm desaturated toy-model look, map palette, soft shading, no outlines.
- No code, no scenes — sprites only; Kimi integrates (task A5).

## Track A — Visuals (Kimi) — additions

- [ ] **A5: Sprite integration** — stamp Astra's sprites into the baked map
  (trees first: replace drawn canopies; props at fountain/toilet/shuttle/
  venue positions) and/or as richer markers in map_view; keep latlon_to_pixel
  contract and all suites green.

## Integration points (contracts between tracks)

- `map_meta.json` v2 ← A writes, A consumes (nobody else touches).
- `data.airquality` ← A produces, B consumes (`data.get("airquality")`, absent → 0).
- `map_view.set_day_tint(day)` ← A implements, C calls from day-change logic.
- Everything else unchanged from the #25 base.

## Verification (all tracks, before any merge)

```bash
godot --headless --path game/godot -s res://tests/run_tests.gd
godot --headless --path game/godot -s res://tests/run_data_tests.gd
godot --headless --path game/godot -s res://tests/run_panel_tests.gd
godot --headless --path game/godot -s res://tests/run_integration_tests.gd
python3 tools/check_proxy_client.py godot
```

All green + 15 min without objection → merge.
