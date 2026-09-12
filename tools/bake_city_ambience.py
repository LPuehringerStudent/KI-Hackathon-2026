from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "game/godot/assets"
STEP = 16
CLEARANCE = 28


def main():
    city = Image.open(ASSETS / "innenstadt_map.png").convert("RGB")
    water = Image.new("L", city.size)
    water.putdata([255 if pixel == (168, 202, 222) else 0 for pixel in city.getdata()])
    safe = water.filter(ImageFilter.MinFilter(CLEARANCE * 2 + 1))
    grid = Image.new("L", (city.width // STEP, city.height // STEP))
    grid.putdata([safe.getpixel((x * STEP + STEP // 2, y * STEP + STEP // 2))
                  for y in range(grid.height) for x in range(grid.width)])
    grid.save(ASSETS / "boat_clearance.png", optimize=True)
    lights = Image.new("RGBA", city.size)
    draw = ImageDraw.Draw(lights)
    count = 0
    for y in range(12, city.height - 12, 18):
        for x in range(12, city.width - 12, 22):
            wall = city.getpixel((x, y))
            if wall not in [(208, 195, 176), (184, 170, 150)]:
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
