import math
import random

from PIL import Image, ImageDraw, ImageOps
from shapely.affinity import translate
from shapely.geometry import LineString
from shapely.ops import linemerge, unary_union


GRASS_PALETTES = {
    "ground": ((166, 186, 121), (202, 216, 159)),
    "forest": ((102, 142, 79), (151, 181, 110)),
    "park": ((139, 175, 91), (184, 204, 133)),
    "grass": ((154, 180, 100), (193, 207, 141)),
    "garden": ((149, 180, 108), (192, 211, 153)),
}
ROAD_WIDTHS = {"road_minor": 10, "pedestrian": 12, "road_major": 18}


def grass_tile(kind):
    rng = random.Random(720 + list(GRASS_PALETTES).index(kind))
    values = [rng.randrange(25, 231) for _ in range(256)]
    coarse = Image.new("L", (18, 18))
    coarse.putdata([values[((y - 1) % 16) * 16 + (x - 1) % 16] for y in range(18) for x in range(18)])
    coarse = coarse.resize((576, 576), Image.Resampling.BICUBIC).crop((32, 32, 544, 544))
    dark, light = GRASS_PALETTES[kind]
    tile = ImageOps.colorize(coarse, dark, light)
    draw = ImageDraw.Draw(tile)
    for _ in range(450):
        x, y = rng.randrange(5, 507), rng.randrange(5, 507)
        color = tuple(max(0, channel - 10) for channel in tile.getpixel((x, y)))
        draw.line([(x - 2, y), (x, y - 3), (x + 2, y - 1)], fill=color, width=2)
    return tile


def tile_patch(tile, size, origin=(0, 0)):
    patch = Image.new("RGB", size)
    for y in range(-origin[1] % tile.height - tile.height, size[1], tile.height):
        for x in range(-origin[0] % tile.width - tile.width, size[0], tile.width):
            patch.paste(tile, (x, y))
    return patch


def paint_grass(image, fills):
    image.paste(tile_patch(grass_tile("ground"), image.size))
    for kind in ("forest", "park", "grass", "garden"):
        tile = grass_tile(kind)
        for ring in fills[kind]:
            x0 = max(0, math.floor(min(p[0] for p in ring)))
            y0 = max(0, math.floor(min(p[1] for p in ring)))
            x1 = min(image.width, math.ceil(max(p[0] for p in ring)) + 1)
            y1 = min(image.height, math.ceil(max(p[1] for p in ring)) + 1)
            if x1 <= x0 or y1 <= y0:
                continue
            size = (x1 - x0, y1 - y0)
            mask = Image.new("L", size)
            ImageDraw.Draw(mask).polygon([(x - x0, y - y0) for x, y in ring], fill=255)
            image.paste(tile_patch(tile, size, (x0, y0)), (x0, y0), mask)


def paint_shape(image, shape, color):
    if shape.is_empty:
        return
    for polygon in shape.geoms if hasattr(shape, "geoms") else [shape]:
        if polygon.geom_type != "Polygon":
            continue
        left, top, right, bottom = polygon.bounds
        x0, y0 = max(0, math.floor(left)), max(0, math.floor(top))
        x1, y1 = min(image.width, math.ceil(right) + 1), min(image.height, math.ceil(bottom) + 1)
        if x1 <= x0 or y1 <= y0:
            continue
        mask = Image.new("L", (x1 - x0, y1 - y0))
        painter = ImageDraw.Draw(mask)
        painter.polygon([(x - x0, y - y0) for x, y in polygon.exterior.coords], fill=color[3] if len(color) == 4 else 255)
        for hole in polygon.interiors:
            painter.polygon([(x - x0, y - y0) for x, y in hole.coords], fill=0)
        image.paste(color[:3], (x0, y0, x1, y1), mask)


def paint_roads(image, roads):
    draw = ImageDraw.Draw(image, "RGBA")
    surfaces = {}
    for kind, paths in roads.items():
        paths = [LineString(path) for path in paths if len(set(path)) > 1]
        surfaces[kind] = unary_union([path.buffer(ROAD_WIDTHS[kind] / 2, cap_style=2) for path in paths])
    combined = unary_union(list(surfaces.values()))
    paint_shape(image, translate(combined.buffer(3), yoff=3), (89, 110, 95, 95))
    paint_shape(image, combined.buffer(3), (151, 163, 153))
    paint_shape(image, combined.buffer(1.5), (237, 233, 215))
    for kind, surface in surfaces.items():
        color = (191, 184, 164) if kind == "pedestrian" else (119, 137, 140)
        paint_shape(image, surface, color)
    for kind, paths in roads.items():
        for points in paths:
            line = LineString(points)
            if line.length < 24:
                continue
            for distance in range(12, int(line.length) - 8, 28 if kind == "road_major" else 18):
                a = line.interpolate(distance)
                b = line.interpolate(distance + 8)
                if kind == "road_major":
                    draw.line([(a.x, a.y), (b.x, b.y)], fill=(239, 230, 196), width=2)
                elif kind == "pedestrian":
                    dx, dy = b.x - a.x, b.y - a.y
                    length = max(1, math.hypot(dx, dy))
                    nx, ny = -dy / length * 4, dx / length * 4
                    draw.line([(a.x + nx, a.y + ny), (a.x - nx, a.y - ny)], fill=(214, 209, 192), width=2)


def bridge_paths(segments):
    if not segments:
        return []
    network = unary_union([LineString(points) for points in segments if len(set(points)) > 1])
    if network.is_empty:
        return []
    merged = network if network.geom_type == "LineString" else linemerge(network)
    return list(merged.geoms) if hasattr(merged, "geoms") else [merged]


def paint_bridges(image, segments):
    draw = ImageDraw.Draw(image, "RGBA")
    count = 0
    for line in bridge_paths(segments):
        if line.length < 12:
            continue
        width = 26 if line.length > 100 else 18
        lift = min(18.0, line.length / 6)
        samples = max(2, math.ceil(line.length / 12))
        deck = []
        for i in range(samples + 1):
            distance = line.length * i / samples
            p = line.interpolate(distance)
            rise = lift * min(1, distance / 28, (line.length - distance) / 28)
            deck.append((p.x, p.y - rise))
        raised = LineString(deck)
        paint_shape(image, translate(line.buffer(width / 2 + 4, cap_style=2), xoff=5, yoff=9), (57, 91, 102, 95))
        if line.length > 100:
            for fraction in (0.3, 0.7):
                p = line.interpolate(line.length * fraction)
                draw.polygon([(p.x - 7, p.y + 3), (p.x + 6, p.y + 6),
                              (p.x + 6, p.y - lift), (p.x - 7, p.y - lift - 3)], fill=(150, 163, 155))
                draw.line([(p.x + 6, p.y + 6), (p.x + 6, p.y - lift)], fill=(105, 131, 128), width=3)
        paint_shape(image, translate(raised.buffer(width / 2, cap_style=2), yoff=5), (112, 140, 140))
        paint_shape(image, raised.buffer(width / 2, cap_style=2), (229, 229, 209))
        paint_shape(image, raised.buffer(width / 2 - 4, cap_style=2), (116, 135, 140))
        for distance in range(20, int(raised.length) - 16, 26):
            a, b = raised.interpolate(distance), raised.interpolate(distance + 10)
            draw.line([(a.x, a.y), (b.x, b.y)], fill=(245, 232, 186), width=2)
        for side in (-1, 1):
            edge = raised.offset_curve(side * (width / 2 - 1))
            if edge.is_empty or edge.geom_type != "LineString":
                continue
            for distance in range(8, int(edge.length) - 8, 22):
                p = edge.interpolate(distance)
                draw.line([(p.x, p.y), (p.x, p.y - 6)], fill=(233, 239, 226), width=2)
            draw.line([(x, y - 6) for x, y in edge.coords], fill=(234, 241, 226), width=2)
        count += 1
    return count
