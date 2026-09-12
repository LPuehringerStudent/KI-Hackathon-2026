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
    landmark = [part["points"] for part in segments if isinstance(part, dict) and part["name"].startswith("Nibelungen")]
    ordinary = [part["points"] if isinstance(part, dict) else part for part in segments
                if not isinstance(part, dict) or not part["name"].startswith("Nibelungen")]
    if landmark:
        paint_nibelungen(image, nibelungen_centerline(landmark))
        count += 1
    for line in bridge_paths(ordinary):
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


def nibelungen_centerline(segments):
    lanes = sorted(bridge_paths(segments), key=lambda line: line.length, reverse=True)[:2]
    reference = lanes[0]
    aligned = []
    for lane in lanes:
        if lane.interpolate(0).distance(reference.interpolate(0)) > lane.interpolate(lane.length).distance(reference.interpolate(0)):
            lane = LineString(list(lane.coords)[::-1])
        aligned.append(lane)
    points = []
    for i in range(33):
        samples = [lane.interpolate(i / 32, normalized=True) for lane in aligned]
        points.append((sum(p.x for p in samples) / len(samples), sum(p.y for p in samples) / len(samples)))
    return LineString(points)


def nibelungen_deck(line):
    points = []
    for i in range(65):
        t = i / 64
        p = line.interpolate(t, normalized=True)
        rise = 24 * math.sin(math.pi * t)
        points.append((p.x, p.y - rise))
    return LineString(points)


def paint_nibelungen(image, line):
    draw = ImageDraw.Draw(image, "RGBA")
    width = max(42, min(58, line.length * 21 / 250))
    deck = nibelungen_deck(line)
    paint_shape(image, translate(line.buffer(width / 2 + 2, cap_style=2), xoff=3, yoff=6), (40, 74, 85, 22))
    for fraction in (0.30, 0.70):
        p = line.interpolate(fraction, normalized=True)
        before = line.interpolate(fraction - 0.01, normalized=True)
        after = line.interpolate(fraction + 0.01, normalized=True)
        angle = math.atan2(after.y - before.y, after.x - before.x)
        tangent = (math.cos(angle), math.sin(angle))
        normal = (-tangent[1], tangent[0])
        pier_top = 24 * math.sin(math.pi * fraction) - 5
        base = [(p.x + tangent[0] * along + normal[0] * across,
                 p.y + tangent[1] * along + normal[1] * across)
                for along, across in [(-7, -width * 0.35), (7, -width * 0.35), (7, width * 0.35), (-7, width * 0.35)]]
        for i, (x, y) in enumerate(base):
            xx, yy = base[(i + 1) % 4]
            draw.polygon([(x, y + 4), (xx, yy + 4), (xx, yy - pier_top), (x, y - pier_top)],
                         fill=(175, 173, 155) if i % 2 else (135, 143, 135))
            for height in range(0, int(pier_top), 6):
                draw.line([(x, y - height), (xx, yy - height)], fill=(153, 156, 143), width=2)
    paint_shape(image, translate(deck.buffer(width / 2, cap_style=2), yoff=5), (96, 114, 105))
    paint_shape(image, deck.buffer(width / 2, cap_style=2), (226, 225, 207))
    paint_shape(image, deck.buffer(width / 2 - 7, cap_style=2), (119, 132, 133))
    for side in (-1, 1):
        cycle = deck.offset_curve(side * (width / 2 - 10))
        draw.line(list(cycle.coords), fill=(178, 152, 121), width=4)
        for offset in (1.5, 4.0):
            track = deck.offset_curve(side * offset)
            draw.line(list(track.coords), fill=(77, 91, 91), width=1)
        lane = deck.offset_curve(side * width * 0.23)
        for distance in range(18, int(lane.length) - 14, 28):
            a, b = lane.interpolate(distance), lane.interpolate(distance + 11)
            draw.line([(a.x, a.y), (b.x, b.y)], fill=(241, 236, 212), width=2)
        edge = deck.offset_curve(side * (width / 2 - 1))
        for distance in range(8, int(edge.length) - 8, 18):
            p = edge.interpolate(distance)
            draw.line([(p.x, p.y), (p.x, p.y - 5)], fill=(193, 203, 192), width=2)
        draw.line([(x, y - 5) for x, y in edge.coords], fill=(232, 235, 218), width=2)
        for distance in range(44, int(edge.length) - 32, 100):
            p = edge.interpolate(distance)
            draw.line([(p.x, p.y - 5), (p.x, p.y - 22)], fill=(155, 167, 159), width=2)
            draw.line([(p.x - side * 5, p.y - 22), (p.x, p.y - 22)], fill=(240, 236, 208), width=3)
    front = line.offset_curve(width / 2)
    front_deck = deck.offset_curve(width / 2)
    if front.centroid.y < line.centroid.y:
        front = line.offset_curve(-width / 2)
        front_deck = deck.offset_curve(-width / 2)
    for start, end in ((0.025, 0.12), (0.88, 0.975)):
        fractions = [start + (end - start) * i / 8 for i in range(9)]
        base = [front.interpolate(t, normalized=True) for t in fractions]
        top = [front_deck.interpolate(t, normalized=True) for t in reversed(fractions)]
        draw.polygon([(p.x, p.y + 8) for p in base] + [(p.x, p.y + 5) for p in top], fill=(173, 172, 151))
    for fraction in (0.045, 0.08, 0.92, 0.955):
        p = front.interpolate(fraction, normalized=True)
        top = front_deck.interpolate(fraction, normalized=True).y + 7
        height = p.y + 8 - top
        if height < 4:
            continue
        radius = min(4, height * 0.4)
        draw.polygon([(p.x - radius, p.y + 8), (p.x + radius, p.y + 8),
                      (p.x + radius, top + radius), (p.x + radius * 0.6, top + 1),
                      (p.x, top), (p.x - radius * 0.6, top + 1), (p.x - radius, top + radius)], fill=(83, 95, 83))
