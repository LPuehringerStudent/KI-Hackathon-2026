#!/usr/bin/env python3
"""Bake an isometric 2.5D miniature of Linz's Innenstadt for the game.

Fetches OSM geometry via Overpass (cached in tools/cache/), renders a
warm light-palette model city at a 30-degree isometric angle — extruded
buildings, tree canopies, water, roads — and marks festival venues with
glowing beacons (venue data from game/godot/data/venues.json).

The lat/lon->pixel transform is written to game/godot/data/map_meta.json
(format_version 2, projection "iso30"); map_view.gd reproduces it exactly.

Wall visibility math: the viewer looks from the northeast (screen-bottom
is max gx+gy). For a CCW footprint ring in pixel space an edge faces the
viewer iff its x delta is negative; d_py > 0 picks the east-facing shade,
else the north-facing one. (Derived from the inverse iso Jacobian.)
"""

import json
import math
import sys
from pathlib import Path
from urllib.request import Request, urlopen

from PIL import Image, ImageDraw
from shapely.geometry import LineString
from shapely.geometry import box as shapely_box
from shapely.ops import polygonize, unary_union

ROOT = Path(__file__).resolve().parent.parent
CACHE = Path(__file__).resolve().parent / "cache" / "overpass_innenstadt_v2.json"
OUT_PNG = ROOT / "game" / "godot" / "assets" / "innenstadt_map.png"
OUT_META = ROOT / "game" / "godot" / "data" / "map_meta.json"
VENUES_JSON = ROOT / "game" / "godot" / "data" / "venues.json"
SPRITES_DIR = ROOT / "game" / "godot" / "assets" / "sprites"
DATA_JSON = ROOT / "game" / "godot" / "data"

BOUNDS = (48.284, 48.318, 14.270, 14.320)  # lat_min, lat_max, lon_min, lon_max
SIZE = 8192
COS_A = math.cos(math.radians(30.0))
SIN_A = math.sin(math.radians(30.0))
TOP_MARGIN = 110    # px above the horizon for venue pillars
EDGE_MARGIN = 36

OVERPASS = "https://overpass-api.de/api/interpreter"
QUERY = """[out:json][timeout:90];(
  way["natural"="water"]({b});
  way["waterway"="riverbank"]({b});
  relation["natural"="water"]({b});
  way["leisure"~"^(park|garden|common)$"]({b});
  way["landuse"~"^(grass|forest)$"]({b});
  way["leisure"="sports_centre"]({b});
  node["natural"="tree"]({b});
  way["highway"~"^(primary|secondary|tertiary|residential|pedestrian|living_street|unclassified)$"]({b});
  way["building"]({b});
);out geom;"""

KM_PER_DEG_LON = 111.32 * math.cos(math.radians(48.3))
KM_PER_DEG_LAT = 110.57

# warm "architectural miniature" palette
C_GROUND = (233, 227, 213)
C_WATER = (168, 202, 222)
C_WATER_EDGE = (146, 184, 208)
C_FOREST = (169, 199, 149)
C_PARK = (188, 214, 168)
C_GRASS = (194, 216, 174)
C_GARDEN = (201, 220, 181)
C_ROAD_MAJOR = (194, 185, 166)
C_ROAD_MINOR = (205, 197, 180)
C_PEDESTRIAN = (221, 213, 195)
C_WALL_E = (208, 195, 176)
C_WALL_N = (184, 170, 150)
C_ROOFS = [(244, 239, 230), (237, 230, 217), (229, 222, 208), (241, 232, 215)]
C_ROOF_EDGE = (184, 173, 155)
C_SHADOW = (70, 58, 44, 42)
C_TRUNK = (122, 96, 70)
C_CANOPY = (110, 157, 94)
C_CANOPY_HI = (144, 189, 120)
C_BEACON = (255, 122, 46)
C_BEACON_HI = (255, 198, 122)

TREE_CAP = 3200
DEFAULT_HEIGHT_M = {
    "church": 20.0, "cathedral": 24.0, "chapel": 10.0,
    "commercial": 13.0, "retail": 12.0, "office": 14.0,
    "industrial": 9.0, "warehouse": 8.0,
    "residential": 9.0, "apartments": 11.0, "house": 6.0, "detached": 6.0,
    "terrace": 7.0, "public": 12.0, "civic": 12.0, "hospital": 15.0,
    "school": 10.0, "university": 14.0, "hotel": 13.0,
    "garage": 3.5, "garages": 3.5, "roof": 3.0, "construction": 8.0,
    "yes": 8.0,
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


def ground_km(lat, lon):
    lat_min, _, lon_min, _ = BOUNDS
    return (lon - lon_min) * KM_PER_DEG_LON, (lat - lat_min) * KM_PER_DEG_LAT


class Iso:
    """lat/lon -> pixel transform; mirrored by map_view.gd."""

    def __init__(self, scale, offset_x, offset_y):
        self.scale, self.offset_x, self.offset_y = scale, offset_x, offset_y

    def xy(self, gx, gy, z_m=0.0):
        sx = (gx - gy) * COS_A
        sy = (gx + gy) * SIN_A - z_m / 1000.0
        return (sx * self.scale + self.offset_x, sy * self.scale + self.offset_y)

    def pt(self, lat, lon, z_m=0.0):
        return self.xy(*ground_km(lat, lon), z_m)


def signed_area(pts):
    a = 0.0
    for i in range(len(pts)):
        x1, y1 = pts[i]
        x2, y2 = pts[(i + 1) % len(pts)]
        a += x1 * y2 - x2 * y1
    return a / 2.0


def building_height(tags):
    for key in ("height", "building:height"):
        raw = tags.get(key)
        if raw:
            try:
                return max(3.0, min(60.0, float(str(raw).split("m")[0].replace(",", ".").strip())))
            except ValueError:
                pass
    levels = tags.get("building:levels") or tags.get("levels")
    if levels:
        try:
            return max(3.0, min(60.0, float(str(levels)) * 3.0))
        except ValueError:
            pass
    return DEFAULT_HEIGHT_M.get(tags.get("building", ""), 8.0)


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
        return "park"
    if el["type"] == "node" and t.get("natural") == "tree":
        return "tree"
    if t.get("building"):
        return "building"
    h = t.get("highway", "")
    if h == "pedestrian":
        return "pedestrian"
    if h in ("primary", "secondary"):
        return "road_major"
    return "road_minor"


def rings_px(el, iso, min_len=3):
    """Pixel rings for a way (one) or relation (many)."""
    out = []
    if el["type"] == "way":
        pts = [(p["lat"], p["lon"]) for p in el.get("geometry", [])]
        if len(pts) >= min_len:
            out.append([iso.pt(*p) for p in pts])
    elif el["type"] == "relation":
        for m in el.get("members", []):
            if m.get("type") == "way" and "geometry" in m:
                pts = [(p["lat"], p["lon"]) for p in m["geometry"]]
                if len(pts) >= min_len:
                    out.append([iso.pt(*p) for p in pts])
    return out


def load_sprites():
    """Astra's 3D props (docs/track-c-brief.md), if delivered. Missing dir or
    files simply fall back to the drawn shapes — output stays deterministic."""
    sprites = {}
    if SPRITES_DIR.is_dir():
        for path in sorted(SPRITES_DIR.glob("prop_*.png")):
            sprites[path.stem] = Image.open(path).convert("RGBA")
    return sprites


# Integration-side size control: 1.0 = native sprite pixels (the brief's
# targets are authored at final size). Tune here, not by re-modeling.
SPRITE_SCALE = 2.0  # bake doubled: sprites keep their ground proportion


def paste_sprite(base, sprite, cx, ground_y):
    """Paste with bottom-center anchor at (cx, ground_y), scaled by SPRITE_SCALE."""
    if SPRITE_SCALE != 1.0:
        w, h = sprite.size
        sprite = sprite.resize((max(1, int(w * SPRITE_SCALE)), max(1, int(h * SPRITE_SCALE))),
                               Image.LANCZOS)
    w, h = sprite.size
    base.paste(sprite, (int(cx - w / 2), int(ground_y - h)), sprite)


def point_in_ring(p, ring):
    """Ray-casting point-in-polygon (pixel ring)."""
    x, y = p
    inside = False
    n = len(ring)
    j = n - 1
    for i in range(n):
        xi, yi = ring[i]
        xj, yj = ring[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            inside = not inside
        j = i
    return inside


def main():
    data = load()
    lat_min, lat_max, lon_min, lon_max = BOUNDS
    w_km = (lon_max - lon_min) * KM_PER_DEG_LON
    h_km = (lat_max - lat_min) * KM_PER_DEG_LAT
    scale = (SIZE - 2 * EDGE_MARGIN - TOP_MARGIN) / ((w_km + h_km) * SIN_A)
    span_x = (w_km + h_km) * COS_A * scale
    iso = Iso(scale, (SIZE - span_x) / 2 + h_km * COS_A * scale, TOP_MARGIN)

    # Ground fills are built with shapely: Overpass returns FULL member
    # geometries for relations (the Danube spans ~20 km), and naively closing
    # each way filled giant chords across land — the "buildings in water" bug.
    # polygonize() forms real polygons from the linework; inner roles become
    # holes; everything is clipped to the bbox before rasterizing.
    kind_lines = {k: {"outer": [], "inner": []} for k in
                  ("water", "forest", "park", "grass", "garden")}
    roads = {"road_major": [], "road_minor": [], "pedestrian": []}
    buildings = []  # (depth_sy, ground_ring_ccw_px, height_m, roof_color)
    trees = []      # (depth_sy, px, radius)

    for el in data.get("elements", []):
        kind = classify(el)
        if kind in kind_lines:
            if el["type"] == "way":
                pts = [ground_km(p["lat"], p["lon"]) for p in el.get("geometry", [])]
                if len(pts) >= 3:
                    kind_lines[kind]["outer"].append(LineString(pts))
            elif el["type"] == "relation":
                for m in el.get("members", []):
                    if m.get("type") == "way" and "geometry" in m:
                        pts = [ground_km(p["lat"], p["lon"]) for p in m["geometry"]]
                        if len(pts) >= 3:
                            key = "inner" if m.get("role") == "inner" else "outer"
                            kind_lines[kind][key].append(LineString(pts))
        elif kind in roads:
            roads[kind].extend(rings_px(el, iso, min_len=2))
        elif kind == "building":
            ring = rings_px(el, iso, min_len=4)
            if not ring:
                continue
            ground = ring[0]
            if signed_area(ground) < 0:  # CCW so wall normals point outward
                ground.reverse()
            depth = sum(p[1] for p in ground) / len(ground)
            roof = C_ROOFS[hash(el.get("id")) % len(C_ROOFS)]
            buildings.append((depth, ground, building_height(el.get("tags", {})), roof))
        elif kind == "tree":
            px = iso.pt(el["lat"], el["lon"])
            r = 2.2 + (hash(el.get("id")) % 10) / 6.0
            trees.append((px[1], px, r))

    bbox_geom = shapely_box(0.0, 0.0, w_km, h_km)
    fills = {"water": [], "forest": [], "park": [], "grass": [], "garden": []}
    water_holes_px = []
    for kind in ("forest", "park", "grass", "garden", "water"):
        outers = kind_lines[kind]["outer"]
        if not outers:
            continue
        geom = unary_union(list(polygonize(unary_union(outers))))
        if geom.is_empty:
            continue
        inners = kind_lines[kind]["inner"]
        if inners:
            inner_geom = unary_union(list(polygonize(unary_union(inners))))
            if not inner_geom.is_empty:
                geom = geom.difference(inner_geom)
        geom = geom.intersection(bbox_geom)
        if geom.is_empty:
            continue
        polys = geom.geoms if geom.geom_type == "MultiPolygon" else [geom]
        for poly in polys:
            fills[kind].append([iso.xy(x, y) for x, y in poly.exterior.coords])
            if kind == "water":
                for interior in poly.interiors:
                    water_holes_px.append([iso.xy(x, y) for x, y in interior.coords])

    # trees standing in water are OSM edge cases (quay promenades etc.) —
    # drop them so the miniature never plants trees in the Danube
    water_rings = fills["water"]
    if water_rings:
        trees = [t for t in trees if not any(point_in_ring(t[1], w) for w in water_rings)]
    buildings.sort(key=lambda b: b[0])
    trees.sort(key=lambda t: t[0])
    trees = trees[:TREE_CAP]

    venues = json.loads(VENUES_JSON.read_text("utf-8")) if VENUES_JSON.exists() else []

    # Astra's sprites (if delivered) become ground objects in the same
    # depth-sorted pass; without them the drawn fallbacks below are used.
    sprites = load_sprites()
    tree_sprites = [sprites[n] for n in sorted(sprites) if n.startswith("prop_tree")]
    ground_objs = []  # (depth_sy, kind, px, extra)
    for depth, px, r in trees:
        ground_objs.append((depth, "tree", px, r))
    if sprites:
        for sprite_name, data_name in (("prop_fountain", "fountains"), ("prop_toilet", "toilets")):
            data_file = DATA_JSON / f"{data_name}.json"
            if sprite_name in sprites and data_file.exists():
                for rec in json.loads(data_file.read_text("utf-8")):
                    px = iso.pt(float(rec["lat"]), float(rec["lon"]))
                    ground_objs.append((px[1], "prop", px, sprites[sprite_name]))
        if "prop_stage" in sprites and VENUES_JSON.exists():
            for v in venues:
                px = iso.pt(float(v["lat"]), float(v["lon"]))
                ground_objs.append((px[1], "prop", px, sprites["prop_stage"]))
        # crowd blobs at venues (baked festival atmosphere, scaled by demand)
        if "prop_crowd" in sprites:
            for v in venues:
                base = iso.pt(float(v["lat"]), float(v["lon"]))
                n = 1 + int(v.get("event_weight", 5)) // 8
                for i in range(n):
                    jx = (hash((v["id"], i, "x")) % 17) - 8
                    jy = (hash((v["id"], i, "y")) % 9) - 4
                    px = (base[0] + jx, base[1] + jy)
                    ground_objs.append((px[1], "prop", px, sprites["prop_crowd"]))
        # market stalls along pedestrian streets
        if "prop_stall" in sprites:
            for ring in roads["pedestrian"]:
                for i, px in enumerate(ring):
                    if i % 12 == 5:  # deterministic spacing along the street
                        ground_objs.append((px[1], "prop", px, sprites["prop_stall"]))
        # boats on the largest water body
        if "prop_boat" in sprites and fills["water"]:
            biggest = max(fills["water"], key=lambda r: abs(signed_area(r)))
            n = len(biggest)
            for frac in (0.3, 0.65):
                p = biggest[int(n * frac)]
                ground_objs.append((p[1], "prop", p, sprites["prop_boat"]))
    ground_objs.sort(key=lambda o: o[0])

    img = Image.new("RGB", (SIZE, SIZE), C_GROUND)
    draw = ImageDraw.Draw(img, "RGBA")

    for kind in ("forest", "park", "grass", "garden"):
        color = C_FOREST if kind == "forest" else \
            {"park": C_PARK, "grass": C_GRASS, "garden": C_GARDEN}[kind]
        for ring in fills[kind]:
            draw.polygon(ring, fill=color)
    for ring in fills["water"]:
        draw.polygon(ring, fill=C_WATER)
        draw.line(ring + [ring[0]], fill=C_WATER_EDGE, width=2)
    for ring in water_holes_px:  # islands: back to ground
        draw.polygon(ring, fill=C_GROUND)

    for kind, width in (("road_minor", 2), ("pedestrian", 4), ("road_major", 5)):
        color = {"road_minor": C_ROAD_MINOR, "pedestrian": C_PEDESTRIAN,
                 "road_major": C_ROAD_MAJOR}[kind]
        for ring in roads[kind]:
            draw.line(ring, fill=color, width=width, joint="curve")

    for v in venues:
        px = iso.pt(float(v["lat"]), float(v["lon"]))
        for rx, alpha in ((38, 30), (26, 48), (14, 72)):
            draw.ellipse([px[0] - rx, px[1] - rx * 0.5, px[0] + rx, px[1] + rx * 0.5],
                         fill=(C_BEACON[0], C_BEACON[1], C_BEACON[2], alpha))

    # depth-sorted world objects (far first): ground objects and buildings
    gi = bi = 0
    while gi < len(ground_objs) or bi < len(buildings):
        take_obj = bi >= len(buildings) or (gi < len(ground_objs) and ground_objs[gi][0] < buildings[bi][0])
        if take_obj:
            _, kind, px, extra = ground_objs[gi]
            gi += 1
            if kind == "prop":
                paste_sprite(img, extra, px[0], px[1])
            elif tree_sprites:
                paste_sprite(img, tree_sprites[hash(px) % len(tree_sprites)], px[0], px[1])
            else:
                r = extra
                draw.line([px[0], px[1], px[0], px[1] - r], fill=C_TRUNK, width=2)
                draw.ellipse([px[0] - r, px[1] - 2 * r, px[0] + r, px[1]], fill=C_CANOPY)
                draw.ellipse([px[0] - r * 0.6, px[1] - 1.9 * r, px[0] + r * 0.35, px[1] - 1.1 * r],
                             fill=C_CANOPY_HI)
        else:
            _, ground, h, roof = buildings[bi]
            bi += 1
            draw.polygon([(x + 7, y + 9) for x, y in ground], fill=C_SHADOW)
            zoff = h / 1000.0 * iso.scale
            n = len(ground)
            for i in range(n):
                x1, y1 = ground[i]
                x2, y2 = ground[(i + 1) % n]
                if x2 >= x1:
                    continue  # edge faces away from the northeast viewer
                wall = C_WALL_E if y2 > y1 else C_WALL_N
                draw.polygon([(x1, y1), (x2, y2), (x2, y2 - zoff), (x1, y1 - zoff)], fill=wall)
            top = [(x, y - zoff) for x, y in ground]
            draw.polygon(top, fill=roof)
            draw.line(top + [top[0]], fill=C_ROOF_EDGE, width=1)

    for v in venues:
        px = iso.pt(float(v["lat"]), float(v["lon"]))
        pillar = 30 + 2 * int(v.get("event_weight", 5))
        for i in range(pillar):
            t = i / pillar
            color = tuple(int(C_BEACON[c] + (C_BEACON_HI[c] - C_BEACON[c]) * t) for c in range(3))
            draw.line([px[0] - 5, px[1] - i, px[0] + 5, px[1] - i],
                      fill=(color[0], color[1], color[2], int(225 * (1 - t))))
        draw.ellipse([px[0] - 4, px[1] - pillar - 4, px[0] + 4, px[1] - pillar + 4],
                     fill=C_BEACON_HI)

    OUT_PNG.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT_PNG)
    OUT_META.write_text(json.dumps({
        "format_version": 2,
        "projection": "iso30",
        "width": SIZE, "height": SIZE,
        "lat_min": lat_min, "lat_max": lat_max,
        "lon_min": lon_min, "lon_max": lon_max,
        "km_per_deg_lon": KM_PER_DEG_LON, "km_per_deg_lat": KM_PER_DEG_LAT,
        "cos_a": COS_A, "sin_a": SIN_A,
        "scale": scale, "offset_x": iso.offset_x, "offset_y": iso.offset_y,
        "source": "OpenStreetMap via Overpass (ODbL) + festival venue data; "
                  "isometric 2.5D render by tools/render_map.py",
    }, indent=1), encoding="utf-8")

    print(f"buildings {len(buildings)}, trees {len(trees)}, venues {len(venues)}")
    print(f"saved {OUT_PNG} + {OUT_META}")
    sys.exit(0 if buildings and fills["water"] else 1)


if __name__ == "__main__":
    main()
