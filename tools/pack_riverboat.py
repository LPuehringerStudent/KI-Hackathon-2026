from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
atlas = Image.new("RGBA", (192 * 8, 128 * 8))
for frame in range(64):
    image = Image.open(ROOT / f"tmp/riverboat-frames/boat_{frame:02}.png").convert("RGBA")
    assert image.size == (192, 128)
    assert image.getchannel("A").getbbox() is not None
    bounds = image.getchannel("A").getbbox()
    assert bounds[0] > 0 and bounds[1] > 0 and bounds[2] < 192 and bounds[3] < 128
    atlas.paste(image, ((frame % 8) * 192, (frame // 8) * 128))
atlas.save(ROOT / "game/godot/assets/sprites/riverboat_directions.png", optimize=True)
print("64 transparent riverboat headings packed; all silhouettes unclipped")
