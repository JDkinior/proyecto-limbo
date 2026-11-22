"""Custom MCP server for creating and editing CapCut Desktop (v191) projects."""

import glob
import hashlib
import json
import os
import shutil
import time
import uuid
from pathlib import Path
from typing import Any

from mcp.server.mcpserver import MCPServer

mcp = MCPServer("capcut")

CAPCUT_DRAFTS_DIR = Path(
    os.path.expandvars(r"%LOCALAPPDATA%\CapCut\User Data\Projects\com.lveditor.draft")
)
CAPCUT_CACHE_EFFECT_DIR = Path(
    os.path.expandvars(r"%LOCALAPPDATA%\CapCut\User Data\Cache\effect")
)
PRESET_COMBINATION_DIR = Path(
    os.path.expandvars(r"%LOCALAPPDATA%\CapCut\User Data\Presets\Combination\Resources")
)
US = 1_000_000  # CapCut uses microseconds for all timestamps and durations

TRANSITION_TEMPLATES: dict[str, dict[str, Any]] = {
    "Derecha": {
        "effect_id": "6724227599616184836",
        "third_resource_id": "6724227599616184836",
        "is_overlap": False,
        "category_id": "123456",
        "category_name": "Transiciones",
        "path": "C:/Users/degkp/AppData/Local/CapCut/User Data/Cache/effect/6724227599616184836/94ddc5b44c66c523dbf70622efb612d3",
    },
    "Izquierda": {
        "effect_id": "6724227717195108867",
        "third_resource_id": "6724227717195108867",
        "is_overlap": False,
        "category_id": "123456",
        "category_name": "Transiciones",
        "path": "C:/Users/degkp/AppData/Local/CapCut/User Data/Cache/effect/6724227717195108867/d623e56c3ec69ac4920fac8740b456ae",
    },
    "Arriba": {
        "effect_id": "6724227090872275463",
        "third_resource_id": "6724227090872275463",
        "is_overlap": False,
        "category_id": "123456",
        "category_name": "Transiciones",
        "path": "C:/Users/degkp/AppData/Local/CapCut/User Data/Cache/effect/6724227090872275463/349746a951e130fe896415f51c9eb36a",
    },
    "Abajo": {
        "effect_id": "6724227330190873100",
        "third_resource_id": "6724227330190873100",
        "is_overlap": False,
        "category_id": "123456",
        "category_name": "heycan_search_transition",
        "path": "C:/Users/degkp/AppData/Local/CapCut/User Data/Cache/effect/6724227330190873100/a61ca47476e8bdcde0a2cfc229b264cd",
    },
    "Zoom recto": {
        "effect_id": "7622889481779055889",
        "third_resource_id": "0",
        "is_overlap": True,
        "category_id": "123456",
        "category_name": "Transiciones",
        "path": "C:/Users/degkp/AppData/Local/CapCut/User Data/Cache/effect/7622889481779055889/469e21038849067abb6978e2fec926f6",
    },
    "Cambio con zoom": {
        "effect_id": "7602308758944976135",
        "third_resource_id": "0",
        "is_overlap": True,
        "category_id": "123456",
        "category_name": "heycan_search_transition",
        "path": "C:/Users/degkp/AppData/Local/CapCut/User Data/Cache/effect/7602308758944976135/353ac2812603b55dc97738f99e13b7ed",
    },
    "Deslizamiento con zoom": {
        "effect_id": "7488157742956350737",
        "third_resource_id": "0",
        "is_overlap": True,
        "category_id": "100000",
        "category_name": "",
        "path": "C:/Users/degkp/AppData/Local/CapCut/User Data/Cache/effect/7488157742956350737/b9c75e5e406051bcfda6a1048fbb2677",
    },
    "Alejamiento con velocidad": {
        "effect_id": "7488094700159782145",
        "third_resource_id": "0",
        "is_overlap": True,
        "category_id": "100000",
        "category_name": "",
        "path": "C:/Users/degkp/AppData/Local/CapCut/User Data/Cache/effect/7488094700159782145/8f3ae25af421f026ede897c2e469449c",
    },
    "Sacudida y cambio": {
        "effect_id": "7612877559063186695",
        "third_resource_id": "0",
        "is_overlap": True,
        "category_id": "123456",
        "category_name": "heycan_search_transition",
        "path": "C:/Users/degkp/AppData/Local/CapCut/User Data/Cache/effect/7612877559063186695/19daf73ddc35c8a05d57c36d972e764e",
    },
    "Movimiento": {
        "effect_id": "7198424967803834881",
        "third_resource_id": "7198424967803834881",
        "is_overlap": False,
        "category_id": "123456",
        "category_name": "Transiciones",
        "path": "C:/Users/degkp/AppData/Local/CapCut/User Data/Cache/effect/7198424967803834881/3a0fd76188f0955a96b967a9cce139b3",
    },
    "Woosh": {
        "effect_id": "6724239584663704071",
        "third_resource_id": "6724239584663704071",
        "is_overlap": False,
        "category_id": "100000",
        "category_name": "",
        "path": "C:/Users/degkp/AppData/Local/CapCut/User Data/Cache/effect/6724239584663704071/06cc8d49c558d57e21207f68a6a7dbc0",
    },
    "Acercar": {
        "effect_id": "6724226861666144779",
        "third_resource_id": "6724226861666144779",
        "is_overlap": False,
        "category_id": "100000",
        "category_name": "",
        "path": "C:/Users/degkp/AppData/Local/CapCut/User Data/Cache/effect/6724226861666144779/4d5a316f2eae582e7d0604b47feb8c32",
    },
}

VIDEO_EFFECT_TEMPLATES: dict[str, dict[str, Any]] = {
    "Movimiento tembloroso": {
        "effect_id": "7630797650480188679",
        "category_id": "1111",
        "category_name": "Efectos de video",
        "apply_target_type": 0,
        "render_index": 11000,
        "path": "C:/Users/degkp/AppData/Local/CapCut/User Data/Cache/effect/7630797650480188679/2b74f8efdcb042378d24062929263f8d",
        "adjust_params": [
            {"name": "effects_adjust_size", "value": 0.0, "default_value": 0.5},
            {"name": "effects_adjust_rotate", "value": 0.0, "default_value": 0.5},
            {"name": "effects_adjust_speed", "value": 1.0, "default_value": 0.2},
        ],
    },
    "Cámara en movimiento": {
        "effect_id": "7399466773713833222",
        "category_id": "1111",
        "category_name": "Efectos de video",
        "apply_target_type": 0,
        "render_index": 11000,
        "path": "C:/Users/degkp/AppData/Local/CapCut/User Data/Cache/effect/7399466773713833222/7cb6c1646c43d86a394245e194e3f451",
        "adjust_params": [
            {"name": "effects_adjust_range", "value": 1.0, "default_value": 0.15},
            {"name": "effects_adjust_speed", "value": 0.71, "default_value": 0.33},
        ],
    },
    "Movimiento": {
        "effect_id": "7399470393884527877",
        "category_id": "1111",
        "category_name": "heycan_search_special_effect",
        "apply_target_type": 0,
        "render_index": 11000,
        "path": "C:/Users/degkp/AppData/Local/CapCut/User Data/Cache/effect/7399470393884527877/d11532bfbfbd6f9af59026c2c42f2570",
        "adjust_params": [
            {"name": "effects_adjust_speed", "value": 0.33, "default_value": 0.33},
            {"name": "effects_adjust_intensity", "value": 0.5, "default_value": 0.5},
        ],
    },
    "Cuerpo tembloroso": {
        "effect_id": "7576470600101727493",
        "category_id": "1111",
        "category_name": "Efectos de video",
        "apply_target_type": 0,
        "render_index": 11000,
        "path": "C:/Users/degkp/AppData/Local/CapCut/User Data/Cache/effect/7576470600101727493/2c5fba5527cdd92af5c9c9438620457b",
        "adjust_params": [],
    },
    "Brillo 2": {
        "effect_id": "7409873342792043781",
        "category_id": "1111",
        "category_name": "heycan_search_special_effect",
        "apply_target_type": 2,
        "render_index": 0,
        "path": "C:/Users/degkp/AppData/Local/CapCut/User Data/Cache/effect/7409873342792043781/7ea9db818289cf323dc4eff20e79a23f",
        "adjust_params": [
            {"name": "effects_adjust_size", "value": 0.0, "default_value": 0.5},
            {"name": "effects_adjust_luminance", "value": 1.0, "default_value": 0.5},
        ],
    },
}

KINIOR_COLORS: dict[str, list[float]] = {
    "yellow": [0.95686274766922, 0.7803921699523926, 0.05882352963089943],
    "cyan": [0.11372549086809158, 0.5921568870544434, 1.0],
    "red": [1.0, 0.25, 0.25],
    "green": [0.2, 0.95, 0.4],
    "white": [1.0, 1.0, 1.0],
}


def _new_id() -> str:
    return str(uuid.uuid4()).upper()


def _md5_hex(text: str) -> str:
    return hashlib.md5(text.encode("utf-8")).hexdigest()


def _norm_path(path: str | Path) -> str:
    return str(Path(path).resolve()).replace("\\", "/")


def _get_main_timeline_id(proj_dir: Path, dc: dict[str, Any]) -> str:
    proj_json = proj_dir / "Timelines" / "project.json"
    if proj_json.exists():
        with open(proj_json, "r", encoding="utf-8") as f:
            pdata = json.load(f)
        tl_id = pdata.get("main_timeline_id")
        if tl_id:
            return tl_id
    return dc.get("id") or _new_id()


def _remove_lock_if_possible(proj_dir: Path) -> None:
    lock_file = proj_dir / ".locked"
    if lock_file.exists():
        try:
            lock_file.unlink()
        except PermissionError:
            pass


def _update_root_meta_info(proj_dir: Path, dm: dict[str, Any]) -> None:
    root_meta_path = CAPCUT_DRAFTS_DIR / "root_meta_info.json"
    if not root_meta_path.exists():
        return
    with open(root_meta_path, "r", encoding="utf-8") as f:
        rm = json.load(f)

    fold_path = str(proj_dir).replace("\\", "/")
    draft_name = dm.get("draft_name", proj_dir.name)
    entry = {
        "cloud_draft_cover": dm.get("cloud_draft_cover", False),
        "cloud_draft_sync": dm.get("cloud_draft_sync", False),
        "draft_cloud_last_action_download": dm.get("draft_cloud_last_action_download", False),
        "draft_cloud_purchase_info": dm.get("draft_cloud_purchase_info", ""),
        "draft_cloud_template_id": dm.get("draft_cloud_template_id", ""),
        "draft_cloud_tutorial_info": dm.get("draft_cloud_tutorial_info", ""),
        "draft_cloud_videocut_purchase_info": dm.get("draft_cloud_videocut_purchase_info", ""),
        "draft_cover": dm.get("draft_cover", "draft_cover.jpg"),
        "draft_fold_path": fold_path,
        "draft_id": dm.get("draft_id", _new_id()),
        "draft_is_ai_shorts": dm.get("draft_is_ai_shorts", False),
        "draft_is_cloud_temp_draft": dm.get("draft_is_cloud_temp_draft", False),
        "draft_is_invisible": dm.get("draft_is_invisible", False),
        "draft_is_web_article_video": dm.get("draft_is_web_article_video", False),
        "draft_json_file": f"{fold_path}/draft_content.json",
        "draft_name": draft_name,
        "draft_new_version": dm.get("draft_new_version", ""),
        "draft_root_path": str(CAPCUT_DRAFTS_DIR).replace("\\", "/"),
        "draft_timeline_materials_size": dm.get("draft_timeline_materials_size_", 0),
        "draft_type": dm.get("draft_type", ""),
        "tm_draft_cloud_completed": dm.get("tm_draft_cloud_completed", ""),
        "tm_draft_cloud_entry_id": dm.get("tm_draft_cloud_entry_id", -1),
        "tm_draft_cloud_modified": dm.get("tm_draft_cloud_modified", 0),
        "tm_draft_cloud_parent_entry_id": dm.get("tm_draft_cloud_parent_entry_id", -1),
        "tm_draft_cloud_space_id": dm.get("tm_draft_cloud_space_id", -1),
        "tm_draft_cloud_user_id": dm.get("tm_draft_cloud_user_id", -1),
        "tm_draft_create": dm.get("tm_draft_create", int(time.time() * US)),
        "tm_draft_modified": dm.get("tm_draft_modified", int(time.time() * US)),
        "tm_draft_removed": dm.get("tm_draft_removed", 0),
        "tm_duration": dm.get("tm_duration", 0),
    }

    store = rm.setdefault("all_draft_store", [])
    replaced = False
    for idx, item in enumerate(store):
        if item.get("draft_fold_path") == fold_path or item.get("draft_name") == draft_name:
            # Preserve existing fields if present, updating key metadata
            updated = dict(item)
            updated.update({
                "draft_fold_path": fold_path,
                "draft_id": entry["draft_id"],
                "draft_json_file": entry["draft_json_file"],
                "draft_name": draft_name,
                "tm_draft_modified": entry["tm_draft_modified"],
                "tm_duration": entry["tm_duration"],
            })
            store[idx] = updated
            replaced = True
            break
    if not replaced:
        store.insert(0, entry)
        rm["draft_ids"] = rm.get("draft_ids", len(store)) + 1

    with open(root_meta_path, "w", encoding="utf-8") as f:
        json.dump(rm, f, ensure_ascii=False)


def _load_draft(project_name: str) -> tuple[Path, dict[str, Any]]:
    proj_dir = CAPCUT_DRAFTS_DIR / project_name
    dc_path = proj_dir / "draft_content.json"
    if not dc_path.exists():
        raise FileNotFoundError(f"CapCut project '{project_name}' not found at {proj_dir}")
    with open(dc_path, "r", encoding="utf-8") as f:
        dc = json.load(f)
    tl_id = _get_main_timeline_id(proj_dir, dc)
    dc["id"] = tl_id
    return proj_dir, dc


def _save_draft(proj_dir: Path, dc: dict[str, Any]) -> None:
    _remove_lock_if_possible(proj_dir)
    main_tl_id = _get_main_timeline_id(proj_dir, dc)
    dc["id"] = main_tl_id

    payload = json.dumps(dc, ensure_ascii=False)

    # Write root files
    for fname in ("draft_content.json", "draft_content.json.bak", "template-2.tmp"):
        (proj_dir / fname).write_text(payload, encoding="utf-8")

    # Write matching main timeline files and clear stale patch cache
    tl_dir = proj_dir / "Timelines" / main_tl_id
    if tl_dir.exists():
        for fname in ("draft_content.json", "draft_content.json.bak", "template-2.tmp"):
            (tl_dir / fname).write_text(payload, encoding="utf-8")
        patch_dir = tl_dir / "attachment" / "patch"
        if patch_dir.exists():
            shutil.rmtree(patch_dir)

    # Update draft_meta_info.json and root_meta_info.json
    dm_path = proj_dir / "draft_meta_info.json"
    if dm_path.exists():
        with open(dm_path, "r", encoding="utf-8") as f:
            dm = json.load(f)
        dm["tm_draft_modified"] = int(time.time() * US)
        dm["tm_duration"] = dc.get("duration", 0)
        with open(dm_path, "w", encoding="utf-8") as f:
            json.dump(dm, f, ensure_ascii=False)
        _update_root_meta_info(proj_dir, dm)


def _sync_timeline_ids(proj_dir: Path, tl_id: str) -> None:
    proj_json = proj_dir / "Timelines" / "project.json"
    if proj_json.exists():
        with open(proj_json, "r", encoding="utf-8") as f:
            pdata = json.load(f)
        old_tl_id = pdata.get("main_timeline_id")
        if old_tl_id and old_tl_id != tl_id:
            old_dir = proj_dir / "Timelines" / old_tl_id
            new_dir = proj_dir / "Timelines" / tl_id
            if old_dir.exists() and not new_dir.exists():
                old_dir.rename(new_dir)
        pdata["main_timeline_id"] = tl_id
        for tl in pdata.get("timelines", []):
            if not tl.get("is_marked_delete"):
                tl["id"] = tl_id
                break
        with open(proj_json, "w", encoding="utf-8") as f:
            json.dump(pdata, f, ensure_ascii=False)
        bak = proj_dir / "Timelines" / "project.json.bak"
        if bak.exists():
            shutil.copy2(proj_json, bak)

    layout_json = proj_dir / "timeline_layout.json"
    if layout_json.exists():
        with open(layout_json, "r", encoding="utf-8") as f:
            ldata = json.load(f)
        for dock in ldata.get("dockItems", []):
            if dock.get("timelineIds"):
                dock["timelineIds"][0] = tl_id
        with open(layout_json, "w", encoding="utf-8") as f:
            json.dump(ldata, f, ensure_ascii=False)


def _ensure_meta_material(
    proj_dir: Path,
    abs_path: str,
    metetype: str,
    duration_us: int,
    width: int = 0,
    height: int = 0,
    extra_info: str = "",
) -> str:
    dm_path = proj_dir / "draft_meta_info.json"
    if not dm_path.exists():
        return str(uuid.uuid4())
    with open(dm_path, "r", encoding="utf-8") as f:
        dm = json.load(f)

    buckets = dm.setdefault("draft_materials", [])
    bucket0 = None
    for b in buckets:
        if b.get("type") == 0:
            bucket0 = b
            break
    if bucket0 is None:
        bucket0 = {"type": 0, "value": []}
        buckets.insert(0, bucket0)

    for item in bucket0.get("value", []):
        if item.get("file_Path") == abs_path:
            return item.get("id", str(uuid.uuid4()))

    local_mat_id = str(uuid.uuid4())
    now_s = int(time.time())
    bucket0.setdefault("value", []).append({
        "ai_group_type": "",
        "create_time": now_s,
        "duration": duration_us,
        "enter_from": 0,
        "extra_info": extra_info or Path(abs_path).name,
        "file_Path": abs_path,
        "height": height,
        "id": local_mat_id,
        "import_time": now_s,
        "import_time_ms": 0,
        "item_source": 1,
        "material_color_tag": "",
        "md5": "",
        "metetype": metetype,
        "roughcut_time_range": {"duration": duration_us, "start": 0},
        "sub_time_range": {"duration": -1, "start": -1},
        "type": 0,
        "width": width,
    })
    with open(dm_path, "w", encoding="utf-8") as f:
        json.dump(dm, f, ensure_ascii=False)
    return local_mat_id


def _get_or_create_track(dc: dict[str, Any], track_type: str, slot: int = 0) -> dict[str, Any]:
    tracks = dc.setdefault("tracks", [])
    matching = [t for t in tracks if t.get("type") == track_type]
    while len(matching) <= slot:
        new_track = {
            "attribute": 0,
            "flag": 1 if track_type == "text" else 0,
            "id": _new_id(),
            "is_default_name": True,
            "name": "",
            "segments": [],
            "type": track_type,
        }
        tracks.append(new_track)
        matching.append(new_track)
    return matching[slot]


def _resolve_effect_path(default_path: str, resource_id: str) -> str:
    rid_dir = CAPCUT_CACHE_EFFECT_DIR / resource_id
    if rid_dir.is_dir():
        subdirs = [p for p in rid_dir.iterdir() if p.is_dir()]
        if subdirs:
            return str(subdirs[0]).replace("\\", "/")
    return default_path


def _set_keyframe_prop(
    common_keyframes: list[dict[str, Any]],
    prop_type: str,
    t0: int,
    v0: float,
    t1: int,
    v1: float,
) -> None:
    common_keyframes[:] = [kf for kf in common_keyframes if kf.get("property_type") != prop_type]
    common_keyframes.append({
        "id": _new_id(),
        "material_id": "",
        "property_type": prop_type,
        "keyframe_list": [
            {
                "id": _new_id(),
                "curveType": "Line",
                "time_offset": t0,
                "left_control": {"x": 0.0, "y": 0.0},
                "right_control": {"x": 0.0, "y": 0.0},
                "values": [float(v0)],
                "string_value": "",
                "graphID": "",
            },
            {
                "id": _new_id(),
                "curveType": "Line",
                "time_offset": t1,
                "left_control": {"x": 0.0, "y": 0.0},
                "right_control": {"x": 0.0, "y": 0.0},
                "values": [float(v1)],
                "string_value": "",
                "graphID": "",
            },
        ],
    })


def _update_duration(dc: dict[str, Any]) -> None:
    max_end = 0
    for track in dc.get("tracks", []):
        for seg in track.get("segments", []):
            tr = seg.get("target_timerange", {})
            end = tr.get("start", 0) + tr.get("duration", 0)
            if end > max_end:
                max_end = end
    dc["duration"] = max_end


def _pick_template_dir() -> Path | None:
    preferred = CAPCUT_DRAFTS_DIR / "1111"
    if preferred.is_dir() and (preferred / "draft_content.json").exists():
        return preferred
    for p in CAPCUT_DRAFTS_DIR.iterdir():
        if p.is_dir() and (p / "draft_content.json").exists():
            return p
    return None


@mcp.tool()
def list_projects() -> list[str]:
    """List all CapCut Desktop projects in the local drafts folder."""
    if not CAPCUT_DRAFTS_DIR.exists():
        return []
    return sorted(
        p.name for p in CAPCUT_DRAFTS_DIR.iterdir() if p.is_dir() and (p / "draft_content.json").exists()
    )


@mcp.tool()
def clone_project(source_name: str, target_name: str, overwrite: bool = False) -> str:
    """Clone an existing CapCut Desktop project cleanly with synchronized timeline and root metadata."""
    src = CAPCUT_DRAFTS_DIR / source_name
    dst = CAPCUT_DRAFTS_DIR / target_name
    if not src.exists():
        return f"Source project '{source_name}' not found at {src}"
    if dst.exists():
        if not overwrite:
            return f"Target project '{target_name}' already exists at {dst}"
        shutil.rmtree(dst, ignore_errors=True)

    def _copy_tolerant(src_file: str, dst_file: str) -> str:
        try:
            return shutil.copy2(src_file, dst_file)
        except PermissionError:
            if os.path.exists(dst_file):
                return dst_file
            raise

    shutil.copytree(src, dst, dirs_exist_ok=True, copy_function=_copy_tolerant)
    _remove_lock_if_possible(dst)

    new_draft_id = _new_id()
    now_us = int(time.time() * US)

    with open(dst / "draft_content.json", "r", encoding="utf-8") as f:
        dc = json.load(f)
    main_tl_id = _get_main_timeline_id(dst, dc)
    dc["id"] = main_tl_id
    _sync_timeline_ids(dst, main_tl_id)

    dm_path = dst / "draft_meta_info.json"
    if dm_path.exists():
        with open(dm_path, "r", encoding="utf-8") as f:
            dm = json.load(f)
        dm["draft_id"] = new_draft_id
        dm["draft_name"] = target_name
        dm["draft_fold_path"] = str(dst).replace("\\", "/")
        dm["tm_draft_create"] = now_us
        dm["tm_draft_modified"] = now_us
        dm["tm_duration"] = dc.get("duration", 0)
        with open(dm_path, "w", encoding="utf-8") as f:
            json.dump(dm, f, ensure_ascii=False)
        _update_root_meta_info(dst, dm)

    _save_draft(dst, dc)
    return f"Cloned '{source_name}' -> '{target_name}' at {dst}"


@mcp.tool()
def create_project(
    name: str,
    width: int = 1080,
    height: int = 1920,
    fps: float = 60.0,
) -> str:
    """Create a new empty CapCut Desktop project with valid v191 schema and timeline sync."""
    dst = CAPCUT_DRAFTS_DIR / name
    if dst.exists():
        return f"Project '{name}' already exists at {dst}"

    template_dir = _pick_template_dir()
    if template_dir is None:
        return "No existing CapCut project found to use as template."

    shutil.copytree(template_dir, dst)
    _remove_lock_if_possible(dst)

    new_draft_id = _new_id()
    new_tl_id = _new_id()
    now_us = int(time.time() * US)

    dc_path = dst / "draft_content.json"
    with open(dc_path, "r", encoding="utf-8") as f:
        dc = json.load(f)

    dc["id"] = new_tl_id
    dc["fps"] = fps
    dc["duration"] = 0
    dc["tracks"] = []
    if "canvas_config" in dc:
        dc["canvas_config"]["width"] = width
        dc["canvas_config"]["height"] = height
        gcd_val = 9 if width == 1080 and height == 1920 else None
        dc["canvas_config"]["ratio"] = "9:16" if gcd_val else f"{width}:{height}"
    for key, val in dc.get("materials", {}).items():
        if isinstance(val, list):
            dc["materials"][key] = []

    _sync_timeline_ids(dst, new_tl_id)

    dm_path = dst / "draft_meta_info.json"
    if dm_path.exists():
        with open(dm_path, "r", encoding="utf-8") as f:
            dm = json.load(f)
        dm["draft_id"] = new_draft_id
        dm["draft_name"] = name
        dm["draft_fold_path"] = str(dst).replace("\\", "/")
        dm["tm_draft_create"] = now_us
        dm["tm_draft_modified"] = now_us
        dm["tm_duration"] = 0
        dm["draft_timeline_materials_size_"] = 0
        dm["draft_materials"] = [{"type": t, "value": []} for t in (0, 1, 2, 3, 6, 7, 8)]
        with open(dm_path, "w", encoding="utf-8") as f:
            json.dump(dm, f, ensure_ascii=False)

    _save_draft(dst, dc)
    return f"Created CapCut project '{name}' ({width}x{height} @ {fps}fps) at {dst}"


def _build_video_material(
    abs_path: str,
    file_duration_us: int,
    width: int,
    height: int,
    local_mat_id: str,
) -> dict[str, Any]:
    return {
        "id": _new_id(),
        "unique_id": _md5_hex(abs_path),
        "type": "video",
        "duration": file_duration_us,
        "path": abs_path,
        "media_path": "",
        "local_id": "",
        "has_audio": True,
        "reverse_path": "",
        "intensifies_path": "",
        "reverse_intensifies_path": "",
        "intensifies_audio_path": "",
        "cartoon_path": "",
        "width": width,
        "height": height,
        "category_id": "",
        "category_name": "local",
        "material_id": "",
        "material_name": Path(abs_path).name,
        "material_url": "",
        "crop": {
            "upper_left_x": 0.0,
            "upper_left_y": 0.0,
            "upper_right_x": 1.0,
            "upper_right_y": 0.0,
            "lower_left_x": 0.0,
            "lower_left_y": 1.0,
            "lower_right_x": 1.0,
            "lower_right_y": 1.0,
        },
        "crop_ratio": "free",
        "audio_fade": None,
        "crop_scale": 1.0,
        "extra_type_option": 0,
        "stable": {"stable_level": 0, "matrix_path": "", "time_range": {"start": 0, "duration": 0}},
        "matting": {
            "flag": 0,
            "path": "",
            "interactiveTime": [],
            "has_use_quick_brush": False,
            "strokes": [],
            "has_use_quick_eraser": False,
            "expansion": 0,
            "feather": 0,
            "reverse": False,
            "custom_matting_id": "",
            "enable_matting_stroke": False,
            "is_clould": False,
            "mask_video_path": "",
            "cloud_product_fps": 0.0,
        },
        "source": 0,
        "source_platform": 0,
        "formula_id": "",
        "check_flag": 62978047,
        "video_algorithm": {
            "algorithms": [],
            "time_range": None,
            "path": "",
            "gameplay_configs": [],
            "ai_in_painting_config": [],
            "complement_frame_config": None,
            "motion_blur_config": None,
            "deflicker": None,
            "noise_reduction": None,
            "quality_enhance": None,
            "super_resolution": None,
            "ai_background_configs": [],
            "smart_complement_frame": None,
            "aigc_generate": None,
            "aigc_generate_list": [],
            "mouth_shape_driver": None,
            "ai_expression_driven": None,
            "ai_motion_driven": None,
            "image_interpretation": None,
            "story_video_modify_video_config": {
                "task_id": "",
                "is_overwrite_last_video": False,
                "tracker_task_id": "",
                "generate_id": "",
                "generate_card_id": "",
            },
            "skip_algorithm_index": [],
        },
        "is_unified_beauty_mode": False,
        "is_set_beauty_mode": False,
        "object_locked": None,
        "smart_motion": None,
        "multi_camera_info": None,
        "freeze": None,
        "picture_from": "none",
        "picture_set_category_id": "",
        "picture_set_category_name": "",
        "team_id": "",
        "local_material_id": local_mat_id,
        "origin_material_id": "",
        "request_id": "",
        "has_sound_separated": False,
        "is_text_edit_overdub": False,
        "is_ai_generate_content": False,
        "is_video_copilot_aigc_content": False,
        "aigc_type": "none",
        "is_copyright": False,
        "aigc_history_id": "",
        "aigc_item_id": "",
        "local_material_from": "",
        "smart_match_info": None,
        "beauty_face_preset_infos": [],
        "beauty_body_preset_id": "",
        "beauty_face_auto_preset": {"preset_id": "", "name": "", "rate_map": "", "scene": ""},
        "beauty_face_auto_preset_infos": [],
        "beauty_body_auto_preset": None,
        "live_photo_timestamp": -1,
        "live_photo_cover_path": "",
        "content_feature_info": None,
        "corner_pin": None,
        "surface_trackings": [],
        "video_mask_stroke": {
            "resource_id": "",
            "path": "",
            "type": "",
            "color": "",
            "size": 0.0,
            "alpha": 0.0,
            "distance": 0.0,
            "texture": 0.0,
            "horizontal_shift": 0.0,
            "vertical_shift": 0.0,
        },
        "video_mask_shadow": {
            "resource_id": "",
            "path": "",
            "color": "",
            "alpha": 0.0,
            "blur": 0.0,
            "distance": 0.0,
            "angle": 0.0,
        },
        "pre_applied_vip_materials": [],
        "workflow_node_id": "",
    }


def _attach_common_segment_refs(dc: dict[str, Any], speed: float) -> list[str]:
    mats = dc.setdefault("materials", {})
    spd_id = _new_id()
    ph_id = _new_id()
    cv_id = _new_id()
    ma_id = _new_id()
    scm_id = _new_id()
    mc_id = _new_id()
    vs_id = _new_id()

    mats.setdefault("speeds", []).append({
        "id": spd_id,
        "type": "speed",
        "mode": 0,
        "speed": speed,
        "curve_speed": None,
    })
    mats.setdefault("placeholder_infos", []).append({
        "id": ph_id,
        "type": "placeholder_info",
        "meta_type": "none",
        "res_path": "",
        "res_text": "",
        "error_path": "",
        "error_text": "",
    })
    mats.setdefault("canvases", []).append({
        "id": cv_id,
        "type": "canvas_color",
        "color": "",
        "blur": 0.0,
        "image": "",
        "album_image": "",
        "image_id": "",
        "image_name": "",
        "source_platform": 0,
        "team_id": "",
    })
    mats.setdefault("material_animations", []).append({
        "id": ma_id,
        "type": "sticker_animation",
        "animations": [],
        "multi_language_current": "none",
    })
    mats.setdefault("sound_channel_mappings", []).append({
        "id": scm_id,
        "type": "none",
        "audio_channel_mapping": 0,
        "is_config_open": False,
    })
    mats.setdefault("material_colors", []).append({
        "id": mc_id,
        "is_color_clip": False,
        "is_gradient": False,
        "solid_color": "",
        "gradient_colors": [],
        "gradient_percents": [],
        "gradient_angle": 90.0,
        "width": 0.0,
        "height": 0.0,
    })
    mats.setdefault("vocal_separations", []).append({
        "id": vs_id,
        "type": "vocal_separation",
        "choice": 0,
        "removed_sounds": [],
        "time_range": None,
        "production_path": "",
        "final_algorithm": "",
        "enter_from": "",
    })
    return [spd_id, ph_id, cv_id, ma_id, scm_id, mc_id, vs_id]


def _build_segment(
    material_id: str,
    source_timerange: dict[str, int] | None,
    target_start_us: int,
    target_duration_us: int,
    extra_material_refs: list[str],
    speed: float = 1.0,
    volume: float = 1.0,
    clip: dict[str, Any] | None = None,
    uniform_scale: dict[str, Any] | None = None,
    render_index: int = 0,
    track_render_index: int = 0,
    enable_lut: bool = True,
    enable_adjust: bool = True,
    enable_hsl: bool = False,
    enable_adjust_mask: bool = False,
    hdr_settings: dict[str, Any] | None = None,
) -> dict[str, Any]:
    return {
        "id": _new_id(),
        "source_timerange": source_timerange,
        "target_timerange": {
            "start": target_start_us,
            "duration": target_duration_us,
        },
        "render_timerange": {"start": 0, "duration": 0},
        "desc": "",
        "state": 0,
        "speed": speed,
        "is_loop": False,
        "is_tone_modify": False,
        "reverse": False,
        "intensifies_audio": False,
        "cartoon": False,
        "volume": volume,
        "last_nonzero_volume": 1.0 if volume == 0.0 else volume,
        "clip": clip,
        "uniform_scale": uniform_scale,
        "material_id": material_id,
        "extra_material_refs": extra_material_refs,
        "render_index": render_index,
        "keyframe_refs": [],
        "enable_lut": enable_lut,
        "enable_adjust": enable_adjust,
        "enable_hsl": enable_hsl,
        "visible": True,
        "group_id": "",
        "enable_color_curves": True,
        "enable_hsl_curves": True,
        "track_render_index": track_render_index,
        "hdr_settings": hdr_settings,
        "hdr_vivid_settings": None,
        "enable_color_wheels": True,
        "track_attribute": 0,
        "is_placeholder": False,
        "template_id": "",
        "enable_smart_color_adjust": False,
        "template_scene": "default",
        "common_keyframes": [],
        "caption_info": None,
        "responsive_layout": {
            "enable": False,
            "target_follow": "",
            "size_layout": 0,
            "horizontal_pos_layout": 0,
            "vertical_pos_layout": 0,
        },
        "enable_color_match_adjust": False,
        "enable_color_correct_adjust": False,
        "enable_adjust_mask": enable_adjust_mask,
        "raw_segment_id": "",
        "lyric_keyframes": None,
        "enable_video_mask": True,
        "digital_human_template_group_id": "",
        "color_correct_alg_result": "",
        "source": "segmentsourcenormal",
        "enable_mask_stroke": False,
        "enable_mask_shadow": False,
        "enable_color_adjust_pro": False,
        "segment_color_tag": "",
    }


@mcp.tool()
def add_video_clip(
    project_name: str,
    file_path: str,
    source_start_sec: float = 0.0,
    duration_sec: float = 5.0,
    timeline_start_sec: float = 0.0,
    speed: float = 1.0,
    scale: float = 3.2,
    transform_x: float = 0.0,
    transform_y: float = 0.0,
    volume: float = 1.0,
    width: int = 1920,
    height: int = 1080,
    file_duration_sec: float = 60.0,
    target_start_us: int | None = None,
    target_duration_us: int | None = None,
) -> str:
    """Add a video clip with complete CapCut v191 metadata and linked refs to Track 0."""
    proj_dir, dc = _load_draft(project_name)
    abs_path = _norm_path(file_path)
    file_dur_us = max(int(round(file_duration_sec * US)), int(round((source_start_sec + duration_sec * speed) * US)))

    local_mat_id = _ensure_meta_material(
        proj_dir, abs_path, metetype="video", duration_us=file_dur_us, width=width, height=height
    )

    videos = dc.setdefault("materials", {}).setdefault("videos", [])
    existing_mat = next((v for v in videos if v.get("path") == abs_path), None)
    if existing_mat is not None:
        mat_id = existing_mat["id"]
    else:
        mat_doc = _build_video_material(abs_path, file_dur_us, width, height, local_mat_id)
        videos.append(mat_doc)
        mat_id = mat_doc["id"]

    t_start_us = target_start_us if target_start_us is not None else int(round(timeline_start_sec * US))
    t_dur_us = target_duration_us if target_duration_us is not None else int(round(duration_sec * US))
    s_start_us = int(round(source_start_sec * US))
    s_dur_us = int(round(t_dur_us * speed))

    extra_refs = _attach_common_segment_refs(dc, speed)
    seg = _build_segment(
        material_id=mat_id,
        source_timerange={"start": s_start_us, "duration": s_dur_us},
        target_start_us=t_start_us,
        target_duration_us=t_dur_us,
        extra_material_refs=extra_refs,
        speed=speed,
        volume=volume,
        clip={
            "scale": {"x": scale, "y": scale},
            "rotation": 0.0,
            "rotation3d": [],
            "transform": {"x": transform_x, "y": transform_y},
            "flip": {"vertical": False, "horizontal": False},
            "alpha": 1.0,
        },
        uniform_scale={"on": True, "value": 1.0},
        render_index=0,
        track_render_index=0,
        enable_lut=True,
        enable_adjust=True,
        enable_hsl=False,
        enable_adjust_mask=False,
        hdr_settings={"mode": 1, "intensity": 1.0, "nits": 1000},
    )

    track = _get_or_create_track(dc, "video")
    track["segments"].append(seg)
    track["segments"].sort(key=lambda s: s["target_timerange"]["start"])

    _update_duration(dc)
    _save_draft(proj_dir, dc)
    return (
        f"Added video '{Path(file_path).name}' to '{project_name}' "
        f"at {t_start_us / US:.3f}s ({t_dur_us / US:.3f}s, {speed}x)"
    )


@mcp.tool()
def add_audio_clip(
    project_name: str,
    file_path: str,
    source_start_sec: float = 0.0,
    duration_sec: float = 5.0,
    timeline_start_sec: float = 0.0,
    speed: float = 1.0,
    volume: float = 1.0,
    file_duration_sec: float = 60.0,
    track_slot: int = 0,
) -> str:
    """Add an audio clip with complete CapCut v191 metadata and linked refs to an audio track."""
    proj_dir, dc = _load_draft(project_name)
    abs_path = _norm_path(file_path)
    file_dur_us = max(int(round(file_duration_sec * US)), int(round((source_start_sec + duration_sec * speed) * US)))

    local_mat_id = _ensure_meta_material(
        proj_dir, abs_path, metetype="music", duration_us=file_dur_us
    )

    audios = dc.setdefault("materials", {}).setdefault("audios", [])
    existing_mat = next((a for a in audios if a.get("path") == abs_path), None)
    if existing_mat is not None:
        mat_id = existing_mat["id"]
    else:
        mat_id = _new_id()
        audios.append({
            "id": mat_id,
            "unique_id": _md5_hex(abs_path),
            "type": "extract_music",
            "name": Path(file_path).name,
            "duration": file_dur_us,
            "path": abs_path,
            "category_name": "local",
            "wave_points": [],
            "music_id": "",
            "app_id": 0,
            "text_id": "",
            "tone_type": "",
            "source_platform": 0,
            "video_id": "",
            "effect_id": "",
            "resource_id": "",
            "third_resource_id": "",
            "category_id": "",
            "intensifies_path": "",
            "formula_id": "",
            "check_flag": 1,
            "team_id": "",
            "local_material_id": local_mat_id,
            "tone_speaker": "",
            "mock_tone_speaker": "",
            "tone_effect_id": "",
            "tone_effect_name": "",
            "tone_platform": "",
            "cloned_model_type": "",
            "tone_category_id": "",
            "tone_category_name": "",
            "tone_second_category_id": "",
            "tone_second_category_name": "",
            "tone_emotion_name_key": "",
            "tone_emotion_style": "",
            "tone_emotion_role": "",
            "tone_emotion_selection": "",
            "tone_emotion_scale": 0.0,
            "moyin_emotion": "",
            "request_id": "",
            "query": "",
            "search_id": "",
            "sound_separate_type": "",
            "is_text_edit_overdub": False,
            "is_ugc": False,
            "is_ai_clone_tone": False,
            "is_ai_clone_tone_post": False,
            "source_from": "",
            "copyright_limit_type": "none",
            "aigc_history_id": "",
            "aigc_item_id": "",
            "music_source": "",
            "pgc_id": "",
            "pgc_name": "",
            "similiar_music_info": {"original_song_id": "", "original_song_name": ""},
            "ai_music_type": 0,
            "ai_music_enter_from": "",
            "lyric_type": 0,
            "tts_task_id": "",
            "tts_generate_scene": "",
            "ai_music_generate_scene": 0,
            "tts_benefit_info": {
                "benefit_type": "none",
                "benefit_log_id": "",
                "benefit_log_extra": "",
                "benefit_amount": -1,
            },
            "tts_language_info": None,
            "is_ai_generate_content": False,
            "aigc_audio_type": "none",
            "aigc_audio_generate_info": None,
        })

    mats = dc.setdefault("materials", {})
    spd_id = _new_id()
    ph_id = _new_id()
    beats_id = _new_id()
    scm_id = _new_id()
    vs_id = _new_id()

    mats.setdefault("speeds", []).append({
        "id": spd_id,
        "type": "speed",
        "mode": 0,
        "speed": speed,
        "curve_speed": None,
    })
    mats.setdefault("placeholder_infos", []).append({
        "id": ph_id,
        "type": "placeholder_info",
        "meta_type": "none",
        "res_path": "",
        "res_text": "",
        "error_path": "",
        "error_text": "",
    })
    mats.setdefault("beats", []).append({
        "id": beats_id,
        "type": "beats",
        "enable_ai_beats": False,
        "gear": 404,
        "gear_count": 0,
        "mode": 404,
        "user_beats": [],
        "user_delete_ai_beats": None,
        "ai_beats": {
            "melody_url": "",
            "melody_path": "",
            "beats_url": "",
            "beats_path": "",
            "melody_percents": [0.0],
            "beat_speed_infos": [],
        },
    })
    mats.setdefault("sound_channel_mappings", []).append({
        "id": scm_id,
        "type": "none",
        "audio_channel_mapping": 0,
        "is_config_open": False,
    })
    mats.setdefault("vocal_separations", []).append({
        "id": vs_id,
        "type": "vocal_separation",
        "choice": 0,
        "removed_sounds": [],
        "time_range": None,
        "production_path": "",
        "final_algorithm": "",
        "enter_from": "",
    })

    t_start_us = int(round(timeline_start_sec * US))
    t_dur_us = int(round(duration_sec * US))
    s_start_us = int(round(source_start_sec * US))
    s_dur_us = int(round(t_dur_us * speed))

    seg = _build_segment(
        material_id=mat_id,
        source_timerange={"start": s_start_us, "duration": s_dur_us},
        target_start_us=t_start_us,
        target_duration_us=t_dur_us,
        extra_material_refs=[spd_id, ph_id, beats_id, scm_id, vs_id],
        speed=speed,
        volume=volume,
        clip=None,
        uniform_scale=None,
        render_index=0,
        track_render_index=1,
        enable_lut=False,
        enable_adjust=False,
        enable_hsl=False,
        enable_adjust_mask=False,
        hdr_settings=None,
    )

    track = _get_or_create_track(dc, "audio", slot=track_slot)
    track["segments"].append(seg)
    track["segments"].sort(key=lambda s: s["target_timerange"]["start"])

    _update_duration(dc)
    _save_draft(proj_dir, dc)
    return f"Added audio '{Path(file_path).name}' to '{project_name}' at {timeline_start_sec}s ({duration_sec}s)"


def _build_text_styles(
    text: str,
    font_size: float,
    highlight_words: list[str] | None,
    highlight_rgb: list[float],
    stroke_width: float = 0.08,
) -> list[dict[str, Any]]:
    def _style_entry(start: int, end: int, color_rgb: list[float]) -> dict[str, Any]:
        return {
            "fill": {"content": {"render_type": "solid", "solid": {"color": color_rgb}}},
            "strokes": [{
                "content": {"render_type": "solid", "solid": {"color": [0.0, 0.0, 0.0]}},
                "width": stroke_width,
                "mode": 0,
            }],
            "size": font_size,
            "bold_width": 0.008,
            "useLetterColor": True,
            "range": [start, end],
        }

    white = KINIOR_COLORS["white"]
    n = len(text)
    if not highlight_words or n == 0:
        return [_style_entry(0, n, white)]

    lower_text = text.lower()
    raw_spans: list[tuple[int, int]] = []
    for phrase in highlight_words:
        token = (phrase or "").strip().lower()
        if not token:
            continue
        pos = 0
        while True:
            idx = lower_text.find(token, pos)
            if idx == -1:
                break
            raw_spans.append((idx, idx + len(token)))
            pos = idx + len(token)

    if not raw_spans:
        return [_style_entry(0, n, white)]

    raw_spans.sort()
    merged: list[tuple[int, int]] = []
    for s, e in raw_spans:
        if not merged or s > merged[-1][1]:
            merged.append((s, e))
        else:
            merged[-1] = (merged[-1][0], max(merged[-1][1], e))

    styles: list[dict[str, Any]] = []
    cursor = 0
    for s, e in merged:
        if cursor < s:
            styles.append(_style_entry(cursor, s, white))
        styles.append(_style_entry(s, e, highlight_rgb))
        cursor = e
    if cursor < n:
        styles.append(_style_entry(cursor, n, white))
    return styles


def _add_styled_text_segment(
    project_name: str,
    text: str,
    target_start_us: int,
    target_duration_us: int,
    font_size: float,
    transform_y: float,
    highlight_words: list[str] | None = None,
    highlight_color: str = "yellow",
    is_top_hook: bool = False,
    stroke_width: float = 0.08,
) -> tuple[Path, dict[str, Any]]:
    proj_dir, dc = _load_draft(project_name)
    mat_id = _new_id()
    anim_id = _new_id()

    highlight_rgb = KINIOR_COLORS.get(highlight_color.lower(), KINIOR_COLORS["yellow"])
    styles = _build_text_styles(text, font_size, highlight_words, highlight_rgb, stroke_width)
    content_json = json.dumps({"text": text, "styles": styles}, ensure_ascii=False)

    texts = dc.setdefault("materials", {}).setdefault("texts", [])
    texts.append({
        "recognize_task_id": "",
        "id": mat_id,
        "name": "",
        "recognize_text": "",
        "recognize_model": "",
        "punc_model": "",
        "type": "text",
        "content": content_json,
        "base_content": "",
        "words": {"start_time": [], "end_time": [], "text": []},
        "current_words": {"start_time": [], "end_time": [], "text": []},
        "global_alpha": 1.0,
        "combo_info": {"text_templates": []},
        "caption_template_info": {
            "resource_id": "",
            "third_resource_id": "",
            "resource_name": "",
            "category_id": "",
            "category_name": "",
            "effect_id": "",
            "request_id": "",
            "path": "",
            "is_new": False,
            "source_platform": 0,
        },
        "layer_weight": 1,
        "letter_spacing": 0.0,
        "text_curve": None,
        "text_loop_on_path": False,
        "offset_on_path": 0.0,
        "enable_path_typesetting": False,
        "text_exceeds_path_process_type": 0,
        "text_typesetting_paths": None,
        "text_typesetting_paths_file": "",
        "text_typesetting_path_index": 0,
        "line_spacing": 0.02,
        "has_shadow": False,
        "shadow_color": "",
        "shadow_alpha": 0.9,
        "shadow_smoothing": 0.45,
        "shadow_distance": 5.0,
        "shadow_point": {"x": 0.6363961030678928, "y": -0.6363961030678928},
        "shadow_angle": -45.0,
        "shadow_thickness_projection_enable": False,
        "shadow_thickness_projection_angle": 0.0,
        "shadow_thickness_projection_distance": 0.0,
        "border_alpha": 1.0,
        "border_color": "#000000",
        "border_width": stroke_width,
        "border_mode": 0,
        "style_name": "",
        "text_color": "#ffffff",
        "text_alpha": 1.0,
        "font_name": "",
        "font_title": "none",
        "font_size": font_size,
        "font_path": "",
        "font_id": "",
        "font_resource_id": "",
        "initial_scale": 1.0,
        "font_url": "",
        "typesetting": 0,
        "alignment": 1,
        "line_feed": 1,
        "use_effect_default_color": False,
        "is_rich_text": False,
        "shape_clip_x": False,
        "shape_clip_y": False,
        "ktv_color": "",
        "text_to_audio_ids": [],
        "bold_width": 0.008,
        "italic_degree": 0,
        "underline": False,
        "underline_width": 0.05,
        "underline_offset": 0.22,
        "sub_type": 0,
        "check_flag": 47,
        "text_size": 30,
        "font_category_name": "",
        "font_source_platform": 0,
        "font_third_resource_id": "",
        "font_category_id": "",
        "add_type": 0,
        "operation_type": 0,
        "recognize_type": 0,
        "fonts": [],
        "background_color": "",
        "background_alpha": 1.0,
        "background_style": 0,
        "background_round_radius": 0.0,
        "background_width": 0.14,
        "background_height": 0.14,
        "background_vertical_offset": 0.0,
        "background_horizontal_offset": 0.0,
        "background_fill": "",
        "single_char_bg_enable": False,
        "single_char_bg_color": "",
        "single_char_bg_alpha": 1.0,
        "single_char_bg_round_radius": 0.3,
        "single_char_bg_width": 0.0,
        "single_char_bg_height": 0.0,
        "single_char_bg_vertical_offset": 0.0,
        "single_char_bg_horizontal_offset": 0.0,
        "font_team_id": "",
        "tts_auto_update": False,
        "text_preset_resource_id": "",
        "group_id": "",
        "preset_id": "",
        "preset_name": "",
        "preset_category": "",
        "preset_category_id": "",
        "preset_index": 0,
        "preset_has_set_alignment": False,
        "force_apply_line_max_width": True,
        "language": "es-MX",
        "relevance_segment": [],
        "original_size": [],
        "fixed_width": -1.0,
        "fixed_height": -1.0,
        "autoAdaptCanvasEnabled": False,
        "line_max_width": 0.82,
        "oneline_cutoff": False,
        "cutoff_postfix": "",
        "subtitle_template_original_fontsize": 0.0,
        "subtitle_keywords": None,
        "inner_padding": -1.0,
        "multi_language_current": "none",
        "source_from": "",
        "is_lyric_effect": False,
        "lyric_group_id": "",
        "lyrics_template": {
            "resource_id": "",
            "resource_name": "",
            "panel": "",
            "effect_id": "",
            "path": "",
            "category_id": "",
            "category_name": "",
            "request_id": "",
        },
        "is_batch_replace": False,
        "is_words_linear": False,
        "ssml_content": "",
        "subtitle_keywords_config": None,
        "sub_template_id": -1,
        "translate_original_text": "",
        "adjust_params": [],
    })

    dc.setdefault("materials", {}).setdefault("material_animations", []).append({
        "id": anim_id,
        "type": "sticker_animation",
        "animations": [],
        "multi_language_current": "none",
    })

    slot = 1 if is_top_hook else 0
    track = _get_or_create_track(dc, "text", slot=slot)
    seg = _build_segment(
        material_id=mat_id,
        source_timerange=None,
        target_start_us=target_start_us,
        target_duration_us=target_duration_us,
        extra_material_refs=[anim_id],
        speed=1.0,
        volume=1.0,
        clip={
            "scale": {"x": 1.0, "y": 1.0},
            "rotation": 0.0,
            "rotation3d": [],
            "transform": {"x": 0.0, "y": transform_y},
            "flip": {"vertical": False, "horizontal": False},
            "alpha": 1.0,
        },
        uniform_scale={"on": True, "value": 1.0},
        render_index=(14026 if is_top_hook else 14000) + len(track["segments"]),
        track_render_index=2 if is_top_hook else 1,
        enable_lut=False,
        enable_adjust=False,
        enable_hsl=False,
        enable_adjust_mask=False,
        hdr_settings=None,
    )

    track["segments"].append(seg)
    track["segments"].sort(key=lambda s: s["target_timerange"]["start"])

    _update_duration(dc)
    _save_draft(proj_dir, dc)
    return proj_dir, dc


@mcp.tool()
def add_text(
    project_name: str,
    text: str,
    timeline_start_sec: float = 0.0,
    duration_sec: float = 3.0,
    font_size: float = 12.0,
    transform_y: float = 0.0,
) -> str:
    """Add a text/subtitle segment with complete CapCut v191 schema to the text track."""
    _add_styled_text_segment(
        project_name=project_name,
        text=text,
        target_start_us=int(round(timeline_start_sec * US)),
        target_duration_us=int(round(duration_sec * US)),
        font_size=font_size,
        transform_y=transform_y,
        stroke_width=0.06,
    )
    return f"Added text '{text}' to '{project_name}' at {timeline_start_sec}s ({duration_sec}s)"


@mcp.tool()
def add_kinior_subtitle(
    project_name: str,
    text: str,
    target_start_us: int,
    target_duration_us: int,
    highlight_words: list[str] | None = None,
    highlight_color: str = "yellow",
    transform_y: float = -0.45,
    font_size: float = 13.5,
    is_top_hook: bool = False,
) -> str:
    """Add a styled Kinior Labs subtitle or top hook title synced to exact microsecond timing."""
    _add_styled_text_segment(
        project_name=project_name,
        text=text,
        target_start_us=target_start_us,
        target_duration_us=target_duration_us,
        font_size=font_size,
        transform_y=transform_y,
        highlight_words=highlight_words,
        highlight_color=highlight_color,
        is_top_hook=is_top_hook,
        stroke_width=0.08,
    )
    kind = "top hook" if is_top_hook else "subtitle"
    return (
        f"Added Kinior {kind} '{text}' to '{project_name}' "
        f"at {target_start_us / US:.3f}s ({target_duration_us / US:.3f}s)"
    )


@mcp.tool()
def add_transition(
    project_name: str,
    segment_index: int,
    transition_name: str = "Zoom recto",
    duration_sec: float = 0.15,
) -> str:
    """Attach a real CapCut v191 template transition to a video segment in Track 0."""
    tpl = TRANSITION_TEMPLATES.get(transition_name)
    if tpl is None:
        available = ", ".join(sorted(TRANSITION_TEMPLATES.keys()))
        raise ValueError(f"Unknown transition '{transition_name}'. Available: {available}")

    proj_dir, dc = _load_draft(project_name)
    video_track = _get_or_create_track(dc, "video", slot=0)
    segs = video_track.get("segments", [])
    if segment_index < 0 or segment_index >= len(segs):
        raise IndexError(f"segment_index {segment_index} out of range (0..{len(segs) - 1})")

    seg = segs[segment_index]
    trans_list = dc.setdefault("materials", {}).setdefault("transitions", [])
    existing_trans_ids = {t["id"] for t in trans_list if "id" in t}
    seg["extra_material_refs"] = [r for r in seg.get("extra_material_refs", []) if r not in existing_trans_ids]

    trans_id = _new_id()
    trans_list.append({
        "id": trans_id,
        "type": "transition",
        "name": transition_name,
        "effect_id": tpl["effect_id"],
        "resource_id": tpl["effect_id"],
        "third_resource_id": tpl["third_resource_id"],
        "source_platform": 1,
        "sub_type": 0,
        "adjust_params": [],
        "path": _resolve_effect_path(tpl["path"], tpl["effect_id"]),
        "duration": int(round(duration_sec * US)),
        "is_overlap": tpl["is_overlap"],
        "platform": "all",
        "category_id": tpl["category_id"],
        "category_name": tpl["category_name"],
        "request_id": "",
        "is_ai_transition": False,
        "video_path": "",
        "task_id": "",
    })
    seg["extra_material_refs"].append(trans_id)

    _save_draft(proj_dir, dc)
    return f"Added transition '{transition_name}' ({duration_sec}s) to seg[{segment_index}] in '{project_name}'"


@mcp.tool()
def add_zoom_keyframe(
    project_name: str,
    segment_index: int,
    start_scale: float,
    end_scale: float,
    start_x: float | None = None,
    end_x: float | None = None,
    start_y: float | None = None,
    end_y: float | None = None,
) -> str:
    """Add smooth source-timed dynamic scale and position keyframes (common_keyframes) to a video segment."""
    proj_dir, dc = _load_draft(project_name)
    video_track = _get_or_create_track(dc, "video", slot=0)
    segs = video_track.get("segments", [])
    if segment_index < 0 or segment_index >= len(segs):
        raise IndexError(f"segment_index {segment_index} out of range (0..{len(segs) - 1})")

    seg = segs[segment_index]
    src = seg.get("source_timerange") or {"start": 0, "duration": seg["target_timerange"]["duration"]}
    t0 = int(src["start"])
    t1 = t0 + int(src["duration"])

    clip = seg.setdefault("clip", {
        "scale": {"x": start_scale, "y": start_scale},
        "rotation": 0.0,
        "rotation3d": [],
        "transform": {"x": 0.0, "y": 0.0},
        "flip": {"vertical": False, "horizontal": False},
        "alpha": 1.0,
    })
    clip["scale"] = {"x": float(start_scale), "y": float(start_scale)}
    common_kfs = seg.setdefault("common_keyframes", [])
    _set_keyframe_prop(common_kfs, "KFTypeScaleX", t0, start_scale, t1, end_scale)

    if start_x is not None and end_x is not None:
        clip.setdefault("transform", {})["x"] = float(start_x)
        _set_keyframe_prop(common_kfs, "KFTypePositionX", t0, start_x, t1, end_x)
    if start_y is not None and end_y is not None:
        clip.setdefault("transform", {})["y"] = float(start_y)
        _set_keyframe_prop(common_kfs, "KFTypePositionY", t0, start_y, t1, end_y)

    _save_draft(proj_dir, dc)
    return (
        f"Added zoom keyframe {start_scale}->{end_scale} "
        f"(t={t0}..{t1}) to seg[{segment_index}] in '{project_name}'"
    )


@mcp.tool()
def add_video_effect(
    project_name: str,
    effect_name: str,
    timeline_start_sec: float,
    duration_sec: float = 0.5,
) -> str:
    """Add a template CapCut v191 video effect segment to an effect track."""
    tpl = VIDEO_EFFECT_TEMPLATES.get(effect_name)
    if tpl is None:
        available = ", ".join(sorted(VIDEO_EFFECT_TEMPLATES.keys()))
        raise ValueError(f"Unknown video effect '{effect_name}'. Available: {available}")

    proj_dir, dc = _load_draft(project_name)
    fx_id = _new_id()
    dc.setdefault("materials", {}).setdefault("video_effects", []).append({
        "id": fx_id,
        "effect_id": tpl["effect_id"],
        "resource_id": tpl["effect_id"],
        "name": effect_name,
        "type": "video_effect",
        "sub_type": 0,
        "bind_segment_id": "",
        "transparent_params": "",
        "path": _resolve_effect_path(tpl["path"], tpl["effect_id"]),
        "value": 1.0,
        "category_id": tpl["category_id"],
        "category_name": tpl["category_name"],
        "platform": "all",
        "apply_target_type": tpl["apply_target_type"],
        "source_platform": 1,
        "version": "",
        "item_effect_type": 0,
        "adjust_params": tpl["adjust_params"],
        "time_range": None,
        "formula_id": "",
        "apply_time_range": None,
        "render_index": tpl["render_index"],
        "track_render_index": 0,
        "common_keyframes": [],
        "request_id": "",
        "algorithm_artifact_path": "",
        "disable_effect_faces": [],
        "covering_relation_change": 0,
        "enable_mask": True,
        "effect_mask": [],
        "enable_video_mask_stroke": True,
        "enable_video_mask_shadow": True,
        "aigc_current_artifact_path": "",
        "aigc_current_artifact_cnt": 0,
        "aigc_current_artifact_freeze_time": -1,
        "aigc_current_artifact_freeze_progress": 0.0,
        "sdk_extra": "",
    })

    seg = _build_segment(
        material_id=fx_id,
        source_timerange=None,
        target_start_us=int(round(timeline_start_sec * US)),
        target_duration_us=int(round(duration_sec * US)),
        extra_material_refs=[],
        speed=1.0,
        volume=1.0,
        clip=None,
        uniform_scale=None,
        render_index=11000,
        track_render_index=2,
        enable_lut=False,
        enable_adjust=False,
        enable_hsl=False,
        enable_adjust_mask=False,
        hdr_settings=None,
    )

    track = _get_or_create_track(dc, "effect")
    track["segments"].append(seg)
    track["segments"].sort(key=lambda s: s["target_timerange"]["start"])

    _update_duration(dc)
    _save_draft(proj_dir, dc)
    return f"Added video effect '{effect_name}' at {timeline_start_sec}s ({duration_sec}s) to '{project_name}'"


@mcp.tool()
def add_preset_sfx(
    project_name: str,
    timeline_start_sec: float,
    duration_sec: float = 0.6,
    volume: float = 0.6,
    sfx_index: int = 0,
) -> str:
    """Insert an existing .aac preset/combination SFX onto a secondary audio track."""
    candidates: list[str] = []
    if PRESET_COMBINATION_DIR.is_dir():
        candidates.extend(sorted(glob.glob(str(PRESET_COMBINATION_DIR / "*.aac"))))
    tornados_comb = CAPCUT_DRAFTS_DIR / "Tornados Fantasma Shorts" / "Resources" / "combination"
    if tornados_comb.is_dir():
        candidates.extend(sorted(glob.glob(str(tornados_comb / "*.aac"))))

    if not candidates:
        return "No preset .aac SFX files found on disk."

    sfx_path = candidates[sfx_index % len(candidates)]
    return add_audio_clip(
        project_name=project_name,
        file_path=sfx_path,
        source_start_sec=0.0,
        duration_sec=duration_sec,
        timeline_start_sec=timeline_start_sec,
        speed=1.0,
        volume=volume,
        file_duration_sec=max(duration_sec, 1.0),
        track_slot=1,
    )


if __name__ == "__main__":
    mcp.run()
