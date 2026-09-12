import unittest

from PIL import Image
from shapely.geometry import Polygon

from terrain_art import bridge_paths, grass_tile, paint_bridges, paint_roads, paint_shape, tile_patch


class TerrainArtTests(unittest.TestCase):
    def test_grass_is_repeatable_and_varied(self):
        tile = grass_tile("grass")
        self.assertEqual(tile.tobytes(), grass_tile("grass").tobytes())
        self.assertGreater(len(tile.getcolors(512 * 512)), 100)
        edge_difference = sum(abs(a - b) for y in range(512)
                              for a, b in zip(tile.getpixel((0, y)), tile.getpixel((511, y)))) / (512 * 3)
        self.assertLess(edge_difference, 3)

    def test_patch_uses_world_aligned_texture(self):
        tile = grass_tile("park")
        whole = tile_patch(tile, (700, 600))
        cropped = tile_patch(tile, (150, 120), (430, 280))
        self.assertEqual(whole.crop((430, 280, 580, 400)).tobytes(), cropped.tobytes())

    def test_surface_preserves_holes(self):
        image = Image.new("RGB", (100, 100), (30, 90, 40))
        shape = Polygon([(5, 5), (95, 5), (95, 95), (5, 95)],
                        [[(30, 30), (70, 30), (70, 70), (30, 70)]])
        paint_shape(image, shape, (120, 140, 150))
        self.assertEqual(image.getpixel((50, 50)), (30, 90, 40))
        self.assertEqual(image.getpixel((10, 10)), (120, 140, 150))

    def test_roads_preserve_blocks(self):
        image = Image.new("RGB", (160, 160), (30, 90, 40))
        paint_roads(image, {"road_major": [[(20, 20), (140, 20), (140, 140), (20, 140), (20, 20)]],
                            "road_minor": [], "pedestrian": []})
        self.assertEqual(image.getpixel((80, 80)), (30, 90, 40))
        self.assertNotEqual(image.getpixel((80, 20)), (30, 90, 40))

    def test_bridge_segments_join_and_raise_deck(self):
        segments = [[(20, 80), (100, 80)], [(100, 80), (220, 80)]]
        self.assertEqual(len(bridge_paths(segments)), 1)
        water = (168, 202, 222)
        image = Image.new("RGB", (240, 120), water)
        self.assertEqual(paint_bridges(image, segments), 1)
        self.assertNotEqual(image.getpixel((120, 62)), water)
        self.assertEqual(image.getpixel((120, 20)), water)


if __name__ == "__main__":
    unittest.main()
