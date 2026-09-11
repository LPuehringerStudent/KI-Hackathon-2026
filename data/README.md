# Data

Shared data snapshots for the hackathon project. All three team members work from these files — refresh them deliberately (see below), not ad-hoc per branch.

## Structure

- `festival/notion_export.json` — official Ars Electronica Festival 2026 program dataset (schema v2, bilingual DE/EN, generated 2026-09-07, 5.4 MB). Top-level keys: `projects`, `locations`, `calendar`, `contacts`, `_meta`. Join everything via `canonical_id` (32-char hex). Source: [official hackathon data endpoint](https://ars.electronica.art/negotiatinghumanity/hackathondata/).
- `linz/` — curated City of Linz open data collection from the [organizers' repo](https://github.com/BenjaminDerProgrammierer/ars-26-hackathon) (`opendata-linz/`), copied 2026-09-11. Contains 12 prepared datasets (normalized CSV/GeoJSON in WGS84) plus conversion scripts. Each subfolder has its own README with schema, license, caveats, and refresh commands — **read it before using a dataset**.

## Status tiers (see `linz/README.md`)

- **Essential:** Baumkataster (trees), Boudicca.Events (city events API), EFA journey planner (live API)
- **Recommended:** AEDs, berries, dog zones, guest origins, Wi-Fi, Linztermine, street names, fountains, toilets, building reserves
- **Optional:** 3D model, historic maps, parking zones, transit geometry, air/weather, orthophotos, cycling counters, city map

## Important caveats

- **Verify festival joins:** an older export (July 20) had broken references (calendar slots → missing projects). The Sept 7 snapshot is newer, but check referential integrity before building cross-dataset joins. Filter by the export's visibility fields.
- **Stale data:** AED (2022), Wi-Fi (2022), fountains/toilets (2023), parking/dog zones (2022/2023) — fine for prototypes, never present as current operational facts.
- **Live APIs** (Boudicca, EFA, air quality) need caching + stale-data handling; EFA blocks browser requests (CORS) — route through a small backend.
- **Licenses:** Linz datasets are typically CC BY — keep attribution (source link + vintage) in anything you build.

## Refreshing

```bash
# Festival dataset (replace the snapshot)
curl -sL "https://ars.electronica.art/negotiatinghumanity/hackathondata/" -o data/festival/notion_export.json
```

For Linz datasets, follow the refresh commands in each `data/linz/<dataset>/README.md`.
