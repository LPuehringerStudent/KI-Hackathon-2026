#!/usr/bin/env python3
"""Bake a stylized dark-theme map PNG of Linz's Innenstadt for the game.

Fetches OSM geometry via Overpass (cached in tools/cache/), renders a
2048x2048 night-style map, and writes the lat/lon->pixel transform to
game/godot/data/map_meta.json. The Godot map_view uses that meta to place
entity markers, so the transform here is the single source of truth.

Rerun freely: the PNG is deterministic given the cache.
"""

import json
import math
import sys
from pathlib import Path
from urllib.request import Request, urlopen

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
CACHE = Path(__file__).resolve().parent / "cache" / "overpass_innenstadt.json"
OUT_PNG = ROOT / "game" / "godot" / "assets" / "innenstadt_map.png"
OUT_META = ROOT / "game" / "godot" / "data" / "map_meta.json"

BOUNDS = (48.284, 48.318, 14.270, 14.320)  # must match extract_innenstadt.py
SIZE = 2048

OVERPASS = "https://overpass-api.de/api/interpreter"
QUERY = """[out:json][timeout:90];(
  way["natural"="water"]({b});
  way["waterway"="riverbank"]({b});
  relation["natural"="water"]({b});
  way["leisure"~"^(park|garden|common)$"]({b});
  way["landuse"~"^(grass|forest)$"]({b});
  way["leisure"="sports_centre"]({b});
  way["highway"~"^(primary|secondary|tertiary|residential|pedestrian|living_street|unclassified)$"]({b});
  way["building"]({b});
);out geom;"""

# night palette
C_BG = (30, 36, 48)
C_WATER = (45, 74, 107)
C_PARK = (43, 74, 58)
C_GARDEN = (48, 82, 62)
C_FOREST = (38, 66, 52)
C_GRASS = (44, 73, 57)
C_BUILDING = (58, 66, 80)
C_BUILDING_EDGE = (70, 79, 95)
C_ROAD = (74, 84, 99)
C_ROAD_MAJOR = (96, 107, 124)
C_PEDESTRIAN = (88, 98, 114)

DRAW_ORDER = ["water", "forest", "park", "grass", "garden", "sports",
              "building", "pedestrian", "road_minor", "road_major"]


def classify(el):
    t = el.get("tags", {})
    if t.get("natural") == "water" or t.get("waterway") == "riverbank":
        return "water"
    if t.get("leisure") in ("park", "common"):
        return "park"
    if t.get("leisure") == "garden":
        return "garden"
    if t.get("landuse") == "forest":
        return "forest"
    if t.get("landuse") == "grass":
        return "grass"
    if t.get("leisure") == "sports_centre":
        return "sports"
    if t.get("building"):
        return "building"
    h = t.get("highway", "")
    if h == "pedestrian":
        return "pedestrian"
    if h in ("primary", "secondary"):
        return "road_major"
    return "road_minor"


COLORS = {
    "water": C_WATER, "park": C_PARK, "garden": C_GARDEN, "forest": C_FOREST,
    "grass": C_GRASS, "sports": C_PARK, "building": C_BUILDING,
    "pedestrian": C_PEDESTRIAN, "road_minor": C_ROAD, "road_major": C_ROAD_MAJOR,
}


def fetch():
    lat_min, lat_max, lon_min, lon_max = BOUNDS
    b = f"{lat_min},{lon_min},{lat_max},{lon_max}"  # Overpass: s,w,n,e
    print("fetching OSM geometry from Overpass ...", flush=True)
    req = Request(OVERPASS, data=QUERY.format(b=b).encode(),
                  headers={"User-Agent": "KI-Hackathon-2026 map baker (OpenStreetMap data)"})
    with urlopen(req, timeout=120) as r:
        data = json.loads(r.read().decode())
    CACHE.parent.mkdir(parents=True, exist_ok=True)
    CACHE.write_text(json.dumps(data), encoding="utf-8")
    return data


def load():
    if CACHE.exists():
        return json.loads(CACHE.read_text("utf-8"))
    return fetch()


def projection_constants():
    km_per_deg_lon = 111.32 * math.cos(math.radians(48.3))
    km_per_deg_lat = 110.57
    lat_min, lat_max, lon_min, lon_max = BOUNDS
    w_km = (lon_max - lon_min) * km_per_deg_lon
    h_km = (lat_max - lat_min) * km_per_deg_lat
    return {
        "km_per_deg_lon": km_per_deg_lon,
        "km_per_deg_lat": km_per_deg_lat,
        "scale_px_per_km": SIZE / max(w_km, h_km),
    }


def project(lat, lon):
    """WGS84 -> pixel coords (equirectangular, corrected for lat 48.3)."""
    c = projection_constants()
    lat_min, lat_max, lon_min, lon_max = BOUNDS
    x = (lon - lon_min) * c["km_per_deg_lon"]
    y = (lat_max - lat) * c["km_per_deg_lat"]
    return x * c["scale_px_per_km"], y * c["scale_px_per_km"]


def ring_geom(el):
    """Yield pixel-space rings; handles way geom and relation members."""
    if el["type"] == "way":
        pts = [(p["lat"], p["lon"]) for p in el.get("geometry", [])]
        if len(pts) >= 3:
            yield [project(*p) for p in pts]
    elif el["type"] == "relation":
        for m in el.get("members", []):
            if m.get("type") == "way" and "geometry" in m:
                pts = [(p["lat"], p["lon"]) for p in m["geometry"]]
                if len(pts) >= 3:
                    yield [project(*p) for p in pts]


def main():
    data = load()
    layers = {k: [] for k in DRAW_ORDER}
    for el in data.get("elements", []):
        kind = classify(el)
        if kind in layers:
            layers[kind].extend(ring_geom(el))

    img = Image.new("RGB", (SIZE, SIZE), C_BG)
    draw = ImageDraw.Draw(img)
    for kind in DRAW_ORDER:
        rings = layers[kind]
        if not rings:
            continue
        color = COLORS[kind]
        width = 0
        if kind in ("road_minor", "pedestrian"):
            width = 2
        elif kind == "road_major":
            width = 4
        for ring in rings:
            if width:
                draw.line(ring, fill=color, width=width, joint="curve")
            else:
                draw.polygon(ring, fill=color)
                if kind == "building":
                    draw.line(ring + [ring[0]], fill=C_BUILDING_EDGE, width=1)

    OUT_PNG.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT_PNG)
    OUT_META.write_text(json.dumps({
        "width": SIZE, "height": SIZE,
        "lat_min": BOUNDS[0], "lat_max": BOUNDS[1],
        "lon_min": BOUNDS[2], "lon_max": BOUNDS[3],
        **projection_constants(),
        "projection": "equirectangular corrected for lat 48.3 (see project())",
        "source": "OpenStreetMap via Overpass (ODbL), rendered by tools/render_map.py",
    }, indent=1), encoding="utf-8")

    counts = {k: len(v) for k, v in layers.items() if v}
    print("rendered:", counts)
    print(f"saved {OUT_PNG} + {OUT_META}")
    sys.exit(0 if (counts.get("water") and counts.get("building")) else 1)


if __name__ == "__main__":
    main()
