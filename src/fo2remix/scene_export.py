"""Export the verified MAP subset to a renderer-neutral JSON scene."""

from __future__ import annotations

from io import BytesIO
from typing import Any

from .map_format import (
    SQUARE_GRID_HEIGHT,
    SQUARE_GRID_WIDTH,
    grid_to_tile_index,
    read_map_core,
    tile_index_to_grid,
)


def export_scene_v1(map_data: bytes, *, source: dict[str, str]) -> dict[str, Any]:
    core = read_map_core(BytesIO(map_data))
    spawn_column, spawn_row = tile_index_to_grid(core.header.entering_tile)
    assert grid_to_tile_index(spawn_column, spawn_row) == core.header.entering_tile

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
    }
