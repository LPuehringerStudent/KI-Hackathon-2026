# Track C Brief — 3D Props as Sprites (Astra)

**Read ONLY this file.** Everything you need is here. Do not read
Kimi-Opus.md, the sprint plan, or other agents' threads — that work is not
yours. Game logic is owned by Kimi and Opus; your deliverable is visual
assets only. When unsure, choose the option that changes pixels, not code.

## Mission

Our game map is an isometric miniature of Linz (2D, baked PNG). It currently
uses programmer-drawn shapes for trees and props. You replace them with
**3D-modeled sprites** so the world looks crafted, not drawn.

Style reference: `docs/screenshots/map-after-iso.png` (the current map — your
props must sit naturally in this world: same 30° angle, same warm palette,
same miniature scale).

## Deliverables (exact — no decisions needed)

All files in `game/godot/assets/sprites/`, transparent PNGs. Seven props.

| File | Prop | Real size | PNG height | Palette (hex) |
|------|------|-----------|-----------|----------------|
| `prop_tree_broad_a.png` | broadleaf tree, full crown | 12 m | 13 px | canopy `#6f9d5f`, highlight `#90bc77`, trunk `#7a6046` |
| `prop_tree_broad_b.png` | broadleaf, wider/shorter | 9 m | 10 px | same, crown 1.4× wider |
| `prop_tree_conifer.png` | conifer | 14 m | 15 px | canopy `#5d8a55`, trunk `#7a6046` |
| `prop_fountain.png` | round drinking fountain | 1.2 m | 8 px | basin `#b9c4cc`, water `#8fc3e0` |
| `prop_toilet.png` | public toilet booth | 2.4 m | 8 px | walls `#e8e2d6`, roof `#c9c0b0`, door `#8a8274` |
| `prop_shuttle.png` | small electric shuttle bus | 2.5 m | 8 px | body `#f2efe8`, accent `#238573` |
| `prop_stage.png` | small festival stage / beacon base | 4 m | 14 px | deck `#d9cfbf`, canopy `#e5484d` warm light `#ff7a2e` |

Optional (only after the six above land): `icon_<entity>.png` 48px icons for
chat headers (venue/tree/fountain/toilet/street), same palette, flat style.

## Technical spec (follow exactly)

- **Camera: orthographic, 30° elevation, looking from the northeast** — the
  same orientation as the map (north-east faces visible, matching the
  building walls). If you model in Godot: rotation roughly X+30°, facing SW;
  verify against the screenshot.
- **Anchor: bottom-center pixel of each PNG is the ground contact point.**
- Transparent background (alpha), no shadows baked in (the renderer adds
  them), no outlines, soft diffuse shading, slightly desaturated.
- Max width 24 px; scale consistently (1 m ≈ 3.3 px at PNG height).
- File naming exactly as in the table — Kimi's integration code maps
  filenames to entities.

## Workflow (token-efficient)

1. One modeling session. Batch all six props before opening any PR.
2. Render each prop from the fixed camera to PNG (script the export if your
   MCP allows — one render pass, not per-prop fiddling).
3. Self-check against the checklist below, then open ONE PR adding only the
  `game/godot/assets/sprites/` files (+ a one-line note in your PR body).
4. Ping via a comment: "sprites ready" — Kimi integrates.

## Definition of done

- [ ] Seven PNGs at the paths above, correct names, transparent, sizes within
      ±2 px of the table
- [ ] All six at the same camera angle as `map-after-iso.png`
- [ ] Bottom-center anchor visually obvious (ground contact at image bottom)
- [ ] No code, no scene files, no other repo changes in your PR
- [ ] PR opened; comment posted

## Do NOT

- Do not read or edit game logic, scenes, tests, `main.gd`, `map_view.gd`,
  `render_map.py`, or the coordination thread.
- Do not fix bugs, do not refactor, do not "quickly improve" anything outside
  `game/godot/assets/sprites/`. Bugs in logic are Kimi/Opus territory
  (already assigned — your reports would be duplicates).
- Do not commit directly to `main`; branch `sprites/props`, PR, sprint merge
  rule applies (green + 15 min no objection).

## Appendix — PR body template (drafted by Mistral, filenames corrected)

```markdown
**Add 7 isometric 3D sprite props for the game map**

- [ ] `prop_tree_broad_a.png`
- [ ] `prop_tree_broad_b.png`
- [ ] `prop_tree_conifer.png`
- [ ] `prop_fountain.png`
- [ ] `prop_toilet.png`
- [ ] `prop_shuttle.png`
- [ ] `prop_stage.png`

Transparent PNGs (3D-modeled, 30° iso from NE, bottom-center anchor) in
`game/godot/assets/sprites/`. Per `docs/track-c-brief.md`. Integration into
the map is Track A's job — no code in this PR.
```
