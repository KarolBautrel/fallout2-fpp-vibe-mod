"""Export the verified MAP subset to a renderer-neutral JSON scene."""

from __future__ import annotations

from io import BytesIO
from typing import Any

from .map_format import (
    OBJECT_TYPE_SCENERY,
    OBJECT_TYPE_WALL,
    SQUARE_GRID_HEIGHT,
    SQUARE_GRID_WIDTH,
    MapObject,
    PrototypeResolver,
    grid_to_tile_index,
    hex_index_to_world,
    read_map,
    tile_in_direction,
    tile_index_to_grid,
)


def export_scene_v1(
    map_data: bytes,
    *,
    source: dict[str, str],
    prototype_resolver: PrototypeResolver,
) -> dict[str, Any]:
    map_file = read_map(BytesIO(map_data), prototype_resolver)
    core = map_file.core
    spawn_column, spawn_row = tile_index_to_grid(core.header.entering_tile)
    assert grid_to_tile_index(spawn_column, spawn_row) == core.header.entering_tile

    exported_objects = [
        _export_object(obj)
        for obj in map_file.objects
        if obj.fid_type in {OBJECT_TYPE_SCENERY, OBJECT_TYPE_WALL}
    ]
    blocking_hexes = _export_blocking_hexes(map_file.objects)

    return {
        "schema": "fo2remix.scene-v1",
        "source": source,
        "map": {
            "name": core.header.name,
            "version": core.header.version,
            "index": core.header.map_index,
            "flags": core.header.flags,
        },
        "spawn": {
            "hex_index": core.header.entering_tile,
            "hex_column": spawn_column,
            "hex_row": spawn_row,
            "elevation": core.header.entering_elevation,
            "rotation": core.header.entering_rotation,
        },
        "tile_grid": {
            "width": SQUARE_GRID_WIDTH,
            "height": SQUARE_GRID_HEIGHT,
            "layers": [
                {
                    "elevation": layer.elevation,
                    "floor_ids": [tile.floor_id for tile in layer.tiles],
                    "roof_ids": [tile.roof_id for tile in layer.tiles],
                    "roof_flags": [tile.roof_flags for tile in layer.tiles],
                }
                for layer in core.tile_layers
            ],
        },
        "objects": {
            "declared_count": map_file.declared_object_count,
            "script_counts": list(map_file.script_counts),
            "exported_count": len(exported_objects),
            "wall_count": sum(obj["kind"] == "wall" for obj in exported_objects),
            "door_count": sum(obj["kind"] == "door" for obj in exported_objects),
            "scenery_count": sum(obj["kind"] == "scenery" for obj in exported_objects),
            "records": exported_objects,
        },
        "collision": {
            "blocking_hexes": blocking_hexes,
        },
    }


def _export_object(obj: MapObject) -> dict[str, Any]:
    column, row = tile_index_to_grid(obj.tile)
    world = hex_index_to_world(obj.tile, obj.elevation)
    kind = "wall" if obj.fid_type == OBJECT_TYPE_WALL else "door" if obj.is_door else "scenery"
    record: dict[str, Any] = {
        "object_id": obj.object_id,
        "kind": kind,
        "pid": obj.pid,
        "fid": obj.fid,
        "prototype": {
            "path": obj.prototype.path,
            "subtype": obj.prototype.subtype_name,
        },
        "hex_index": obj.tile,
        "hex_column": column,
        "hex_row": row,
        "elevation": obj.elevation,
        "rotation": obj.rotation,
        "world": [world[0], world[1], world[2]],
        "flags": {
            "raw": obj.flags_u32,
            "hidden": obj.hidden,
            "no_block": obj.no_block,
            "multihex": obj.multihex,
        },
        "blocks_movement": obj.blocks_movement,
    }
    if obj.is_door:
        door_flags = (obj.door_open_flags or 0) & 0xFFFFFFFF
        record["door"] = {
            "open_flags": door_flags,
            "open": bool(door_flags & 0x01),
            "locked": bool(door_flags & 0x02000000),
            "jammed": bool(door_flags & 0x04000000),
        }
    return record


def _export_blocking_hexes(objects: tuple[MapObject, ...]) -> list[dict[str, Any]]:
    blocked: dict[tuple[int, int], set[int]] = {}
    for obj in objects:
        if not obj.blocks_movement:
            continue
        tiles = {obj.tile}
        if obj.multihex:
            tiles.update(tile_in_direction(obj.tile, rotation) for rotation in range(6))
        for tile in tiles:
            blocked.setdefault((obj.elevation, tile), set()).add(obj.object_id)

    records: list[dict[str, Any]] = []
    for (elevation, tile), object_ids in sorted(blocked.items()):
        column, row = tile_index_to_grid(tile)
        records.append(
            {
                "hex_index": tile,
                "hex_column": column,
                "hex_row": row,
                "elevation": elevation,
                "object_ids": sorted(object_ids),
            }
        )
    return records
