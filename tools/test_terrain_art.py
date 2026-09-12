import unittest

from PIL import Image, ImageDraw
from shapely.geometry import LineString, Polygon

from terrain_art import bridge_paths, grass_tile, nibelungen_centerline, nibelungen_deck, paint_bridges, paint_roads, paint_shape, tile_patch
from bake_city_ambience import water_clearance


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

    def test_nibelungen_has_one_shared_deck(self):
        segments = [[(30, 110), (150, 110)], [(150, 110), (300, 110)],
                    [(300, 130), (30, 130)]]
        center = nibelungen_centerline(segments)
        self.assertAlmostEqual(center.centroid.y, 120)
        image = Image.new("RGB", (340, 180), (168, 202, 222))
        count = paint_bridges(image, [{"name": "Nibelungenbruecke", "points": points} for points in segments])
        self.assertEqual(count, 1)
        self.assertNotEqual(image.getpixel((165, 90)), (168, 202, 222))

    def test_clearance_matches_full_hull_footprint(self):
        image = Image.new("RGB", (64, 64), (168, 202, 222))
        ImageDraw.Draw(image).rectangle((29, 11, 34, 49), fill=(120, 120, 120))
        mask = water_clearance(image, clearance=5, step=8)
        for y in range(mask.height):
            for x in range(mask.width):
                cx, cy = x * 8 + 4, y * 8 + 4
                inside = cx >= 5 and cy >= 5 and cx + 5 < 64 and cy + 5 < 64
                expected = inside and all(image.getpixel((xx, yy)) == (168, 202, 222)
                                          for yy in range(cy - 5, cy + 6) for xx in range(cx - 5, cx + 6))
                self.assertEqual(mask.getpixel((x, y)) == 255, expected)

    def test_bridge_profile_has_no_ramp_kinks(self):
        line = LineString([(30, 120), (670, 120)])
        deck = list(nibelungen_deck(line).coords)
        self.assertAlmostEqual(deck[0][1], 120)
        self.assertAlmostEqual(deck[-1][1], 120)
        second_differences = [abs(deck[i + 1][1] - 2 * deck[i][1] + deck[i - 1][1]) for i in range(1, len(deck) - 1)]
        self.assertLess(max(second_differences), 0.08)

    def test_bridge_shadow_keeps_water_visible(self):
        water = (168, 202, 222)
        image = Image.new("RGB", (340, 180), water)
        paint_bridges(image, [{"name": "Nibelungenbruecke", "points": [(30, 120), (300, 120)]}])
        pixel = image.getpixel((165, 148))
        self.assertLess(max(abs(a - b) for a, b in zip(pixel, water)), 18)


if __name__ == "__main__":
    unittest.main()
