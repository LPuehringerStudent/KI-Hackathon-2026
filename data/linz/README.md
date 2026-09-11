# Linz Open Data collection

This directory contains the Linz datasets selected for the Ars Electronica
Festival 2026 hackathon. The individual dataset pages are the current source of
truth for description, provider, format, license, data vintage, limitations,
and delivery status. Where preparation has been completed, the repository also
contains a browser-friendly CSV or JSON snapshot and, in most cases, the script
used to produce it.

The research and decisions that led to this collection are preserved as one
chronological [project history](historic.md). That history explains why a
dataset entered or left the portfolio; it is not a current readiness list.

## Status and preparation are different

The `status` in each dataset page's frontmatter controls how the dataset appears
on the hackathon website:

| Status | Current delivery meaning |
|---|---|
| `essential` | A primary dataset for participants. |
| `recommended` | Directly useful, with documented and manageable caveats. |
| `optional` | A secondary or experimental source. |

These labels describe current participant delivery. Historical reports used
portfolio decisions such as **USE**, **USE WITH PREPARATION**, **OPTIONAL**, and
**DO NOT USE** to record what organizers intended to do at the time. A source
can therefore have been historically selected “with preparation” and now be
`recommended` because that preparation has since been completed. Conversely, a
live or downloadable source can have a prominent catalog status without a
checked-in snapshot; its page must explain the remaining integration work.

In the inventory below, **prepared** means that a normalized, browser-friendly
artifact is checked into this repository. It does not mean that the source is
current enough for operational, legal, accessibility, or safety decisions.

## Current inventory

| Dataset | Page status | Delivery in this repository |
|---|---|---|
| [Baumkataster](baumkataster/) | `essential` | **Prepared:** normalized CSV with WGS84 coordinates and a reproducible converter. |
| [Boudicca.Events](boudicca-events/) | `essential` | Live JSON API; a normalized snapshot, source-aware attribution, deduplication, and fallback are still needed. |
| [Baulandreserven 2022](baulandreserven-2022/) | `recommended` | **Prepared:** checked-in WGS84 GeoJSON; no conversion script is currently included. The 2022 layer is historical context, not a current availability statement. |
| [Defibrillators](defibrillatoren/) | `recommended` | **Prepared:** normalized CSV and reproducible converter; 2022 data is for prototypes only. |
| [Hecken die Schmecken](hecken-die-schmecken/) | `recommended` | **Prepared:** normalized CSV and reproducible converter; the source has no coordinates. |
| [Guest origin countries](herkunftslaender-gaeste/) | `recommended` | **Prepared:** tidy quarterly CSV and reproducible converter. |
| [Public Wi-Fi](hotspots/) | `recommended` | **Prepared:** joined location and monthly-use CSVs with a reproducible converter; status and use figures are from 2022. |
| [Dog zones](hundezonen/) | `recommended` | **Prepared:** checked-in WGS84 GeoJSON with 140 features; no conversion script is currently included. Treat the 2023 rules as non-authoritative. |
| [Linztermine](linztermine/) | `recommended` | **Prepared:** one joined JSON snapshot plus a reproducible converter for events, occurrences, places, organizers, and categories. Refresh shortly before the hackathon. |
| [Playgrounds and sports facilities](spielplaetze/) | `recommended` | Downloadable geocoded CSV and equipment Shapefile; no normalized artifact or converter is checked in here. |
| [Street names and meanings](strassennamen/) | `recommended` | **Prepared:** current and historical normalized CSVs with stable IDs and a reproducible converter. |
| [Drinking fountains](trinkbrunnen/) | `recommended` | **Prepared:** normalized CSV with WGS84 coordinates and a reproducible converter; verify operation and drinkability before use. |
| [Public toilets](wc-anlagen/) | `recommended` | **Prepared:** normalized CSV with WGS84 coordinates and a reproducible converter; verify current service details before use. |
| [Historical city maps](historische-stadtplaene/) | `optional` | Large georeferenced source images; selected maps still need web tiling. |
| [Short-term parking zones](kurzparkzonen/) | `optional` | **Prepared:** five checked-in WGS84 GeoJSON layers with 305 features; no conversion script is currently included. The 2022 data is not current parking or legal guidance. |
| [LINZ AG lines and stops](linz-ag-linien-2025/) | `optional` | Downloadable transit geometry; no browser-ready WGS84 snapshot is checked in here. |
| [Air and weather](luftguete-messwerte/) | `optional` | Rolling live API; applications need per-station failure handling, caching, and clear stale-value presentation. |
| [Orthophotos](orthofotos/) | `optional` | Large source imagery; no festival-area web tiles are checked in here. |
| [Cycling counter measurements](radverkehr-zaehlstellen/) | `optional` | Downloadable 2024–2025 counts and counter locations; release questions about attribution, time semantics, blanks, and grouping remain. |
| [Stadtplan Linz 2025](stadtplan-linz-2025/) | `optional` | Georeferenced source raster; no cropped, reprojected, web-optimized artifact is checked in here. |
| [3D city data](3d-geodaten-lod2-2022/) | `optional` | Large 2025 source tiles are documented; selected festival-area tiles still need conversion for browser use. |
| [EFA journey planner](efa-fahrplanauskunft/) | `essential` | The live legacy API and usage path are documented; no shared adapter, cache, or fallback is provided, and browser-direct requests are blocked by CORS. |

The prepared collection currently covers 12 dataset folders. Linztermine,
short-term parking zones, and dog zones are already converted; they are not
future preparation tasks. For exact record counts, fields, downloads, and
refresh commands, use the linked dataset pages.

## Festival-data integration

The Ars festival export's schema version 2 already supplies canonical record
IDs, unique calendar and location IDs, and visibility fields. Those earlier
schema gaps are no longer the integration blocker.

The current blocker is referential integrity after visibility filtering. Five
exported calendar slots refer to projects that are absent, and 35 projects
contain 75 references to absent calendar slots. There are also unresolved
contact, project-hierarchy, and reverse location references. As a result, the
current `event_rows()` import produces no timetable events. Repair or remove
those references and verify a fresh public export before building cross-dataset
joins; the checked-in July 20 export is retained only as a known-bad diagnostic
snapshot. See the [July 28 referential-integrity report](../ars-dataset/discussions/2026-07-28-export-referential-integrity.md).

After that repair, join festival records by `canonical_id` and use only records
allowed by the export's visibility fields. For spatial combinations, prefer
verified child or parent locations and retain source provenance and vintage on
every Linz-derived layer.

## Working with the collection

Start with the dataset page, not the historical report. It documents the
student-facing schema, missing-value semantics, identifiers, coordinates,
source links, warnings, and any refresh command. Prepared outputs use UTF-8 and
WGS84 `lon`/`lat` for point maps; converted polygon layers are GeoJSON in
EPSG:4326. Preserve the documented IDs and use compound keys where a page says
an identifier is unique only within a file or layer.

Live, safety-related, legal, and service-state data must be rechecked near the
event. The dataset pages call out the applicable limits, including stale AED,
Wi-Fi, fountain, toilet, parking, and dog-zone information. Historical or
prototype-only layers must never be presented as current operational guidance.
