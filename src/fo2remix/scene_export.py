"""Export the verified MAP subset to a renderer-neutral JSON scene."""

from __future__ import annotations

from collections.abc import Callable
from io import BytesIO
from typing import Any

from .art_format import ArtReference
from .map_format import (
    OBJECT_TYPE_ITEM,
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
    art_resolver: Callable[[int], ArtReference] | None = None,
    art_color_resolver: Callable[[int], tuple[int, int, int]] | None = None,
    art_metadata_resolver: Callable[[int], dict[str, Any]] | None = None,
) -> dict[str, Any]:
    map_file = read_map(BytesIO(map_data), prototype_resolver)
    core = map_file.core
    spawn_column, spawn_row = tile_index_to_grid(core.header.entering_tile)
    assert grid_to_tile_index(spawn_column, spawn_row) == core.header.entering_tile

    indexed_objects = list(enumerate(map_file.objects))
    exported_objects = [
        _export_object(
            obj,
            instance_id=instance_id,
            art_resolver=art_resolver,
            art_color_resolver=art_color_resolver,
            art_metadata_resolver=art_metadata_resolver,
        )
        for instance_id, obj in indexed_objects
        if obj.fid_type in {OBJECT_TYPE_ITEM, OBJECT_TYPE_SCENERY, OBJECT_TYPE_WALL}
    ]
    blocking_hexes = _export_blocking_hexes(indexed_objects)

    tile_art: list[dict[str, Any]] = []
    if art_resolver is not None:
        tile_ids = sorted(
            {
                tile_id
                for layer in core.tile_layers
                for tile in layer.tiles
                for tile_id in (tile.floor_id, tile.roof_id)
                if tile_id != 1
            }
        )
        tile_art = [
            _export_art_reference(
                0x04000000 | tile_id,
                art_resolver=art_resolver,
                art_color_resolver=art_color_resolver,
                art_metadata_resolver=art_metadata_resolver,
                extra={"tile_id": tile_id},
            )
            for tile_id in tile_ids
        ]

    return {
        "schema": "fo2remix.scene-v1",
        "source": source,
        "map": {
            "name": core.header.name,
            "version": core.header.version,
            "index": core.header.map_index,
            "flags": core.header.flags,
            "darkness": core.header.darkness,
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
            "art": tile_art,
        },
        "objects": {
            "declared_count": map_file.declared_object_count,
            "script_counts": list(map_file.script_counts),
            "exported_count": len(exported_objects),
            "wall_count": sum(obj["kind"] == "wall" for obj in exported_objects),
            "door_count": sum(obj["kind"] == "door" for obj in exported_objects),
            "scenery_count": sum(obj["kind"] == "scenery" for obj in exported_objects),
            "item_count": sum(obj["kind"] == "item" for obj in exported_objects),
            "records": exported_objects,
        },
        "collision": {
            "blocking_hexes": blocking_hexes,
        },
    }


def _export_object(
    obj: MapObject,
    *,
    instance_id: int,
    art_resolver: Callable[[int], ArtReference] | None,
    art_color_resolver: Callable[[int], tuple[int, int, int]] | None,
    art_metadata_resolver: Callable[[int], dict[str, Any]] | None,
) -> dict[str, Any]:
    column, row = tile_index_to_grid(obj.tile)
    world = hex_index_to_world(obj.tile, obj.elevation)
    if obj.fid_type == OBJECT_TYPE_ITEM:
        kind = "item"
    elif obj.fid_type == OBJECT_TYPE_WALL:
        kind = "wall"
    else:
        kind = "door" if obj.is_door else "scenery"
    record: dict[str, Any] = {
        "instance_id": instance_id,
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
        "frame": obj.frame,
        "screen_offset": [obj.x, obj.y],
        "world": [world[0], world[1], world[2]],
        "light": {
            "distance": obj.light_distance,
            "intensity": obj.light_intensity,
        },
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
    if art_resolver is not None:
        record["art"] = _export_art_reference(
            obj.fid,
            art_resolver=art_resolver,
            art_color_resolver=art_color_resolver,
            art_metadata_resolver=art_metadata_resolver,
        )
    return record


def _export_art_reference(
    fid: int,
    *,
    art_resolver: Callable[[int], ArtReference],
    art_color_resolver: Callable[[int], tuple[int, int, int]] | None,
    art_metadata_resolver: Callable[[int], dict[str, Any]] | None,
    extra: dict[str, Any] | None = None,
) -> dict[str, Any]:
    art = art_resolver(fid)
    result: dict[str, Any] = {
        "type": art.object_type_name,
        "list_index": art.list_index,
        "file_name": art.file_name,
        "path": art.path,
    }
    if extra is not None:
        result.update(extra)
    if art_color_resolver is not None:
        result["opaque_average_rgb"] = list(art_color_resolver(fid))
    if art_metadata_resolver is not None:
        result["frame"] = art_metadata_resolver(fid)
    return result


def _export_blocking_hexes(
    objects: list[tuple[int, MapObject]],
) -> list[dict[str, Any]]:
    blocked: dict[tuple[int, int], dict[str, set[int]]] = {}
    for instance_id, obj in objects:
        if not obj.blocks_movement:
            continue
        tiles = {obj.tile}
        if obj.multihex:
            tiles.update(tile_in_direction(obj.tile, rotation) for rotation in range(6))
        for tile in tiles:
            identities = blocked.setdefault(
                (obj.elevation, tile),
                {"instance_ids": set(), "object_ids": set()},
            )
            identities["instance_ids"].add(instance_id)
            identities["object_ids"].add(obj.object_id)

    records: list[dict[str, Any]] = []
    for (elevation, tile), identities in sorted(blocked.items()):
        column, row = tile_index_to_grid(tile)
        records.append(
            {
                "hex_index": tile,
                "hex_column": column,
                "hex_row": row,
                "elevation": elevation,
                "instance_ids": sorted(identities["instance_ids"]),
                "object_ids": sorted(identities["object_ids"]),
            }
        )
    return records
