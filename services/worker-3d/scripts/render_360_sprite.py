"""Render a deterministic JPEG sprite sheet from a GLB with Blender."""

import argparse
from array import array
import json
import math
from pathlib import Path
import shutil
import sys
import tempfile

import bpy
from mathutils import Vector


def install_numpy_compatibility_aliases() -> None:
    try:
        import numpy as np
    except ModuleNotFoundError:
        return
    if "bool" not in vars(np):
        np.bool = bool


def parse_args() -> argparse.Namespace:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--frames", type=int, default=24)
    parser.add_argument("--columns", type=int, default=6)
    parser.add_argument("--size", type=int, default=160)
    args = parser.parse_args(argv)
    if args.frames < 4 or args.frames > 120:
        parser.error("--frames must be between 4 and 120")
    if args.columns < 1 or args.columns > args.frames:
        parser.error("--columns must be between 1 and --frames")
    if args.size < 64 or args.size > 1024:
        parser.error("--size must be between 64 and 1024")
    return args


def reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in (bpy.data.meshes, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        for item in list(collection):
            if item.users == 0:
                collection.remove(item)


def import_glb(path: Path) -> list[bpy.types.Object]:
    install_numpy_compatibility_aliases()
    bpy.ops.import_scene.gltf(filepath=str(path))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError("GLB contains no mesh objects")
    return meshes


def world_bounds(objects: list[bpy.types.Object]) -> tuple[Vector, Vector]:
    points = [obj.matrix_world @ Vector(corner) for obj in objects for corner in obj.bound_box]
    minimum = Vector(tuple(min(point[index] for point in points) for index in range(3)))
    maximum = Vector(tuple(max(point[index] for point in points) for index in range(3)))
    return minimum, maximum


def add_area_light(
    name: str, location: tuple[float, float, float], energy: float, target: Vector
) -> None:
    data = bpy.data.lights.new(name=name, type="AREA")
    data.energy = energy
    data.shape = "DISK"
    data.size = 100.0
    light = bpy.data.objects.new(name, data)
    light.location = location
    light.rotation_euler = (target - light.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.collection.objects.link(light)


def configure_scene(center: Vector, extent: Vector, size: int) -> bpy.types.Object:
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except TypeError:
        scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = size
    scene.render.resolution_y = size
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "JPEG"
    scene.render.image_settings.color_mode = "RGB"
    scene.render.image_settings.quality = 90
    scene.render.film_transparent = False
    scene.render.use_file_extension = True
    scene.render.use_overwrite = True
    scene.render.use_placeholder = False
    scene.render.resolution_percentage = 100

    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes.get("Background")
    background.inputs["Color"].default_value = (0.12, 0.12, 0.12, 1.0)
    background.inputs["Strength"].default_value = 1.0
    scene.view_settings.exposure = 1.0
    for look in ("AgX - Medium High Contrast", "Medium High Contrast"):
        try:
            scene.view_settings.look = look
            break
        except TypeError:
            continue

    camera_data = bpy.data.cameras.new("LuminSpriteCamera")
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = max(extent.x, extent.y, extent.z) * 1.35
    camera = bpy.data.objects.new("LuminSpriteCamera", camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera

    radius = max(extent.x, extent.y, extent.z)
    add_area_light(
        "LuminKey",
        (center.x + radius * 2, center.y - radius * 2, center.z + radius * 3),
        15000.0,
        center,
    )
    add_area_light(
        "LuminFill",
        (center.x - radius * 2, center.y - radius, center.z + radius),
        7000.0,
        center,
    )
    return camera


def point_camera(camera: bpy.types.Object, location: Vector, target: Vector) -> None:
    camera.location = location
    camera.rotation_euler = (target - location).to_track_quat("-Z", "Y").to_euler()


def render_sheet(args: argparse.Namespace) -> dict[str, int | str]:
    reset_scene()
    meshes = import_glb(args.input.resolve())
    minimum, maximum = world_bounds(meshes)
    center = (minimum + maximum) * 0.5
    extent = maximum - minimum
    if max(extent) <= 0:
        raise RuntimeError("GLB mesh bounds are empty")

    camera = configure_scene(center, extent, args.size)
    radius = max(extent.x, extent.y, extent.z) * 2.5
    rows = math.ceil(args.frames / args.columns)
    sheet_width = args.columns * args.size
    sheet_height = rows * args.size
    sheet_pixels = array("f", [0.0]) * (sheet_width * sheet_height * 4)

    frame_directory = Path(tempfile.mkdtemp(prefix="lumin-sprite-"))
    try:
        bpy.context.scene.render.image_settings.file_format = "PNG"
        for frame in range(args.frames):
            angle = (2.0 * math.pi * frame) / args.frames
            location = Vector(
                (
                    center.x + math.sin(angle) * radius,
                    center.y - math.cos(angle) * radius,
                    center.z + extent.z * 0.18,
                )
            )
            point_camera(camera, location, center)
            frame_path = frame_directory / f"frame-{frame:03}.png"
            bpy.context.scene.render.filepath = str(frame_path)
            bpy.ops.render.render(write_still=True)
            rendered = bpy.data.images.load(str(frame_path), check_existing=False)
            actual_size = tuple(rendered.size)
            if actual_size != (args.size, args.size):
                raise RuntimeError(
                    f"Blender returned render size {actual_size}, expected {(args.size, args.size)}"
                )
            frame_pixels = rendered.pixels[:]
            column = frame % args.columns
            row = rows - 1 - (frame // args.columns)
            for y in range(args.size):
                source_start = y * args.size * 4
                target_start = ((row * args.size + y) * sheet_width + column * args.size) * 4
                sheet_pixels[target_start : target_start + args.size * 4] = array(
                    "f", frame_pixels[source_start : source_start + args.size * 4]
                )
            bpy.data.images.remove(rendered)
    finally:
        shutil.rmtree(frame_directory)

    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    sheet = bpy.data.images.new("Lumin360Sprite", width=sheet_width, height=sheet_height, alpha=False)
    sheet.pixels.foreach_set(sheet_pixels)
    bpy.context.scene.render.image_settings.file_format = "JPEG"
    sheet.filepath_raw = str(output)
    sheet.file_format = "JPEG"
    sheet.save()
    return {
        "renderer": "blender-eevee",
        "frames": args.frames,
        "columns": args.columns,
        "rows": rows,
        "frameSize": args.size,
        "width": sheet_width,
        "height": sheet_height,
        "output": str(output),
    }


def main() -> None:
    args = parse_args()
    if not args.input.is_file():
        raise FileNotFoundError(args.input)
    print(json.dumps(render_sheet(args), sort_keys=True))


if __name__ == "__main__":
    main()
