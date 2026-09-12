import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "tmp/riverboat-frames"
OUTPUT.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
boat = bpy.data.objects.new("RiverCruiser", None)
bpy.context.collection.objects.link(boat)


def material(name, color, roughness=0.55):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Roughness"].default_value = roughness
    return mat


WHITE = material("Ivory enamel", (0.91, 0.94, 0.87))
HULL = material("Deep teal hull", (0.045, 0.23, 0.26))
GLASS = material("Blue glass", (0.12, 0.38, 0.49), 0.28)
DECK = material("Warm timber", (0.63, 0.47, 0.28))
RED = material("Safety coral", (0.92, 0.20, 0.12))
METAL = material("Rail metal", (0.72, 0.80, 0.76))
YELLOW = material("Deck cushions", (0.92, 0.64, 0.16))


def finish(obj, name, mat):
    obj.name = name
    obj.data.materials.append(mat)
    obj.parent = boat
    return obj


def box(name, position, size, mat, bevel=0.04):
    bpy.ops.mesh.primitive_cube_add(size=1, location=position)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        modifier = obj.modifiers.new("Soft manufactured edges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
        obj.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
    return finish(obj, name, mat)


def rod(name, a, b, radius, mat):
    start, end = Vector(a), Vector(b)
    direction = end - start
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=radius, depth=direction.length, location=(start + end) / 2)
    obj = bpy.context.object
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    return finish(obj, name, mat)


def hull():
    outline = [(-3.6, -0.91), (2.65, -0.91), (3.65, -0.38), (3.95, 0),
               (3.65, 0.38), (2.65, 0.91), (-3.6, 0.91), (-3.85, 0.6), (-3.85, -0.6)]
    vertices = [(x * 0.94, y * 0.78, 0.02) for x, y in outline] + [(x, y, 0.5) for x, y in outline]
    n = len(outline)
    faces = [tuple(range(n - 1, -1, -1)), tuple(range(n, n * 2))]
    faces += [(i, (i + 1) % n, (i + 1) % n + n, i + n) for i in range(n)]
    mesh = bpy.data.meshes.new("Tapered hull")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new("Cruise hull", mesh)
    bpy.context.collection.objects.link(obj)
    finish(obj, "Cruise hull", HULL)
    for i, (x, y) in enumerate(outline):
        xx, yy = outline[(i + 1) % n]
        rod("White rubbing strake", (x, y, 0.46), (xx, yy, 0.46), 0.045, WHITE)
        rod("Main deck railing", (x, y, 0.84), (xx, yy, 0.84), 0.028, METAL)
        rod("Rail upright", (x, y, 0.51), (x, y, 0.84), 0.025, METAL)


hull()
box("Main deck", (-0.25, 0, 0.53), (6.6, 1.68, 0.12), DECK)
box("Passenger salon", (-0.35, 0, 0.94), (5.7, 1.45, 0.74), WHITE)
for side in (-1, 1):
    for i in range(11):
        x = -2.9 + i * 0.49
        box("Salon window", (x, side * 0.737, 1.02), (0.35, 0.025, 0.39), GLASS, 0.025)
    box("Teal side stripe", (-0.35, side * 0.75, 0.72), (5.7, 0.025, 0.11), HULL, 0.01)
    for x in (-2.2, 0.7):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.105, minor_radius=0.04,
                                       major_segments=16, minor_segments=8, location=(x, side * 0.80, 1.18),
                                       rotation=(math.pi / 2, 0, 0))
        finish(bpy.context.object, "Life ring", RED)
box("Promenade deck rim", (-0.35, 0, 1.37), (5.94, 1.65, 0.14), WHITE)
box("Sun deck timber", (-0.8, 0, 1.46), (4.5, 1.43, 0.04), DECK)
box("Wheelhouse", (1.7, 0, 1.76), (1.18, 1.25, 0.7), WHITE)
box("Forward windscreen", (2.302, 0, 1.87), (0.025, 1.08, 0.35), GLASS, 0.01)
for side in (-1, 1):
    box("Bridge side glass", (1.73, side * 0.638, 1.88), (0.94, 0.025, 0.34), GLASS, 0.02)
    rod("Upper rail", (-3.25, side * 0.75, 1.84), (1.03, side * 0.75, 1.84), 0.025, METAL)
    for i in range(11):
        x = -3.2 + i * 0.4
        rod("Upper stanchion", (x, side * 0.75, 1.45), (x, side * 0.75, 1.84), 0.018, METAL)
    for x in (-2.55, -1.75, -0.95):
        box("Sun deck seat", (x, side * 0.40, 1.56), (0.48, 0.40, 0.18), YELLOW)
        box("Seat back", (x - 0.20, side * 0.40, 1.71), (0.10, 0.40, 0.26), WHITE)
box("Wheelhouse roof", (1.7, 0, 2.16), (1.4, 1.47, 0.13), WHITE)
box("Teal funnel", (0.0, 0, 1.79), (0.44, 0.52, 0.61), HULL)
box("Funnel cap", (0.0, 0, 2.12), (0.50, 0.57, 0.09), WHITE)
rod("Radar mast", (1.45, 0, 2.21), (1.45, 0, 2.68), 0.025, METAL)
rod("Radar arm", (1.18, 0, 2.61), (1.72, 0, 2.61), 0.034, WHITE)
rod("Flagstaff", (-3.55, 0, 0.6), (-3.55, 0, 1.4), 0.022, METAL)
box("Austrian flag", (-3.74, 0, 1.28), (0.39, 0.025, 0.22), RED, 0)
box("Flag middle stripe", (-3.74, -0.017, 1.28), (0.39, 0.006, 0.07), WHITE, 0)
for x in (3.1, -3.35):
    for y in (-0.47, 0.47):
        rod("Mooring bollard", (x, y, 0.57), (x, y, 0.72), 0.06, HULL)

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 192
scene.render.resolution_y = 128
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.film_transparent = True
scene.world.color = (0.45, 0.45, 0.45)
scene.view_settings.view_transform = "Standard"
for name, position, energy, size in [("Key", (1, -6, 10), 1300, 7), ("Fill", (-5, 3, 6), 850, 8)]:
    data = bpy.data.lights.new(name, "AREA")
    data.energy = energy
    data.shape = "DISK"
    data.size = size
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.location = position
    obj.rotation_euler = (-obj.location).to_track_quat("-Z", "Y").to_euler()
camera_data = bpy.data.cameras.new("Iso camera")
camera = bpy.data.objects.new("Iso camera", camera_data)
bpy.context.collection.objects.link(camera)
camera.location = (0, -12, 6.928203)
camera.rotation_euler = (-camera.location).to_track_quat("-Z", "Y").to_euler()
camera_data.type = "ORTHO"
camera_data.ortho_scale = 10.3
scene.camera = camera
if "--export-model" in sys.argv:
    bpy.ops.export_scene.gltf(
        filepath=str(ROOT / "game/godot/assets/sprites/riverboat.glb"),
        export_format="GLB", export_cameras=False, export_lights=False,
    )
    sys.exit(0)
for frame in range(64):
    heading = frame * math.tau / 64
    boat.rotation_euler.z = math.atan2(-math.sin(heading) / 0.5, math.cos(heading))
    scene.render.filepath = str(OUTPUT / f"boat_{frame:02}.png")
    bpy.ops.render.render(write_still=True)
