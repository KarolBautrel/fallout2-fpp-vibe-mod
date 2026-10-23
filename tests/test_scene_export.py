from __future__ import annotations

from struct import pack

from fo2remix.map_format import MAP_HEADER_STRUCT, SQUARE_GRID_SIZE
from fo2remix.scene_export import export_scene_v1


def test_exports_one_present_tile_layer() -> None:
    header = MAP_HEADER_STRUCT.pack(
        20,
        b"TEST.MAP\0\0\0\0\0\0\0\0",
        18492,
        0,
        2,
        0,
        10,
        12,
        1,
        0,
        42,
        0,
        *([0] * 44),
    )
    packed_tile = (3 << 28) | (7 << 16) | 5
    layer = pack(f">{SQUARE_GRID_SIZE}I", *([packed_tile] * SQUARE_GRID_SIZE))

    scene = export_scene_v1(header + layer, source={"entry": r"maps\test.map"})

    assert scene["schema"] == "fo2remix.scene-v1"
    assert scene["spawn"]["hex_index"] == 18492
    assert len(scene["tile_grid"]["layers"]) == 1
    assert scene["tile_grid"]["layers"][0]["floor_ids"][0] == 5
    assert scene["tile_grid"]["layers"][0]["roof_ids"][0] == 7
    assert scene["tile_grid"]["layers"][0]["roof_flags"][0] == 3
