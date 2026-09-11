# History of the Linz Open Data assessment

This document records how the Linz Open Data portfolio was researched and how
its decisions changed. It consolidates the former `opendata-linz/archive/`
reports and supporting review artifacts. For the datasets that are available
now, their readiness, prepared files, and current caveats, use the
[current dataset catalog](README.md) and the individual dataset pages instead.

The historical verdicts below are evidence of the decision process, not a
second current catalog. In particular, the festival-export findings from
13–16 July predate schema v2 and are explicitly superseded.

## Timeline

### 13 July 2026: title-and-description candidate scan

The first pass queried the data.gv.at feed for publisher “Stadt Linz” and
selected plausible datasets from titles and descriptions. It organized ideas
around the festival export's anticipated join surfaces: venue coordinates,
calendar times, project text and categories, and artist countries.

This pass surfaced the directions that shaped the later work: Linztermine,
public transport, trees, historical maps and orthophotos, 3D city data,
visitor-service points, tourism origins, street-name history, and several
smaller public-space layers. It was intentionally speculative. It did not
verify payloads, freshness, identifiers, licenses, coordinate systems, or
whether a title accurately described the data.

**Superseded finding:** the candidate tiers were discovery aids only. Examples
of title-driven errors included treating `Beherbergungsbetriebe` as possible
hotel locations and “open construction projects” as project-level data. Later
payload inspection showed that both were aggregate tables without the expected
places or projects.

### 13 July 2026: reproducible review of the full catalog

A second pass downloaded nine Atom-feed pages and parsed all 820 records. The
inventory captured title, description, dates, formats, resource count, catalog
URL, and resource URLs. A small namespace-aware Python analyzer made the pass
repeatable.

The inventory marked 19 records **A**, 13 **B**, and 788 unselected. These were
not 820 distinct subjects: 513 records were annual budget/account tables, 49
were council minutes or agenda records, and many subjects appeared once per
year or once per format. This established an important portfolio rule: catalog
record count is a poor proxy for useful breadth.

The strongest broader ideas from this pass were an urban-forest explorer,
solar/green-roof analysis with 3D buildings, a neighborhood-change atlas,
accessible-everyday-Linz maps, transit exploration, searchable civic memory,
Linztermine discovery, street-history storytelling, election maps, city-change
imagery, transparent-city-finance views, resilience trends, and a live
environmental pulse.

Several of those ideas remained valuable but did not belong in the default
festival bundle. The later assessment required a credible festival join,
manageable preparation, interpretable freshness, and acceptable operational or
safety risk—not merely an interesting civic-data topic.

### 13 July 2026: hands-on review of 25 likely sources

The next pass downloaded representative payloads and tested actual formats,
values, endpoint behavior, freshness, identifiers, and joins. Its initial
source-level score was 17 recommended, six borderline, and two dropped. That
score was deliberately permissive: “recommended” meant that a source contained
useful data and could combine with festival data, not that it was ready to ship
unchanged.

The lasting evidence from those checks is summarized below. Later corrections
are included in the same row so obsolete conclusions are not repeated as
current facts.

| Source or bundle | Evidence established by the payload review | How the conclusion evolved |
|---|---|---|
| Baumkataster | About 27,000 geocoded trees; semicolon CSV; July 2026 export; missing-value markers need normalization | Remained a leading source. The later crawl found 27,004 rows and showed that `BaumNr` and even `(Flaeche, BaumNr)` were not unique, so snapshot keys must be validated. |
| Linztermine events, places, organizers, and tags | Live XML; explicit date range required; location 358 is Ars Electronica Center and organizer 7 is Ars Electronica; places have no coordinates; tags are only a small helper taxonomy | The four feeds became one prepared bundle rather than four standalone recommendations. |
| LINZ AG network | 748 WGS84 stops plus route/graph geometry; GML/GeoPackage rather than browser-ready data; no schedules | Remained useful only as static geometry after conversion; it must not be described as realtime timetable data. |
| EFA journey planner | Live legacy API worked without registration; StopFinder-to-departure flow and projected coordinates required; no SLA | Retained only with an adapter, backend/proxy, documented limits, and fallback. |
| Air and weather | Rolling Land OÖ JSON; epoch-millisecond timestamps and comma-decimal strings; station-specific components; only a 24-hour window | Five station endpoints worked and four returned no measurements in the sampled window. The conclusion changed from a broad recommendation to monitored, cached use with visible station failures. |
| Historical city maps | Georeferenced raster editions from 1876–1990 in useful CRSs; files are large and each vintage is separate | Remained a prepared visual track requiring selection, tiling, and downsampling. |
| 3D city model | 834 CityGML/DXF tiles with textures in EPSG:31255; substantial tooling and browser conversion needed | The July 16 crawl found a 2025 edition, but all generated index URLs still pointed to `/2022/`; selected paths needed repair and verification. |
| Orthophotos | Strong historical imagery, but roughly 11.8 GB for the 2019 vintage and TIFF/GK conversion required | Remained an optional organizer-prepared showcase rather than a default source. |
| Street names | Roughly 1,211 current and 369 historical names, narrative descriptions, successor names, and Wikidata links; no geometry | Remained useful through normalized venue-address joins and prepared current/historical CSVs. |
| Guest-origin countries | 2005–2024 country/quarter tourism series; Latin-1, semicolon delimiter, aggregate and footnote rows mixed with countries | Retained as contextual analysis after country normalization; it must not imply that festival artists caused or represent tourist flows. |
| Public toilets | Small EPSG:31255 CSV with accessibility and free-text opening-hours fields | Retained after reprojection and normalization, with current-service warnings. |
| Drinking fountains | Useful operating and service attributes; original metadata mislabeled projected coordinates as WGS84 | The publisher corrected the CRS metadata on 15 July. Conversion still had to verify axes and service freshness. |
| Accessible parking | 574 projected Shapefile points from 2022; CP1252 text | Moved from borderline source data to prepared-only, dated accessibility context; not current availability. |
| Playgrounds and sports facilities | About 158 geocoded CSV rows; the richer equipment Shapefile initially used unreachable internal paths | Publisher repair restored the equipment files. The source remained suitable with a visible vintage. |
| Defibrillators | 282 WGS84-ish coordinate strings from 2022; some co-located devices | Downgraded from a general recommendation to prototype-only because safety locations must not be operational guidance. |
| Public Wi-Fi | About 134 points and partial name joins to January–July 2022 usage; missing values and name normalization required | Kept only as dated optional context, not current crowd information. |
| Short-term parking | Valid central-Linz projected Shapefiles from 2022 | Kept as a secondary utility layer after conversion; hours and rules require current confirmation. |
| Parking-ticket machines | Initial 2023 Shapefile had no `.prj`; addresses offered a fallback | The projection file was repaired and a 251-record 2024 edition later superseded the 269-record 2023 edition, but low festival value still excluded it from the default bundle. |
| Dog zones | Initial catalog links pointed to an inaccessible internal file share | Public access and the EPSG:31255 projection file were repaired on 15 July. The source changed from “drop” to dated optional material after conversion. |
| Hecken die Schmecken | 26 named locations, no coordinates, 2022 vintage, and uncertain plant details | Stayed a small optional garnish, never a core source. |
| Digital city map TMS/WMTS | 2016 GIF tiles in a custom projected folder scheme and no joinable attributes | Excluded because standard web basemaps were easier and more useful. |
| Accommodation establishments | City-wide monthly guest totals, no establishments, names, addresses, or coordinates | Dropped; the misleading title was the clearest demonstration that catalog metadata alone was insufficient. |

The payload checks also established recurring preparation needs: explicit
encoding conversion, comma-decimal parsing, WKT handling, EPSG:31255
reprojection, Shapefile sidecar validation, XML/CDATA parsing, deterministic
IDs, asset tiling, and request-time health checks for rolling APIs.

### 13–15 July 2026: festival-specific consolidation and publisher follow-up

The source reviews were then combined with the live festival export. The main
portfolio conclusion was that Linz Open Data worked well as a curated and
prepared bundle, not as an unfiltered catalog exercise. City data could join to
the festival through cleaned venue coordinates and addresses, dates, shared
places or organizers, country codes, and categories.

Publisher follow-up on 15 July materially changed several judgments:

- drinking-fountain CRS metadata was corrected;
- dog-zone downloads and their projection information became public;
- the playground equipment files became reachable;
- a missing parking-machine projection file was supplied;
- incorrect 2012 links for `Baulandreserven` were replaced with a complete
  2022 Shapefile;
- the air-quality failures were escalated rather than silently treated as
  healthy endpoints;
- LINZ AG-controlled sources were identified as requiring direct follow-up
  with LINZ AG.

Recycling-point CSVs still redirected to a LINZ AG login, so they could not be
treated as open downloads. The publisher planned to retire the affected catalog
records rather than restore those files. Requests for timetable/GTFS or NeTEx,
realtime service information, pool occupancy, and replacement recycling data
therefore remained external follow-ups.

#### Superseded pre-schema-v2 festival-export findings

The 13–16 July reports measured a pre-schema-v2 export containing 546 projects,
240 contacts, 111 locations, and 178 calendar rows. They found missing and
duplicate location/calendar IDs, prefixed-versus-bare relation IDs, incomplete
project/location and calendar/location resolution, extensive `pending` status,
and no explicit public-record rule. Six Ars Electronica Center child locations
also used the suspicious coordinate `48.09619, 14.84447`.

**These counts and the associated ID/visibility recommendations are historical
and must not be used to describe the current export.** Schema v2, generated on
20 July, introduced unique `canonical_id` values, unique calendar and location
IDs, a leading calendar relation, explicit visibility and quality fields, and
machine-readable suspicious-coordinate reporting. The obsolete recommendation
to invent canonical IDs or infer visibility is therefore withdrawn.

Schema v2 did not make every export concern disappear. The remaining issues
were reassessed against the new fields, and later filtering introduced
post-filter referential-integrity failures. Current work should follow the
[schema-v2 follow-up](../ars-dataset/discussions/2026-07-20-remaining-data-issues.md),
the [July 28 referential-integrity report](../ars-dataset/discussions/2026-07-28-export-referential-integrity.md),
and newer verified exports, not the July 13–16 counts above.

### 16 July 2026: publisher-directory delta crawl

A recursive crawl below
[`https://data.linz.gv.at/katalog/`](https://data.linz.gv.at/katalog/) checked
publisher directories without bulk-downloading the large imagery and 3D
collections. Directory timestamps were treated only as publication activity;
payload contents, not folder dates, determined data vintage. The former central
catalog route used by the earlier research returned HTTP 404, so the publisher
directory and payloads became the stronger freshness evidence.

The crawl produced four material results:

1. **Cycling counts were the strongest new candidate.** Files published on
   15 July contained 263,160 unique station-hour observations from 2024–2025,
   15 directional counter IDs at eight coordinate pairs, complete joins, and
   1,674 blank readings. Blanks had to remain null; license, attribution,
   timezone/DST, sensor method, update cadence, and counter grouping were still
   release gates.
2. **The 3D model had a 2025 edition.** Its 834-row index covered 506 terrain
   and 328 building tiles, but its generated resource URLs incorrectly retained
   `/2022/`.
3. **A neighborhood-statistics pack was feasible.** Population contained 16
   populated district rows plus 177 presentation/blank rows; age structure had
   16 rows and 100 one-year age columns; matching district geometry used the
   2014 boundary system. This required CP1252 conversion, blank filtering,
   stable district keys, boundary-vintage documentation, and disclosure care.
4. **Several title-based ideas were downgraded.** Childcare points were still
   from 2016; the construction source had only five aggregate rows; city-map
   rasters were large but attribute-free; subsidies were stale and awkward;
   road-injury, fire-service, and public-order data were aggregate civic topics
   with weak festival joins.

The crawl also confirmed the 27,004-row tree snapshot and its non-unique source
identifiers, a complete 2024 parking-machine Shapefile, and machine-readable
2025 mayoral results with matching precinct geometry. Election material
remained year-specific and required neutral interpretation.

### After the research archive

The dated research was converted into dataset-specific pages, prepared outputs,
converters, and validation rules. As preparation progressed, readiness changed:
for example, Linztermine, street names, fountains, toilets, short-parking data,
and dog-zone data acquired checked-in normalized artifacts. Those later states
belong in the [current catalog](README.md), not in this historical narrative.

The durable lessons were incorporated into the repository's data-preparation
contract: inspect actual payloads, preserve source provenance, distinguish
snapshot vintage from retrieval time, verify schemas and identifiers, retain
unknowns rather than converting them to zero, reproject rather than relabel
coordinates, and present operational or safety data as dated prototypes unless
it can be confirmed at request time.

## Decision principles that survived every pass

- Prefer a small prepared portfolio over raw-catalog discovery during the
  hackathon.
- Require a real join to festival places, dates, entities, countries, or
  categories for default inclusion.
- Separate source interest from delivery readiness: a compelling source may
  still require conversion, tiling, proxying, caching, or a license decision.
- Treat live endpoints per station or service, with a cached fallback and
  visible partial failure.
- Never present old AED, accessibility, fountain, toilet, parking, transit, or
  other operational records as guaranteed current truth.
- Preserve aggregate meaning; tourism, election, safety, and civic statistics
  do not support claims about individuals.
- Validate identifier uniqueness and relationships on every refreshed
  snapshot; labels such as `ID` or `BaumNr` do not prove key quality.
- Verify CRS and axis order from source metadata and values; projected numbers
  must never merely be renamed `lat` and `lon`.

## Provenance of the consolidated material

This history merges and replaces the following former archive artifacts:

- the 13 July title/description candidate list;
- the 13 July 820-record inventory, its analyzer, CSV, and project shortlist;
- the 25 individual hands-on source reviews and their overview;
- the 13 July festival-specific consolidated report, updated after the
  15 July publisher follow-up;
- the 16 July publisher-directory delta review;
- the 16 July consolidated usability report; and
- the short list of datasets removed from the published catalog.

The detailed source records remain recoverable from Git history. This document
keeps their method, material measurements, corrections, and decision changes in
one place while avoiding a duplicate of the current dataset catalog.
