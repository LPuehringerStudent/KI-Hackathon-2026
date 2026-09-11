#!/usr/bin/env python3
"""Extract the Innenstadt subset of festival + City of Linz data for the game.

Reads the snapshots in data/ and writes small JSON files to game/godot/data/.
All downstream game data comes from here — do not hand-edit the JSON outputs.

Notes on honest data handling:
- Street names have NO coordinates in the source CSV. Streets are placed via a
  small curated table of well-known Innenstadt streets (approximate center
  points, flagged approximate in every record).
- Tree ages are ESTIMATES from trunk circumference (Stammumfang in cm) using
  rough growth rates (Laubbaum 2.5 cm/yr, Nadelbaum 1.2 cm/yr, default 2.0).
  They are persona flavor, not arborist facts; None when circumference missing.
"""

import csv
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data"
OUT = ROOT / "game" / "godot" / "data"

BOUNDS = (48.284, 48.318, 14.270, 14.320)  # lat_min, lat_max, lon_min, lon_max
TREE_CAP = 400
STREET_CAP = 60
STREET_MIN_HISTORY = 50

GROWTH_CM_PER_YEAR = {"laubbaum": 2.5, "nadelbaum": 1.2, "obstbaum": 2.0}

# Approximate center points for well-known Innenstadt streets (no source coords).
# Where the festival export has a matching location (Hauptplatz, OK Platz), its
# verified coordinates are used instead of the estimate.
CURATED_STREETS = {
    "Hauptplatz": (48.30549, 14.28668),  # festival export, verified
    "Landstraße": (48.3026, 14.2888),
    "Promenade": (48.3008, 14.2902),
    "Bischofstraße": (48.3037, 14.2897),
    "Spittelwiese": (48.3046, 14.2882),
    "Schillerstraße": (48.3009, 14.2888),
    "Klammstraße": (48.3068, 14.2876),
    "Domgasse": (48.3046, 14.2845),
    "Rathausgasse": (48.3053, 14.2862),
    "Graben": (48.3036, 14.2832),
    "Fischergasse": (48.3040, 14.2837),
    "Herrenstraße": (48.3049, 14.2889),
    "Taubenmarkt": (48.3047, 14.2870),
    "Bürgerstraße": (48.3040, 14.2933),
    "Bethlehemstraße": (48.2979, 14.2957),
    "Mozartstraße": (48.3017, 14.2917),
    "Bahnhofplatz": (48.2903, 14.2917),
    "Ars-Electronica-Straße": (48.3092, 14.2830),
    "OK-Platz": (48.30241, 14.29098),  # festival export, verified
}


def in_bounds(lat, lon):
    lat_min, lat_max, lon_min, lon_max = BOUNDS
    return lat_min <= lat <= lat_max and lon_min <= lon <= lon_max


def out(name, rows):
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / f"{name}.json"
    path.write_text(json.dumps(rows, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"{name}.json: {len(rows)} records")


def fnum(value):
    try:
        return float(str(value).replace(",", "."))
    except (TypeError, ValueError):
        return None


def extract_venues():
    export = json.loads((DATA / "festival" / "notion_export.json").read_text("utf-8"))
    locations = [
        l for l in export["locations"]
        if l.get("public_for_hackathon") is True
        and str(l.get("coordinates_ok")) == "True"
    ]
    own_events = {}
    for slot in export["calendar"]:
        if slot.get("public_for_hackathon") is not True:
            continue
        link = slot.get("Linked Location") or ""
        m = re.search(r"([0-9a-f]{32})", link)
        if m:
            own_events.setdefault(m.group(1), []).append(slot)

    by_id = {l["canonical_id"]: l for l in locations}

    def total_events(cid, visited=None):
        """Own slots + transitive rollup over Linked Child sub-rooms."""
        if visited is None:
            visited = set()
        if cid in visited:
            return 0
        visited.add(cid)
        loc = by_id.get(cid)
        if loc is None:
            return 0
        n = len(own_events.get(cid, []))
        for child in loc.get("Linked Child") or []:
            n += total_events(child, visited)
        return n

    venues = []
    for loc in locations:
        lat, lon = fnum(loc.get("Latitude")), fnum(loc.get("Longitude"))
        if lat is None or lon is None or not in_bounds(lat, lon):
            continue
        if loc.get("Linked Parent"):  # sub-rooms roll up into their parent venue
            continue
        cid = loc["canonical_id"]
        events = total_events(cid)
        if events < 5:  # curated set of significant festival venues
            continue
        venues.append({
            "id": cid,
            "name": loc.get("Name DE") or loc.get("Name EN") or "Unbenannt",
            "lat": round(lat, 6),
            "lon": round(lon, 6),
            "events": events,
            "event_weight": min(20, events),
        })
    venues.sort(key=lambda v: -v["events"])
    return venues[:20]


def read_csv(path):
    with open(path, newline="", encoding="utf-8") as fh:
        yield from csv.DictReader(fh)


def extract_trees():
    trees = []
    for row in read_csv(DATA / "linz" / "baumkataster" / "Baumkataster.csv"):
        lat, lon = fnum(row.get("lat")), fnum(row.get("lon"))
        if lat is None or lon is None or not in_bounds(lat, lon):
            continue
        species = " ".join(p for p in [row.get("Gattung"), row.get("Art")] if p).strip()
        if not species:
            species = (row.get("NameDeutsch") or "Unbekannter Baum").strip()
        circ = fnum(row.get("Stammumfang"))
        age = None
        if circ and circ > 10:  # circumference in cm; ignore implausible values
            rate = GROWTH_CM_PER_YEAR.get((row.get("Typ") or "").lower(), 2.0)
            age = int(circ / rate)
        trees.append({
            "id": row["id"],
            "lat": round(lat, 6),
            "lon": round(lon, 6),
            "species": species,
            "height_m": fnum(row.get("Hoehe")),
            "crown_m": fnum(row.get("Schirmdurchmesser")),
            "age_estimate": age,
        })
    trees.sort(key=lambda t: -(t["crown_m"] or 0))
    return trees[:TREE_CAP]


def extract_fountains():
    fountains = []
    for row in read_csv(DATA / "linz" / "trinkbrunnen" / "Trinkbrunnen.csv"):
        lat, lon = fnum(row.get("lat")), fnum(row.get("lon"))
        if lat is None or lon is None or not in_bounds(lat, lon):
            continue
        fountains.append({
            "id": row["id"],
            "name": row.get("aufstellungsort") or "Brunnen",
            "lat": round(lat, 6),
            "lon": round(lon, 6),
            "kind": row.get("brunnenart") or "",
            "drinking": (row.get("trinkwasser") or "").lower() == "ja",
        })
    return fountains


def extract_toilets():
    toilets = []
    for row in read_csv(DATA / "linz" / "wc-anlagen" / "WC-Anlagen.csv"):
        lat, lon = fnum(row.get("lat")), fnum(row.get("lon"))
        if lat is None or lon is None or not in_bounds(lat, lon):
            continue
        toilets.append({
            "id": row["id"],
            "name": row.get("name") or row.get("art") or "WC",
            "lat": round(lat, 6),
            "lon": round(lon, 6),
            "kind": row.get("art") or "",
        })
    return toilets


def extract_streets():
    streets = []
    for row in read_csv(DATA / "linz" / "strassennamen" / "Strassennamen-aktuell.csv"):
        name = (row.get("name") or "").strip()
        history = (row.get("beschreibung") or "").strip()
        if name not in CURATED_STREETS or len(history) < STREET_MIN_HISTORY:
            continue
        lat, lon = CURATED_STREETS[name]
        streets.append({
            "id": row["id"],
            "name": name,
            "history": history,
            "lat": lat,
            "lon": lon,
            "approximate": True,
        })
        if len(streets) >= STREET_CAP:
            break
    return streets


def main():
    venues = extract_venues()
    trees = extract_trees()
    fountains = extract_fountains()
    toilets = extract_toilets()
    streets = extract_streets()

    out("venues", venues)
    out("trees", trees)
    out("fountains", fountains)
    out("toilets", toilets)
    out("streets", streets)
    out("meta", {
        "bounds": {"lat_min": BOUNDS[0], "lat_max": BOUNDS[1],
                   "lon_min": BOUNDS[2], "lon_max": BOUNDS[3]},
        "extracted_at": datetime.now(timezone.utc).isoformat(),
        "sources": [
            "data/festival/notion_export.json (Ars Electronica, schema v2)",
            "data/linz/baumkataster/Baumkataster.csv (CC BY 4.0, Export 2026-07-01)",
            "data/linz/trinkbrunnen/Trinkbrunnen.csv (CC BY 4.0, 2023)",
            "data/linz/wc-anlagen/WC-Anlagen.csv (CC BY 4.0, 2023)",
            "data/linz/strassennamen/Strassennamen-aktuell.csv (CC BY 4.0, 2025-03-07)",
        ],
        "notes": {
            "streets": "Source CSV has no coordinates; positions are approximate "
                       "center points of well-known Innenstadt streets (curated), "
                       "except Hauptplatz and OK-Platz, which use the festival "
                       "export's verified venue coordinates.",
            "tree_age": "Estimated from trunk circumference via rough growth rates "
                        "(Laub 2.5, Nadel 1.2, other 2.0 cm/yr). Persona flavor only.",
            "venues": "Top-level festival locations (no Linked Parent) with "
                      "coordinates_ok=True, public_for_hackathon=True; events = own "
                      "calendar slots + transitive rollup over Linked Child "
                      "sub-rooms; >=5 total, capped at 20 by event count.",
        },
    })

    ok = 8 <= len(venues) <= 20 and 300 <= len(trees) <= TREE_CAP \
        and 5 <= len(fountains) <= 40 and 5 <= len(toilets) <= 50 and len(streets) >= 5
    print("counts plausible:" , ok)
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
