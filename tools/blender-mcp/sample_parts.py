"""Generate cpore's sample creature-part library in an isolated Blender process.

blender --background --python tools/blender-mcp/sample_parts.py
"""

import json
import math
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "art" / "generated" / "parts"
OUTPUT.mkdir(parents=True, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
scene = bpy.context.scene
scene.unit_settings.system = "METRIC"
scene.unit_settings.scale_length = 1.0


def material(name, color, roughness=0.65, metallic=0.0):
    value = bpy.data.materials.new(name)
    value.diffuse_color = (*color, 1)
    value.use_nodes = True
    shader = value.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metallic
    return value


SKIN = material("Tidal teal skin", (0.035, 0.42, 0.34))
BELLY = material("Warm sand underside", (0.82, 0.54, 0.20))
KERATIN = material("Plum keratin", (0.075, 0.025, 0.065), 0.48)
BONE = material("Ivory teeth and claws", (0.88, 0.82, 0.61), 0.42)
EYE = material("Obsidian eyes", (0.006, 0.012, 0.018), 0.16)
IRIS = material("Golden iris", (0.95, 0.50, 0.055), 0.28, 0.1)
MEMBRANE = material("Coral membrane", (0.70, 0.12, 0.12), 0.72)
CHITIN = material("Cobalt chitin", (0.075, 0.16, 0.30), 0.4, 0.08)
GLOW = material("Lantern chartreuse", (0.55, 0.95, 0.16), 0.3)
GLOW.node_tree.nodes.get("Principled BSDF").inputs["Emission Color"].default_value = (0.55, 0.95, 0.16, 1)
GLOW.node_tree.nodes.get("Principled BSDF").inputs["Emission Strength"].default_value = 2.5
TEXT = material("Catalog lettering", (0.78, 0.84, 0.80), 0.9)


def finish_primitive(obj, name, mat, smooth=True):
    obj.name = name
    obj.data.materials.append(mat)
    if smooth:
        for polygon in obj.data.polygons:
            polygon.use_smooth = True
    return obj


def ellipsoid(name, location, scale, mat=SKIN, segments=24, rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=segments,
        ring_count=rings,
        radius=1,
        location=location,
    )
    obj = finish_primitive(bpy.context.object, name, mat)
    obj.scale = scale
    return obj


def cone(name, location, radius1, radius2, depth, mat=KERATIN, vertices=10):
    bpy.ops.mesh.primitive_cone_add(
        vertices=vertices,
        radius1=radius1,
        radius2=radius2,
        depth=depth,
        location=location,
    )
    return finish_primitive(bpy.context.object, name, mat)


def segment(name, start, end, radius_start, radius_end=None, mat=SKIN, vertices=10):
    start = Vector(start)
    end = Vector(end)
    direction = end - start
    obj = cone(
        name,
        (start + end) / 2,
        radius_start,
        radius_start if radius_end is None else radius_end,
        direction.length,
        mat,
        vertices,
    )
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    return obj


def tube(name, points, radii, mat=SKIN, sides=12):
    """Create a capped, tapered tube; radii may be scalars or (side, up) pairs."""
    centers = [Vector(point) for point in points]
    vertices = []
    for index, center in enumerate(centers):
        tangent = centers[min(index + 1, len(centers) - 1)] - centers[max(index - 1, 0)]
        tangent.normalize()
        reference = Vector((0, 1, 0)) if abs(tangent.y) < 0.9 else Vector((1, 0, 0))
        side = tangent.cross(reference).normalized()
        up = tangent.cross(side).normalized()
        radius = radii[index]
        radius_side, radius_up = (radius, radius) if isinstance(radius, (int, float)) else radius
        for ring_index in range(sides):
            angle = math.tau * ring_index / sides
            point = center + side * (math.cos(angle) * radius_side) + up * (math.sin(angle) * radius_up)
            vertices.append(tuple(point))
    faces = [tuple(reversed(range(sides)))]
    for ring in range(len(centers) - 1):
        for index in range(sides):
            following = (index + 1) % sides
            faces.append((ring * sides + index, ring * sides + following, (ring + 1) * sides + following, (ring + 1) * sides + index))
    faces.append(tuple((len(centers) - 1) * sides + index for index in range(sides)))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(obj)
    obj.data.materials.append(mat)
    for polygon in mesh.polygons:
        polygon.use_smooth = len(polygon.vertices) == 4
    return obj


def membrane(name, vertices, faces, mat=MEMBRANE, thickness=0.045):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(obj)
    obj.data.materials.append(mat)
    solidify = obj.modifiers.new("Membrane thickness", "SOLIDIFY")
    solidify.thickness = thickness
    bevel = obj.modifiers.new("Soft membrane rim", "BEVEL")
    bevel.width = 0.025
    bevel.segments = 2
    return obj


def finish_part(name, objects, category, abilities, attachment):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        for modifier in list(obj.modifiers):
            bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    part = bpy.context.object
    part.name = name
    bpy.context.scene.cursor.location = (0, 0, 0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    bevel = part.modifiers.new("Soft handcrafted edges", "BEVEL")
    bevel.width = 0.018
    bevel.segments = 2
    bevel.limit_method = "ANGLE"
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    part["cpore_category"] = category
    part["cpore_suggested_abilities"] = ", ".join(abilities)
    part["cpore_attachment"] = attachment
    part["cpore_forward"] = "+X"
    part["cpore_up"] = "+Z"
    part["cpore_visual_asset_only"] = True
    bpy.context.view_layer.update()
    return part


PARTS = []


def register(part, category, abilities, attachment):
    path = OUTPUT / f"{part.name}.glb"
    bpy.ops.object.select_all(action="DESELECT")
    part.select_set(True)
    bpy.context.view_layer.objects.active = part
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_animations=False,
        export_yup=True,
        export_extras=True,
    )
    PARTS.append({
        "id": part.name,
        "category": category,
        "file": path.name,
        "suggested_abilities": abilities,
        "attachment": attachment,
        "dimensions_m": [round(value, 4) for value in part.dimensions],
        "vertices": len(part.data.vertices),
        "polygons": len(part.data.polygons),
        "object": part,
    })


# 1. A single stalk eye; its attachment point is the base of the stalk.
objects = [
    segment("Flexible stalk", (0, 0, 0), (0.12, 0, 0.68), 0.12, 0.085),
    ellipsoid("Eyeball", (0.18, 0, 0.82), (0.26, 0.23, 0.25), BELLY),
    ellipsoid("Iris", (0.397, 0, 0.84), (0.055, 0.14, 0.15), IRIS),
    ellipsoid("Pupil", (0.443, 0, 0.84), (0.025, 0.075, 0.095), EYE),
]
register(finish_part("eye_stalk", objects, "sensory", ["perception"], "head socket"), "sensory", ["perception"], "head socket")

# 2. A wide three-eye cluster for alien silhouettes.
objects = [ellipsoid("Triad brow", (0, 0, 0.12), (0.32, 0.64, 0.20))]
for index, y in enumerate((-0.38, 0, 0.38)):
    height = 0.30 if index == 1 else 0.20
    objects.extend([
        ellipsoid(f"Eye {index}", (0.18, y, height), (0.23, 0.20, 0.21), BELLY),
        ellipsoid(f"Iris {index}", (0.375, y, height + 0.01), (0.045, 0.12, 0.13), IRIS),
        ellipsoid(f"Pupil {index}", (0.411, y, height + 0.01), (0.022, 0.06, 0.08), EYE),
    ])
register(finish_part("eye_triad", objects, "sensory", ["perception", "wide gaze"], "forehead"), "sensory", ["perception", "wide gaze"], "forehead")

# 3. Opposed jaws with visible nipping teeth; mouth opens along +X.
objects = [
    ellipsoid("Upper jaw", (0.32, 0, 0.20), (0.52, 0.40, 0.18)),
    ellipsoid("Lower jaw", (0.29, 0, -0.20), (0.48, 0.36, 0.15), BELLY),
]
for side in (-1, 1):
    for index, x in enumerate((0.18, 0.40, 0.61)):
        objects.append(segment(f"Upper tooth {side} {index}", (x, side * 0.27, 0.11), (x + 0.04, side * 0.26, -0.05), 0.065, 0.008, BONE, 8))
        objects.append(segment(f"Lower tooth {side} {index}", (x, side * 0.24, -0.11), (x + 0.03, side * 0.23, 0.02), 0.05, 0.006, BONE, 8))
register(finish_part("jaw_nipper", objects, "mouth", ["bite"], "head front"), "mouth", ["bite"], "head front")

# 4. A three-pronged crown; base sits at Z=0.
objects = []
for index, (x, y, height) in enumerate(((0, 0, 1.05), (-0.12, -0.34, 0.72), (-0.12, 0.34, 0.72))):
    objects.append(segment(f"Horn base {index}", (x, y, 0), (x + 0.10, y, height * 0.58), 0.17, 0.12))
    objects.append(segment(f"Horn tip {index}", (x + 0.10, y, height * 0.58), (x + 0.30, y, height), 0.12, 0.005, KERATIN))
register(finish_part("horn_crown", objects, "offense", ["charge"], "head or spine"), "offense", ["charge"], "head or spine")

# 5. Overlapping dorsal armor with a central ridge.
objects = [ellipsoid("Armor shield", (0, 0, 0.15), (0.72, 0.58, 0.24), KERATIN)]
for index, x in enumerate((-0.40, 0, 0.40)):
    objects.append(segment(f"Shield ridge {index}", (x, 0, 0.26), (x - 0.10, 0, 0.65), 0.12, 0.008, BONE))
for side in (-1, 1):
    objects.append(segment(f"Side spur {side}", (0, side * 0.42, 0.16), (-0.18, side * 0.74, 0.32), 0.11, 0.008, KERATIN))
register(finish_part("shell_plate", objects, "defense", ["armor"], "dorsal spine"), "defense", ["armor"], "dorsal spine")

# 6. Digitigrade sprinting leg; hip is at the origin.
objects = [
    segment("Thigh", (0, 0, 0), (-0.25, 0, -0.72), 0.23, 0.17),
    ellipsoid("Knee", (-0.25, 0, -0.72), (0.20, 0.18, 0.20)),
    segment("Shin", (-0.25, 0, -0.72), (0.12, 0, -1.35), 0.15, 0.09),
    ellipsoid("Runner foot", (0.30, 0, -1.43), (0.40, 0.20, 0.13), KERATIN),
]
for index, y in enumerate((-0.12, 0, 0.12)):
    objects.append(segment(f"Toe claw {index}", (0.52, y, -1.43), (0.76, y, -1.46), 0.05, 0.004, BONE, 8))
register(finish_part("leg_sprinter", objects, "locomotion", ["sprint"], "hip; extends -Z"), "locomotion", ["sprint"], "hip; extends -Z")

# 7. Bent amphibious leg with a broad suction foot.
objects = [
    segment("Upper limb", (0, 0, 0), (-0.42, 0, -0.42), 0.23, 0.20),
    ellipsoid("Flexible joint", (-0.42, 0, -0.42), (0.23, 0.21, 0.23)),
    segment("Lower limb", (-0.42, 0, -0.42), (-0.12, 0, -0.90), 0.18, 0.12),
    ellipsoid("Suction pad", (0.02, 0, -0.96), (0.39, 0.34, 0.12), BELLY),
]
for index, angle in enumerate((-60, -20, 20, 60)):
    radians = math.radians(angle)
    start = (0.12, 0, -0.96)
    end = (0.26 + 0.24 * math.cos(radians), 0.30 * math.sin(radians), -1.00)
    objects.append(segment(f"Gripper toe {index}", start, end, 0.07, 0.035, SKIN))
register(finish_part("leg_sucker", objects, "locomotion", ["climb", "swim"], "hip; extends -Z"), "locomotion", ["climb", "swim"], "hip; extends -Z")

# 8. A grasping arm with opposed pincers.
objects = [
    segment("Upper arm", (0, 0, 0), (0.22, 0, -0.55), 0.18, 0.13),
    ellipsoid("Elbow", (0.22, 0, -0.55), (0.15, 0.14, 0.15)),
    segment("Forearm", (0.22, 0, -0.55), (0.62, 0, -0.82), 0.13, 0.09),
    ellipsoid("Palm", (0.70, 0, -0.84), (0.20, 0.18, 0.13), BELLY),
]
for side in (-1, 1):
    objects.append(segment(f"Pincer base {side}", (0.74, side * 0.10, -0.84), (0.98, side * 0.22, -0.84), 0.085, 0.055, KERATIN))
    objects.append(segment(f"Pincer tip {side}", (0.98, side * 0.22, -0.84), (1.12, side * 0.06, -0.84), 0.055, 0.004, BONE))
register(finish_part("arm_grasper", objects, "manipulation", ["grasp"], "shoulder; extends -Z and +X"), "manipulation", ["grasp"], "shoulder; extends -Z and +X")

# 9. Aquatic tail; base at origin and paddle extending backward along -X.
objects = [
    segment("Tail muscle", (0, 0, 0), (-0.85, 0, 0.05), 0.25, 0.13),
    ellipsoid("Paddle root", (-0.88, 0, 0.05), (0.22, 0.18, 0.17)),
    ellipsoid("Horizontal paddle", (-1.30, 0, 0.05), (0.52, 0.62, 0.11), MEMBRANE),
]
for side in (-1, 1):
    objects.append(segment(f"Paddle edge {side}", (-0.92, 0, 0.06), (-1.53, side * 0.43, 0.06), 0.045, 0.015, KERATIN))
register(finish_part("tail_paddle", objects, "locomotion", ["swim"], "rear spine; extends -X"), "locomotion", ["swim"], "rear spine; extends -X")

# 10. Defensive tail with a clustered barb.
objects = [
    segment("Tail base", (0, 0, 0), (-0.70, 0, 0.10), 0.22, 0.14),
    segment("Tail curve", (-0.70, 0, 0.10), (-1.20, 0, 0.38), 0.14, 0.08),
    ellipsoid("Barb core", (-1.28, 0, 0.43), (0.24, 0.20, 0.22), KERATIN),
]
for index, offset in enumerate((-0.16, 0, 0.16)):
    objects.append(segment(f"Venom barb {index}", (-1.30, offset, 0.45), (-1.65, offset * 1.4, 0.62 + abs(offset)), 0.075, 0.003, BONE))
register(finish_part("tail_spike", objects, "defense", ["counterattack"], "rear spine; extends -X"), "defense", ["counterattack"], "rear spine; extends -X")

# 11. One right gliding wing; mirror across XZ for the opposite wing.
wing_vertices = [
    (0, 0, 0),
    (0.45, 0.65, 0.10),
    (0.18, 1.55, 0.03),
    (-0.48, 2.25, -0.15),
    (-0.92, 1.25, -0.08),
    (-0.72, 0.38, 0),
]
objects = [membrane("Gliding membrane", wing_vertices, [(0, 1, 2), (0, 2, 3), (0, 3, 4), (0, 4, 5)])]
for index, point in enumerate(wing_vertices[1:]):
    objects.append(segment(f"Wing finger {index}", (0, 0, 0.015), point, 0.055, 0.018, KERATIN))
register(finish_part("wing_glider", objects, "locomotion", ["glide"], "right shoulder; mirror for left"), "locomotion", ["glide"], "right shoulder; mirror for left")

# 12. A social display frill in the YZ plane, attached at the neck.
frill_vertices = [(0, 0, 0)]
segments = 12
for index in range(segments + 1):
    angle = math.radians(-110 + 220 * index / segments)
    frill_vertices.append((-0.10, 0.95 * math.sin(angle), 0.95 * math.cos(angle)))
frill_faces = [(0, index + 1, index + 2) for index in range(segments)]
objects = [membrane("Display fan", frill_vertices, frill_faces, MEMBRANE, 0.035)]
for index in (0, 3, 6, 9, 12):
    point = frill_vertices[index + 1]
    objects.append(segment(f"Frill rib {index}", (0, 0, 0), point, 0.045, 0.018, BONE))
register(finish_part("frill_fan", objects, "social", ["display"], "neck; fan lies in YZ plane"), "social", ["display"], "neck; fan lies in YZ plane")


# 13. Broad herbivore beak with grinding ridges.
objects = [
    tube("Upper crushing beak", [(0, 0, 0.18), (0.38, 0, 0.25), (0.74, 0, 0.10), (0.88, 0, -0.12)], [(0.34, 0.24), (0.35, 0.25), (0.24, 0.18), 0.025], BELLY),
    tube("Lower crushing beak", [(0, 0, -0.16), (0.35, 0, -0.22), (0.70, 0, -0.14)], [(0.30, 0.16), (0.29, 0.15), 0.04], KERATIN),
]
for index, x in enumerate((0.22, 0.40, 0.57)):
    objects.append(segment(f"Grinding ridge {index}", (x, -0.24, 0.015), (x, 0.24, 0.015), 0.045, 0.045, BONE, 8))
register(finish_part("beak_crusher", objects, "mouth", ["bite", "sing"], "head front"), "mouth", ["bite", "sing"], "head front")

# 14. Opposed insect mandibles with inward-sweeping tips.
objects = [ellipsoid("Mandible root", (0, 0, 0), (0.25, 0.48, 0.27), CHITIN)]
for side in (-1, 1):
    objects.append(tube(
        f"Shearing mandible {side}",
        [(0.05, side * 0.32, 0), (0.40, side * 0.42, 0.03), (0.78, side * 0.22, 0.05), (0.92, side * 0.035, 0.10)],
        [0.17, 0.15, 0.085, 0.006],
        KERATIN,
    ))
    for index, x in enumerate((0.36, 0.56)):
        objects.append(segment(f"Mandible tooth {side} {index}", (x, side * 0.30, 0.02), (x + 0.08, side * 0.08, 0.04), 0.06, 0.004, BONE, 8))
register(finish_part("mandible_shear", objects, "mouth", ["bite", "strike"], "head front"), "mouth", ["bite", "strike"], "head front")

# 15. A flared vocal snout with a dark bell and visible sound ports.
objects = [
    tube("Resonating snout", [(0, 0, 0), (0.32, 0, 0.04), (0.58, 0, 0.18)], [(0.30, 0.26), (0.24, 0.22), 0.17], SKIN),
    segment("Trumpet bell", (0.50, 0, 0.15), (0.98, 0, 0.27), 0.16, 0.38, BELLY, 24),
    ellipsoid("Bell opening", (1.0, 0, 0.275), (0.035, 0.30, 0.30), KERATIN),
]
for index, x in enumerate((0.14, 0.30, 0.45)):
    objects.append(ellipsoid(f"Sound port {index}", (x, -0.20, 0.19), (0.055, 0.025, 0.075), EYE, 16, 8))
register(finish_part("snout_trumpet", objects, "mouth", ["sing", "charm"], "head front"), "mouth", ["sing", "charm"], "head front")

# 16. Projectile tongue with an elastic curve and sticky terminal paddle.
objects = [
    ellipsoid("Tongue jaw", (0.05, 0, 0), (0.35, 0.40, 0.28), SKIN),
    ellipsoid("Tongue mouth", (0.29, 0, 0.02), (0.12, 0.26, 0.14), KERATIN),
    tube("Elastic tongue", [(0.30, 0, 0.02), (0.62, 0, 0.04), (0.90, 0, 0.18), (1.22, 0, 0.12)], [0.085, 0.07, 0.065, 0.09], MEMBRANE),
    ellipsoid("Sticky tongue paddle", (1.35, 0, 0.12), (0.27, 0.32, 0.13), BELLY),
    ellipsoid("Paddle grip", (1.42, 0, 0.20), (0.16, 0.22, 0.055), MEMBRANE),
]
register(finish_part("tongue_spring", objects, "mouth", ["ranged capture"], "head front"), "mouth", ["ranged capture"], "head front")

# 17. Twin pressure sacs and a narrowed ranged-spit nozzle.
objects = []
for side in (-1, 1):
    objects.extend([
        ellipsoid(f"Pressure sac {side}", (-0.05, side * 0.30, 0), (0.36, 0.29, 0.34), MEMBRANE),
        ellipsoid(f"Sac highlight {side}", (0.04, side * 0.39, 0.13), (0.14, 0.11, 0.13), GLOW, 16, 8),
    ])
objects.extend([
    tube("Spit nozzle", [(0.12, 0, 0), (0.46, 0, 0.02), (0.78, 0, 0.08)], [0.20, 0.13, 0.075], CHITIN),
    ellipsoid("Nozzle opening", (0.80, 0, 0.08), (0.035, 0.065, 0.065), GLOW, 16, 8),
])
register(finish_part("sac_spitter", objects, "weapon", ["ranged spit"], "cheek or head front"), "weapon", ["ranged spit"], "cheek or head front")

# 18. Mantis-inspired raptorial club arm.
objects = [
    segment("Smasher upper arm", (0, 0, 0), (-0.20, 0, -0.54), 0.20, 0.15, CHITIN),
    ellipsoid("Smasher hinge", (-0.20, 0, -0.54), (0.18, 0.17, 0.18), KERATIN),
    segment("Smasher forearm", (-0.20, 0, -0.54), (0.35, 0, -0.88), 0.15, 0.20, CHITIN),
    ellipsoid("Smasher club", (0.66, 0, -0.82), (0.48, 0.31, 0.34), KERATIN),
]
for index, x in enumerate((0.42, 0.63, 0.84)):
    objects.append(segment(f"Club ridge {index}", (x, -0.25, -0.68), (x, 0.25, -0.68), 0.055, 0.055, BONE, 8))
register(finish_part("arm_smasher", objects, "weapon", ["strike"], "shoulder; extends -Z and +X"), "weapon", ["strike"], "shoulder; extends -Z and +X")

# 19. Angular spring leg with a long foot and contrasting tendon.
objects = [
    segment("Spring thigh", (0, 0, 0), (-0.48, 0, -0.62), 0.24, 0.16, SKIN),
    ellipsoid("Spring knee", (-0.48, 0, -0.62), (0.19, 0.17, 0.19), BELLY),
    segment("Spring shin", (-0.48, 0, -0.62), (0.10, 0, -1.48), 0.14, 0.075, SKIN),
    segment("Spring tendon", (-0.54, 0.11, -0.58), (-0.03, 0.11, -1.42), 0.045, 0.025, BONE, 8),
    ellipsoid("Spring foot", (0.36, 0, -1.51), (0.48, 0.19, 0.10), CHITIN),
]
for side in (-1, 1):
    objects.append(segment(f"Spring toe {side}", (0.56, side * 0.09, -1.51), (0.82, side * 0.13, -1.52), 0.045, 0.012, BONE, 8))
register(finish_part("foot_spring", objects, "foot", ["jump", "sprint", "dance"], "hip; extends -Z"), "foot", ["jump", "sprint", "dance"], "hip; extends -Z")

# 20. Compact cloven hoof with rear dewclaws.
objects = [
    segment("Hoof leg", (0, 0, 0), (0.02, 0, -0.70), 0.21, 0.13, SKIN),
    ellipsoid("Hoof ankle", (0.03, 0, -0.72), (0.20, 0.24, 0.18), BELLY),
]
for side in (-1, 1):
    objects.extend([
        ellipsoid(f"Cloven hoof {side}", (0.16, side * 0.14, -0.91), (0.29, 0.135, 0.22), KERATIN, 16, 8),
        segment(f"Dewclaw {side}", (-0.06, side * 0.16, -0.67), (-0.25, side * 0.20, -0.77), 0.065, 0.008, BONE, 8),
    ])
register(finish_part("foot_hoof", objects, "foot", ["charge", "dance"], "hip; extends -Z"), "foot", ["charge", "dance"], "hip; extends -Z")

# 21. Five compliant, distributed gecko-like toes with visible pad ridges.
objects = [
    segment("Gecko ankle", (0, 0, 0), (-0.05, 0, -0.55), 0.18, 0.12, SKIN),
    ellipsoid("Gecko palm", (0.10, 0, -0.64), (0.30, 0.32, 0.13), BELLY),
]
for index, angle in enumerate((-62, -32, 0, 32, 62)):
    radians = math.radians(angle)
    start = Vector((0.18, 0, -0.64))
    middle = start + Vector((0.30 * math.cos(radians), 0.30 * math.sin(radians), -0.015))
    end = start + Vector((0.57 * math.cos(radians), 0.57 * math.sin(radians), -0.025))
    objects.append(tube(f"Gecko toe {index}", [start, middle, end], [0.065, 0.06, 0.075], SKIN, 10))
    pad = ellipsoid(f"Adhesive pad {index}", end, (0.14, 0.10, 0.055), BELLY, 16, 8)
    pad.rotation_euler.z = radians
    objects.append(pad)
    for ridge in (-0.045, 0.015, 0.075):
        center = end + Vector((ridge * math.cos(radians), ridge * math.sin(radians), 0.052))
        across = Vector((-math.sin(radians), math.cos(radians), 0)) * 0.075
        objects.append(segment(f"Pad lamella {index} {ridge}", center - across, center + across, 0.012, 0.012, BONE, 6))
register(finish_part("foot_gecko", objects, "foot", ["climb", "sneak"], "hip; extends -Z"), "foot", ["climb", "sneak"], "hip; extends -Z")

# 22. Anglerfish-inspired curved lure with a caged luminous bulb.
objects = [tube("Lantern stalk", [(0, 0, 0), (0.05, 0, 0.42), (0.24, 0, 0.86), (0.58, 0, 1.02)], [0.095, 0.075, 0.055, 0.04], CHITIN)]
objects.append(ellipsoid("Lantern bulb", (0.67, 0, 0.98), (0.24, 0.22, 0.24), GLOW))
for index, angle in enumerate((0, 90, 180, 270)):
    radians = math.radians(angle)
    offset = Vector((0, 0.20 * math.cos(radians), 0.20 * math.sin(radians)))
    objects.append(segment(f"Lantern cage {index}", Vector((0.60, 0, 1.00)) + offset, Vector((0.85, 0, 0.95)) + offset * 0.35, 0.025, 0.012, KERATIN, 8))
register(finish_part("lure_lantern", objects, "sensory", ["charm", "perception"], "forehead"), "sensory", ["charm", "perception"], "forehead")

# 23. Two-lobed insect wing with a separate lower sail and vein structure.
upper_vertices = [(0, 0, 0), (0.38, 0.55, 0.05), (0.30, 1.40, 0.02), (-0.12, 2.20, -0.08), (-0.48, 1.50, -0.04), (-0.42, 0.48, 0)]
lower_vertices = [(0, 0, -0.02), (-0.30, 0.42, -0.04), (-0.72, 1.25, -0.12), (-0.88, 1.55, -0.16), (-0.20, 1.20, -0.07), (0.12, 0.40, -0.02)]
objects = [
    membrane("Upper insect wing", upper_vertices, [(0, 1, 2), (0, 2, 3), (0, 3, 4), (0, 4, 5)], MEMBRANE, 0.025),
    membrane("Lower insect wing", lower_vertices, [(0, 1, 2), (0, 2, 3), (0, 3, 4), (0, 4, 5)], BELLY, 0.025),
]
for index, point in enumerate((upper_vertices[2], upper_vertices[3], upper_vertices[4], lower_vertices[2], lower_vertices[3])):
    objects.append(segment(f"Insect vein {index}", (0, 0, 0.015), point, 0.032, 0.009, CHITIN, 8))
register(finish_part("wing_insect", objects, "detail", ["glide"], "right shoulder; mirror for left"), "detail", ["glide"], "right shoulder; mirror for left")

# 24. Heavy ankylosaur-inspired tail club with lateral bony lobes.
objects = [
    tube("Hammer tail", [(0, 0, 0), (-0.48, 0, 0.04), (-0.94, 0, 0.20), (-1.26, 0, 0.36)], [0.23, 0.18, 0.13, 0.15], SKIN),
    ellipsoid("Tail club core", (-1.47, 0, 0.40), (0.43, 0.43, 0.32), KERATIN),
]
for side in (-1, 1):
    objects.extend([
        ellipsoid(f"Club lobe {side}", (-1.47, side * 0.38, 0.40), (0.32, 0.28, 0.25), CHITIN),
        segment(f"Club spike {side}", (-1.48, side * 0.48, 0.44), (-1.52, side * 0.75, 0.52), 0.11, 0.006, BONE, 8),
    ])
register(finish_part("tail_hammer", objects, "weapon", ["strike", "defense"], "rear spine; extends -X"), "weapon", ["strike", "defense"], "rear spine; extends -X")


# Build a normalized, camera-aligned catalog without changing exported assets.
bpy.ops.object.camera_add(location=(8, -12, 13))
camera = bpy.context.object
camera.name = "Catalog Camera"
camera.rotation_euler = (-camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.type = "ORTHO"
row_count = math.ceil(len(PARTS) / 4)
camera.data.ortho_scale = max(16.8, row_count * 3.2 + 1.2)
camera.data.clip_end = 200
scene.camera = camera
rotation = camera.rotation_euler.to_quaternion()
right = rotation @ Vector((1, 0, 0))
up = rotation @ Vector((0, 1, 0))

for index, entry in enumerate(PARTS):
    part = entry["object"]
    column = index % 4
    row = index // 4
    x = (column - 1.5) * 3.5
    y = ((row_count - 1) / 2 - row) * 3.2
    scale = 2.0 / max(part.dimensions)
    part.scale = (scale, scale, scale)
    if part.name in {"wing_glider", "wing_insect"}:
        part.rotation_euler = (math.radians(18), 0, math.radians(-22))
    elif part.name == "frill_fan":
        part.rotation_euler.z = math.radians(-55)
    bpy.context.view_layer.update()
    world_corners = [part.matrix_world @ Vector(corner) for corner in part.bound_box]
    center = sum(world_corners, Vector()) / len(world_corners)
    part.location += right * x + up * y - center
    part["catalog_display_scale"] = scale
    bpy.ops.object.text_add(location=right * x + up * (y - 1.18))
    label = bpy.context.object
    label.name = f"Label {part.name}"
    label.data.body = part.name.replace("_", " ")
    label.data.align_x = "CENTER"
    label.data.size = 0.24
    label.data.extrude = 0.002
    label.data.materials.append(TEXT)
    label.rotation_euler = camera.rotation_euler

scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"
scene.display.shading.color_type = "MATERIAL"
scene.display.shading.show_shadows = True
scene.display.shading.show_cavity = True
scene.display.shading.cavity_type = "BOTH"
scene.display.shading.background_type = "VIEWPORT"
scene.display.shading.background_color = (0.025, 0.035, 0.05)
scene.render.resolution_x = 2048
scene.render.resolution_y = 2048
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.filepath = str(OUTPUT / "catalog.png")
bpy.ops.render.render(write_still=True)

manifest = {
    "schema": "cpore.visual-parts/1",
    "description": "Sample visual meshes only; suggested abilities are illustrative and not simulation genome data.",
    "geometry": "Original procedural meshes; no imported game assets",
    "provenance": "docs/PART_INSPIRATION.md",
    "collections": {
        "foundations": [entry["id"] for entry in PARTS[:12]],
        "researched": [entry["id"] for entry in PARTS[12:]],
    },
    "coordinate_convention": {
        "blender": {"up": "+Z", "forward": "+X", "origin": "anatomical attachment point"},
        "gltf": {"up": "+Y", "units": "meters"},
    },
    "parts": [{key: value for key, value in entry.items() if key != "object"} for entry in PARTS],
}
(OUTPUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT / "catalog.blend"), compress=True, check_existing=False)
print(f"CPORE_PARTS_OUTPUT={OUTPUT}", flush=True)
print(f"CPORE_PARTS_COUNT={len(PARTS)}", flush=True)
