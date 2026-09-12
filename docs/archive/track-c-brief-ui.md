# Track C Brief — UI Art v4 (Astra)

**Read ONLY this file.** Do not read other docs, threads, or git history.
Your v1–v3 sprite props are integrated and working. This v4 is UI art only —
two deliverable groups, exact specs below. Game logic and wiring are Kimi's
job; you deliver files, nothing else.

## Deliverable 1 — start-menu background (first priority)

The pitch audience's first impression is the start menu. Current state: flat
gray screen with text. Replace-worthy.

- File: `game/godot/assets/sprites/ui_menu_background.png`
- Size: **1920×1080** (scaled by the engine; composed so the important
  content survives center-crop to ~1600×900)
- Content: the isometric Linz miniature mood — warm cream palette (same
  family as the map: ground `#e9e3d5`, greens `#a8c795`, water `#a8cade`),
  a soft, slightly out-of-focus iso city skyline along the bottom third,
  glowing amber venue beacons (color `#ff7a2e`) rising from it, generous
  calm negative space in the upper two-thirds where the title text sits
- NO text in the image — the engine renders the title
- Style: match the map's toy-model miniature look; soft gradients; nothing
  photorealistic; subtle vignette

## Deliverable 2 — entity icons for the chat panel

Small icons shown next to entity names when the player talks to them.

- Files in `game/godot/assets/sprites/`, 48×48 px, transparent PNG:
  - `icon_venue.png` — stage/beacon motif (red canopy / amber light)
  - `icon_tree.png` — broadleaf canopy
  - `icon_fountain.png` — round basin with water
  - `icon_toilet.png` — booth silhouette
  - `icon_street.png` — street sign / lamp post
- Flat-ish version of your prop style: readable at 48 px, palette hexes from
  the map props, no outlines finer than 2 px

## Constraints (unchanged from your previous briefs)

- You produce files only: no code, no scenes, no docs, no other repo changes.
- Branch `sprites/ui-v4`, ONE PR adding only the files above.
- If a deliverable can't reach quality you'd defend, skip it and say which —
  a smaller honest PR beats padded scope.

## Definition of done

- [ ] `ui_menu_background.png` 1920×1080, no text, correct palette/mood
- [ ] Five `icon_*.png` at 48×48, transparent, distinct at a glance
- [ ] Nothing else in the PR
- [ ] PR opened from `sprites/ui-v4`; comment "ui art v4 ready" + which
      deliverables completed
