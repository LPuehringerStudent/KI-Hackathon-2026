from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "game/godot/assets"
STEP = 16
CLEARANCE = 112


def water_clearance(city, clearance=CLEARANCE, step=STEP):
    water = np.all(np.asarray(city.convert("RGB")) == (168, 202, 222), axis=2)
    integral = np.zeros((city.height + 1, city.width + 1), dtype=np.uint32)
    np.cumsum(water, axis=0, dtype=np.uint32, out=integral[1:, 1:])
    np.cumsum(integral[1:, 1:], axis=1, dtype=np.uint32, out=integral[1:, 1:])
    xs, ys = np.arange(step // 2, city.width, step), np.arange(step // 2, city.height, step)
    x0, x1 = np.clip(xs - clearance, 0, city.width), np.clip(xs + clearance + 1, 0, city.width)
    y0, y1 = np.clip(ys - clearance, 0, city.height), np.clip(ys + clearance + 1, 0, city.height)
    counts = integral[np.ix_(y1, x1)] - integral[np.ix_(y0, x1)] - integral[np.ix_(y1, x0)] + integral[np.ix_(y0, x0)]
    return Image.fromarray((counts == (clearance * 2 + 1) ** 2).astype(np.uint8) * 255)


def main():
    city = Image.open(ASSETS / "innenstadt_map.png").convert("RGB")
    grid = water_clearance(city)
    grid.save(ASSETS / "boat_clearance.png", optimize=True)
    lights = Image.new("RGBA", city.size)
    draw = ImageDraw.Draw(lights)
    count = 0
    for y in range(12, city.height - 12, 4):
        for x in range(12, city.width - 12, 4):
            wall = city.getpixel((x, y))
            if wall not in [(78, 116, 130), (59, 89, 104)]:
                continue
            if any(city.getpixel((x + dx, y + dy)) != wall
                   for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]):
                continue
            draw.rectangle((x - 1, y - 1, x + 1, y + 1), fill=(255, 197, 105, 230))
            count += 1
    lights.save(ASSETS / "city_windows.png", optimize=True)
    print(f"water cells={sum(v > 0 for v in grid.getdata())}, windows={count}")


if __name__ == "__main__":
    main()
