"""Cpore Design Bridge: run this file with Blender, or install it as an add-on.

blender --python tools/blender-mcp/addon.py

Only 127.0.0.1 is exposed. MCP clients can execute arbitrary Blender Python;
use it only with models and repositories you trust.
"""

import contextlib
import io
import json
import math
import os
from pathlib import Path
import socket
import time
import traceback
import uuid

import bpy
from mathutils import Vector


bl_info = {
    "name": "Cpore Design Bridge",
    "author": "Cpore contributors",
    "version": (1, 0, 0),
    "blender": (4, 2, 0),
    "location": "3D View > Sidebar > Cpore",
    "description": "Local MCP scene control and rendered feedback",
    "category": "Development",
}

HOST = "127.0.0.1"
PORT = int(os.environ.get("CPORE_BLENDER_PORT", "9876"))
MAX_MESSAGE_BYTES = 64 * 1024 * 1024
_server = None
_client = None
_buffer = bytearray()
_namespace = {}


def _json_value(value, depth=0):
    if depth > 5:
        return repr(value)
    if value is None or isinstance(value, (str, bool, int)):
        return value
    if isinstance(value, float):
        return value if math.isfinite(value) else repr(value)
    if isinstance(value, dict):
        return {str(key): _json_value(item, depth + 1) for key, item in value.items()}
    if isinstance(value, (list, tuple, set, Vector)):
        return [_json_value(item, depth + 1) for item in value]
    if hasattr(value, "to_list"):
        return _json_value(value.to_list(), depth + 1)
    return repr(value)


def _scene_info(params):
    limit = min(int(params.get("object_limit", 200)), 500)
    scene = bpy.context.scene
    objects = []
    for obj in list(scene.objects)[:limit]:
        item = {
            "name": obj.name,
            "type": obj.type,
            "location": list(obj.location),
            "rotation_euler": list(obj.rotation_euler),
            "scale": list(obj.scale),
            "dimensions": list(obj.dimensions),
            "parent": obj.parent.name if obj.parent else None,
            "selected": obj.select_get(),
            "hide_render": obj.hide_render,
            "hide_viewport": obj.hide_viewport,
            "materials": [slot.material.name for slot in obj.material_slots if slot.material],
            "modifiers": [{"name": mod.name, "type": mod.type} for mod in obj.modifiers],
        }
        if obj.type == "MESH":
            item["vertices"] = len(obj.data.vertices)
            item["polygons"] = len(obj.data.polygons)
        objects.append(item)
    return {
        "blender_version": bpy.app.version_string,
        "file": bpy.data.filepath or None,
        "scene": scene.name,
        "object_count": len(scene.objects),
        "objects_truncated": len(scene.objects) > limit,
        "objects": objects,
        "collections": [collection.name for collection in bpy.data.collections],
        "materials": [material.name for material in bpy.data.materials],
        "active_object": bpy.context.active_object.name if bpy.context.active_object else None,
        "camera": scene.camera.name if scene.camera else None,
        "render_engine": scene.render.engine,
        "units": scene.unit_settings.system,
    }


def _geometry_bounds():
    points = []
    for obj in bpy.context.scene.objects:
        if obj.hide_render or obj.type not in {"MESH", "CURVE", "SURFACE", "FONT", "META"}:
            continue
        points.extend(obj.matrix_world @ Vector(corner) for corner in obj.bound_box)
    if not points:
        return Vector((0, 0, 0)), 2.0
    low = Vector(tuple(min(point[axis] for point in points) for axis in range(3)))
    high = Vector(tuple(max(point[axis] for point in points) for axis in range(3)))
    return (low + high) / 2, max(max(high - low), 0.1)


def _aim_camera(camera, view):
    center, size = _geometry_bounds()
    directions = {
        "three_quarter": Vector((1.4, -1.8, 1.1)),
        "front": Vector((0, -1, 0.12)),
        "side": Vector((1, 0, 0.12)),
        "top": Vector((0, -0.001, 1)),
    }
    direction = directions.get(view, directions["three_quarter"]).normalized()
    distance = size * 1.8
    camera.location = center + direction * distance
    camera.rotation_euler = (center - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.clip_start = max(distance / 1000, 0.001)
    camera.data.clip_end = max(distance * 20, 1000)


def _ensure_camera(view):
    scene = bpy.context.scene
    if scene.camera is None:
        data = bpy.data.cameras.new("CPORE Preview Camera")
        camera = bpy.data.objects.new(data.name, data)
        scene.collection.objects.link(camera)
        scene.camera = camera
        _aim_camera(camera, "three_quarter" if view == "current" else view)
    elif view != "current":
        _aim_camera(scene.camera, view)
    return scene.camera


def _project_root(params):
    configured = params.get("project_root") or os.environ.get("CPORE_PROJECT_ROOT")
    return Path(configured).expanduser().resolve() if configured else Path.home() / ".cache" / "cpore"


def _output_directory(params, kind):
    directory = _project_root(params) / "art" / "generated" / kind
    directory.mkdir(parents=True, exist_ok=True)
    return directory


def _render(params):
    width = int(params.get("width", 1024))
    height = int(params.get("height", 1024))
    if not 64 <= width <= 2048 or not 64 <= height <= 2048:
        raise ValueError("Render width and height must be between 64 and 2048")
    engine_name = params.get("engine", "WORKBENCH").upper()
    eevee = "BLENDER_EEVEE" if bpy.app.version >= (5, 0, 0) else "BLENDER_EEVEE_NEXT"
    engines = {"WORKBENCH": "BLENDER_WORKBENCH", "EEVEE": eevee, "CYCLES": "CYCLES"}
    if engine_name not in engines:
        raise ValueError("Engine must be WORKBENCH, EEVEE, or CYCLES")
    view = params.get("view", "current")
    if view not in {"current", "three_quarter", "front", "side", "top"}:
        raise ValueError("View must be current, three_quarter, front, side, or top")

    scene = bpy.context.scene
    camera_name = params.get("camera")
    if camera_name:
        camera = bpy.data.objects.get(camera_name)
        if camera is None or camera.type != "CAMERA":
            raise ValueError(f"Camera not found: {camera_name}")
        scene.camera = camera
    _ensure_camera(view)
    bpy.context.view_layer.update()

    render = scene.render
    old = (
        render.engine,
        render.resolution_x,
        render.resolution_y,
        render.resolution_percentage,
        render.filepath,
        render.image_settings.file_format,
        render.image_settings.color_mode,
        render.film_transparent,
    )
    path = _output_directory(params, "renders") / f"cpore-{uuid.uuid4().hex}.png"
    try:
        render.engine = engines[engine_name]
        render.resolution_x = width
        render.resolution_y = height
        render.resolution_percentage = 100
        render.image_settings.file_format = "PNG"
        render.image_settings.color_mode = "RGBA"
        render.film_transparent = bool(params.get("transparent", False))
        if engine_name == "WORKBENCH":
            shading = scene.display.shading
            shading.light = "STUDIO"
            shading.color_type = "MATERIAL"
            shading.show_shadows = True
            shading.show_cavity = True
            shading.cavity_type = "BOTH"
            shading.background_type = "VIEWPORT"
            shading.background_color = (0.035, 0.045, 0.065)
        render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
    finally:
        (
            render.engine,
            render.resolution_x,
            render.resolution_y,
            render.resolution_percentage,
            render.filepath,
            render.image_settings.file_format,
            render.image_settings.color_mode,
            render.film_transparent,
        ) = old
    return {
        "path": str(path),
        "width": width,
        "height": height,
        "engine": engine_name,
        "view": view,
        "camera": scene.camera.name,
    }


def _execute(params):
    code = params.get("code", "")
    if not isinstance(code, str) or not code.strip():
        raise ValueError("code must be a non-empty string")
    if len(code) > 200_000:
        raise ValueError("code exceeds 200000 characters")
    if not _namespace:
        _namespace.update({"__name__": "__cpore__", "bpy": bpy, "math": math})
    stdout = io.StringIO()
    stderr = io.StringIO()
    label = params.get("undo_label", "Cpore MCP edit")
    with contextlib.suppress(RuntimeError):
        bpy.ops.ed.undo_push(message=label)
    try:
        with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            exec(compile(code, "<cpore-mcp>", "exec"), _namespace)
        bpy.context.view_layer.update()
    except Exception:
        details = traceback.format_exc()
        raise RuntimeError(f"{details}\nstdout:\n{stdout.getvalue()}\nstderr:\n{stderr.getvalue()}") from None
    result = {
        "stdout": stdout.getvalue(),
        "stderr": stderr.getvalue(),
        "result": _json_value(_namespace.get("result")),
        "scene": _scene_info({"object_limit": 100}),
    }
    if params.get("render", False):
        render_options = dict(params.get("render_options", {}))
        render_options["project_root"] = params.get("project_root")
        result["render"] = _render(render_options)
    return result


def _target_path(params, extension, overwrite):
    raw_path = params.get("path")
    if not raw_path:
        raise ValueError("path is required")
    path = Path(raw_path).expanduser()
    if not path.is_absolute():
        path = _project_root(params) / path
    path = path.resolve()
    if path.suffix.lower() != extension:
        raise ValueError(f"path must end in {extension}")
    if path.exists() and not overwrite:
        raise FileExistsError(f"Refusing to overwrite existing file: {path}")
    path.parent.mkdir(parents=True, exist_ok=True)
    return path


def _export(params):
    path = _target_path(params, ".glb", bool(params.get("overwrite", False)))
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=bool(params.get("selected_only", False)),
        export_apply=bool(params.get("apply_modifiers", True)),
        export_animations=bool(params.get("animations", True)),
        export_yup=True,
    )
    return {"path": str(path), "bytes": path.stat().st_size, "format": "glTF 2.0 binary"}


def _save(params):
    path = _target_path(params, ".blend", bool(params.get("overwrite", False)))
    bpy.ops.wm.save_as_mainfile(filepath=str(path), compress=True, check_existing=False)
    return {"path": str(path), "bytes": path.stat().st_size}


def _dispatch(command, params):
    if command == "ping":
        return {
            "status": "ready",
            "blender_version": bpy.app.version_string,
            "pid": os.getpid(),
            "file": bpy.data.filepath or None,
            "scene": bpy.context.scene.name,
            "host": HOST,
            "port": PORT,
        }
    if command == "get_scene":
        return _scene_info(params)
    if command == "execute":
        return _execute(params)
    if command == "render":
        return _render(params)
    if command == "export":
        return _export(params)
    if command == "save":
        return _save(params)
    raise ValueError(f"Unknown command: {command}")


def _close_client():
    global _client, _buffer
    if _client is not None:
        with contextlib.suppress(OSError):
            _client.close()
    _client = None
    _buffer = bytearray()


def _poll_server():
    global _client, _buffer
    if _server is None:
        return None
    if _client is None:
        try:
            _client, _address = _server.accept()
            _client.setblocking(False)
            _buffer = bytearray()
        except BlockingIOError:
            return 0.1
    try:
        chunk = _client.recv(65536)
        if not chunk:
            _close_client()
            return 0.1
        _buffer.extend(chunk)
        if len(_buffer) > MAX_MESSAGE_BYTES:
            raise ValueError("Message exceeds 64 MiB")
        if b"\n" not in _buffer:
            return 0.1
        raw, _buffer = _buffer.split(b"\n", 1)
        request = json.loads(raw)
        request_id = request.get("id")
        params = request.get("params", {})
        if not isinstance(params, dict):
            raise TypeError("params must be an object")
        result = _dispatch(request.get("command"), params)
        response = {"id": request_id, "ok": True, "result": result}
    except Exception as error:
        request_id = None
        with contextlib.suppress(Exception):
            request_id = request.get("id")
        response = {"id": request_id, "ok": False, "error": str(error)}
    try:
        _client.setblocking(True)
        _client.settimeout(10)
        _client.sendall(json.dumps(response, ensure_ascii=False).encode("utf-8") + b"\n")
    finally:
        _close_client()
    return 0.1


def start_server():
    global _server
    if _server is not None:
        return
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind((HOST, PORT))
    server.listen(8)
    server.setblocking(False)
    _server = server
    if not bpy.app.background and not bpy.app.timers.is_registered(_poll_server):
        bpy.app.timers.register(_poll_server, first_interval=0.1, persistent=True)
    print(f"Cpore Design Bridge listening on {HOST}:{PORT}", flush=True)


def stop_server():
    global _server
    _close_client()
    if _server is not None:
        _server.close()
        _server = None
    if not bpy.app.background and bpy.app.timers.is_registered(_poll_server):
        bpy.app.timers.unregister(_poll_server)


class CPORE_OT_bridge_start(bpy.types.Operator):
    bl_idname = "cpore.bridge_start"
    bl_label = "Start Model Bridge"

    def execute(self, context):
        start_server()
        return {"FINISHED"}


class CPORE_OT_bridge_stop(bpy.types.Operator):
    bl_idname = "cpore.bridge_stop"
    bl_label = "Stop Model Bridge"

    def execute(self, context):
        stop_server()
        return {"FINISHED"}


class CPORE_PT_design_bridge(bpy.types.Panel):
    bl_label = "Cpore Design Bridge"
    bl_idname = "CPORE_PT_design_bridge"
    bl_space_type = "VIEW_3D"
    bl_region_type = "UI"
    bl_category = "Cpore"

    def draw(self, context):
        layout = self.layout
        layout.label(text=f"Loopback: {HOST}:{PORT}")
        layout.label(text="Running" if _server else "Stopped")
        layout.operator("cpore.bridge_start" if _server is None else "cpore.bridge_stop")
        layout.label(text="MCP can run Python. Trusted models only.", icon="ERROR")


CLASSES = (CPORE_OT_bridge_start, CPORE_OT_bridge_stop, CPORE_PT_design_bridge)


def register():
    for cls in CLASSES:
        bpy.utils.register_class(cls)


def unregister():
    stop_server()
    for cls in reversed(CLASSES):
        bpy.utils.unregister_class(cls)


if __name__ == "__main__":
    register()
    start_server()
    if bpy.app.background:
        try:
            while _server is not None:
                _poll_server()
                time.sleep(0.02)
        except KeyboardInterrupt:
            pass
        finally:
            unregister()
