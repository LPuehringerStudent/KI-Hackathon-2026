# Track C Brief — 3D Props as Sprites (Astra) — v3

**Read ONLY this file.** Everything you need is here. Do not read
Kimi-Opus.md, the sprint plan, or other agents' threads. Game logic is owned
by Kimi and Opus; your deliverable is visual assets only. When unsure,
choose the option that changes pixels, not code.

## Mission

Our game map is an isometric miniature of Linz (2D, baked PNG; your v1
sprites are already baked into it — the world works). This v2 is a **size
and clarity revision** of your seven props: bigger, silhouette-first.

## What changes in v3 (and what does not)

- **Sizes: 1.5× your v1 heights** for the original seven — targets below.
  New props (second table) are authored directly at v3 sizes.
- **Detail bar: clean silhouette readable at 20 px.** No interior texture
  finer than 2 px; no outlines; soft toy-model shading throughout.
- **Unchanged:** filenames, 30° NE camera angle, bottom-center anchor,
  transparent background, warm desaturated palette (hexes below).
- **NEW: six additional props** — priority-ordered. If you can only do some,
  do them in priority order (1 = most important).

## Deliverables (exact — no decisions needed)

All files in `game/godot/assets/sprites/` — overwrite the v1 PNGs in place.
Branch: `sprites/props-v3`. One PR, same as before.

| File | Prop | PNG height (v2 target) | Palette (hex) |
|------|------|------------------------|----------------|
| `prop_tree_broad_a.png` | broadleaf tree, full crown | 19 px | canopy `#6f9d5f`, highlight `#90bc77`, trunk `#7a6046` |
| `prop_tree_broad_b.png` | broadleaf, wider/shorter | 15 px | same, crown 1.4× wider |
| `prop_tree_conifer.png` | conifer | 22 px | canopy `#5d8a55`, trunk `#7a6046` |
| `prop_fountain.png` | round drinking fountain | 12 px | basin `#b9c4cc`, water `#8fc3e0` |
| `prop_toilet.png` | public toilet booth | 12 px | walls `#e8e2d6`, roof `#c9c0b0`, door `#8a8274` |
| `prop_shuttle.png` | small electric shuttle bus | 12 px | body `#f2efe8`, accent `#238573` |
| `prop_stage.png` | small festival stage | 20 px | deck `#d9cfbf`, canopy `#e5484d`, light `#ff7a2e` |

### New props (v3 — same specs, same style)

| File | Prop | PNG height | Palette | Priority |
|------|------|-----------|---------|----------|
| `prop_foodtruck.png` | food truck | 12 px | body `#f2efe8`, awning `#e58e3f` | 1 — a game mechanic depends on it |
| `prop_security.png` | security booth / guard post | 12 px | vest `#e58e3f`, booth `#e8e2d6` | 1 — a game mechanic depends on it |
| `prop_tree_broad_c.png` | broadleaf, different crown shape | 18 px | same greens as broad_a | 2 |
| `prop_tree_autumn.png` | broadleaf, autumn colors (Hitzetag!) | 18 px | canopy `#d98e4a`, highlight `#e8b06a` | 2 |
| `prop_stall.png` | market stall | 11 px | canopy `#c95f4f`, counter `#d9cfbf` | 3 |
| `prop_crowd.png` | small crowd cluster | 8 px | mixed warm neutrals `#d9c9b0/#b98d6f/#8a8274` | 3 |
| `prop_boat.png` | small river boat | 8 px | hull `#8a8274`, cabin `#f2efe8` | 4 |

Max width 36 px (v1 allowed 24). Width proportional to the prop.

## Why these numbers (context, not work)

Buildings extrude ~4–8 px at true scale; v1 trees (13 px) were right at the
edge of dwarfing them. v2 trees (~20 px) are deliberately landmark-scaled —
players click trees, so they must read as objects — but 2× would turn the
city into a forest. 1.5× is the sweet spot; do not exceed the table.

## Workflow (token-efficient, same as v1)

1. Load your seven v1 models, scale/re-render to the v2 targets — no new
   modeling needed unless a silhouette doesn't survive the resize.
2. Self-check: at 100% zoom (not 8×), is the prop unmistakably what it is?
   Does it sit in `docs/screenshots/map-after-iso.png` mentally without
   clashing? Then open ONE PR.
3. PR body: one line + the checklist. Stop and report "sprites v3 ready".

## Definition of done

- [ ] Original seven overwritten at v2 sizes (±3 px)
- [ ] New props delivered down to the highest priority you managed (1s strongly preferred — game mechanics reference them)
- [ ] Silhouette readable at 100% zoom; no sub-2px interior texture
- [ ] Same filenames, angle, anchor, palette family
- [ ] No code/scene/doc changes in the PR
- [ ] PR opened from `sprites/props-v2`; comment posted

## Do NOT

- Do not read or edit game logic, scenes, tests, `main.gd`, `map_view.gd`,
  `render_map.py`, or the coordination thread.
- Do not fix bugs or refactor anything. Do not commit directly to `main`.
- Do not re-model from scratch unless a v1 model genuinely can't be rescaled
  cleanly — this is a resize-and-clarify pass, not a new art direction.
